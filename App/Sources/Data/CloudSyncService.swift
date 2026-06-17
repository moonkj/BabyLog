// CloudSyncService.swift
// BabyLog — iCloud(CloudKit) 가족 백업·동기화 (Pro)
//
// 전략: 전체 상태(PersistableState)를 단일 레코드(JSON)로 개인 DB에 저장/복원.
//   - 앱 규모상 단일 레코드 last-write-wins로 충분(추후 per-record/CKShare 확장 가능).
//   - 활성화에는 유료 개발자 계정 + iCloud(CloudKit) Capability + 엔타이틀먼트가 필요하다.
//   - 엔타이틀먼트가 없으면 절대 CKContainer를 건드리지 않도록 enabled 플래그로 게이트한다.
//     (App Group과 동일 — 미설정 환경에서 빌드/실행이 깨지지 않게)
//
// 가족(조부모) 공유: CKShare로 확장 예정. 현재는 본인 iCloud 계정 내 기기 간 동기화 스캐폴드.

import Foundation
import CloudKit

enum CloudSyncError: LocalizedError {
    case notEnabled
    case accountUnavailable
    var errorDescription: String? {
        switch self {
        case .notEnabled:        return "iCloud 백업이 켜져 있지 않아요."
        case .accountUnavailable: return "iCloud 계정이 필요해요. 설정 > Apple 계정에서 iCloud 로그인 후 다시 시도하세요."
        }
    }
}

@MainActor
final class CloudSyncService {
    static let shared = CloudSyncService()
    private init() {}

    /// 자동 복원 재진입 가드 — .task와 onChange(onboarded)가 같은 런치에서 겹쳐 호출돼도 1회만 실행.
    static var autoRestoreInFlight = false

    /// 사용자가 설정에서 켰는지 (엔타이틀먼트 없으면 켜지지 않음).
    @MainActor static var isEnabled: Bool {
        // 기본 ON — 키가 설정되기 전(첫 실행)에도 자동 백업이 켜져 있도록(데이터 안전 우선).
        (UserDefaults.standard.object(forKey: "bl_cloud_sync") as? Bool) ?? true
    }

    private let recordType = "BabyLogState"
    private let recordName = "main"

    private var database: CKDatabase {
        CKContainer.default().privateCloudDatabase
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }
    private static var decoder: JSONDecoder {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }

    /// 엔타이틀먼트 + 유료 계정 연결 시 빌드 설정에 `BL_CLOUDKIT` 플래그를 추가하면 활성화된다.
    /// 그 전까지는 CKContainer를 절대 건드리지 않아 빌드/실행이 안전하다.
    static var isAvailableInBuild: Bool {
        #if BL_CLOUDKIT
        return true
        #else
        return false
        #endif
    }

    /// 백업/복원 오류를 사용자 친화 메시지로 변환(CloudKit 사유별 안내).
    nonisolated static func message(for error: Error) -> String {
        if let e = error as? CloudSyncError { return e.errorDescription ?? "잠시 후 다시 시도해 주세요." }
        #if BL_CLOUDKIT
        if let ck = error as? CKError {
            switch ck.code {
            case .quotaExceeded:
                return "iCloud 저장공간이 가득 찼어요. iOS 설정 > Apple 계정 > iCloud에서 공간을 비우거나 업그레이드한 뒤 다시 시도하세요."
            case .notAuthenticated:
                return "iCloud 로그인이 필요해요. iOS 설정 > Apple 계정에서 로그인 후 다시 시도하세요."
            case .networkUnavailable, .networkFailure:
                return "네트워크 연결을 확인하고 다시 시도해 주세요."
            case .serviceUnavailable, .requestRateLimited, .zoneBusy:
                return "iCloud가 잠시 바빠요. 잠시 후 다시 시도해 주세요."
            default:
                return "백업 실패: \(ck.localizedDescription)"
            }
        }
        #endif
        return "백업 실패: \(error.localizedDescription)"
    }

    /// iCloud 계정 사용 가능 여부.
    func accountAvailable() async -> Bool {
        #if BL_CLOUDKIT
        return (try? await CKContainer.default().accountStatus()) == .available
        #else
        return false
        #endif
    }

    /// 로컬 상태를 iCloud로 업로드 (last-write-wins).
    func push(_ state: PersistableState) async throws {
        #if BL_CLOUDKIT
        // 수동 '지금 백업'은 자동백업 토글과 무관하게 동작(자동 트리거만 scenePhase에서 isEnabled로 게이트).
        guard await accountAvailable() else { throw CloudSyncError.accountUnavailable }
        let id = CKRecord.ID(recordName: recordName)
        let record = (try? await database.record(for: id))
            ?? CKRecord(recordType: recordType, recordID: id)
        // 전체 상태를 CKAsset(파일)로 저장 — inline Data 필드는 레코드 1MB 한계라 활동 많은 가족은 영구 실패.
        let data = try Self.encoder.encode(state)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("bl-state-\(UUID().uuidString).json")
        try data.write(to: tmp)
        // save가 throw해도 임시 JSON이 누적되지 않게 defer로 정리(백그라운드 전환마다 push 실패 시 누수 방지).
        defer { try? FileManager.default.removeItem(at: tmp) }
        record["jsonAsset"] = CKAsset(fileURL: tmp)
        record["json"] = nil          // 레거시 inline 필드 제거(1MB 한계에 합산되지 않게)
        record["updatedAt"] = Date() as CKRecordValue
        // last-write-wins로 강제 덮어쓰기 — database.save()의 기본 .ifServerRecordUnchanged는
        // 자동/수동 백업이 겹치거나 changeTag가 어긋나면 'serverRecordChanged(client oplock)'로 실패한다.
        // 백업 레코드는 사용자당 1개(main)이고 항상 최신본으로 덮는 게 맞으므로 .allKeys 사용.
        let result = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        for (_, r) in result.saveResults { if case .failure(let e) = r { throw e } }
        UserDefaults.standard.set(Date(), forKey: Self.lastBackupKey)   // 백업 성공 시각 기록(설정에 '마지막 백업' 표시)
        #else
        throw CloudSyncError.notEnabled
        #endif
    }

    /// iCloud에서 상태를 가져온다 (없으면 nil). CKAsset 우선, 레거시 inline json 폴백.
    func pull() async throws -> PersistableState? {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { throw CloudSyncError.accountUnavailable }
        let id = CKRecord.ID(recordName: recordName)
        guard let record = try? await database.record(for: id) else { return nil }
        let data: Data?
        if let asset = record["jsonAsset"] as? CKAsset, let url = asset.fileURL {
            data = try? Data(contentsOf: url)
        } else {
            data = record["json"] as? Data   // 레거시(구버전 백업) inline 폴백
        }
        guard let data else { return nil }
        return try Self.decoder.decode(PersistableState.self, from: data)
        #else
        throw CloudSyncError.notEnabled
        #endif
    }

    /// 클라우드에 저장된 '가장 최근 백업'의 시각(복원 확인창에 표시 — 사용자가 무엇을 되살리는지 명확히).
    /// 레코드는 1개뿐이라 이 값이 곧 최신 백업 시각. 없거나 미사용이면 nil.
    func backupDate() async -> Date? {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { return nil }
        let id = CKRecord.ID(recordName: recordName)
        guard let record = try? await database.record(for: id) else { return nil }
        return (record["updatedAt"] as? Date) ?? record.modificationDate
        #else
        return nil
        #endif
    }

    // MARK: - 사진 동기화 (CKAsset)
    // 상태(JSON)만 백업하면 사진 파일이 빠져 복원 시 빈 액자가 된다 → 사진도 CloudKit에 함께 보관.
    // 사진은 파일별 레코드(BabyLogPhoto, recordName=photo-<파일명>)에 CKAsset으로 저장(증분 업로드).

    private static let photoRecordType = "BabyLogPhoto"
    private static let uploadedKey = "bl_ck_uploaded_photos"   // 이미 올린 파일명(증분)
    private static let tombstoneKey = "bl_ck_deleted_photos"   // 로컬에서 지운 파일명 — CK에서도 지우고 복원 시 부활 차단
    private static let lastBackupKey = "bl_last_cloud_backup_at"   // 이 기기에서 마지막으로 백업 성공한 시각(표시용)

    /// 이 기기에서 마지막으로 iCloud 백업(상태 업로드)에 성공한 시각. 없으면 nil.
    nonisolated static func lastBackupAt() -> Date? {
        UserDefaults.standard.object(forKey: lastBackupKey) as? Date
    }

    /// iCloud에 아직 안 올라간 로컬 사진·영상 수(원장 기준, 네트워크 없이 계산). 0이면 모두 백업됨.
    nonisolated static func pendingUploadCount() -> Int {
        let uploaded = Set(UserDefaults.standard.stringArray(forKey: uploadedKey) ?? [])
        return PhotoStore.allPhotoFileURLs().filter { !uploaded.contains($0.lastPathComponent) }.count
    }

    /// 로컬 사진 삭제 시 호출(PhotoStore.delete) — 툼스톤 기록. 다음 백업에서 CK 레코드를 지우고
    /// 복원(pullPhotos)이 되살리지 않게 한다(민감영역: 지운 사진이 부활하면 안 됨). CloudKit 미사용이어도 무해.
    nonisolated static func tombstonePhoto(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        var set = Set(UserDefaults.standard.stringArray(forKey: tombstoneKey) ?? [])
        set.insert(name)
        UserDefaults.standard.set(Array(set), forKey: tombstoneKey)
    }

    /// 새 사진 파일만 CloudKit에 업로드(증분) + 툼스톤(삭제된 사진) CK 레코드 제거. best-effort.
    /// 반환: (이번에 올린 수, 올릴 대상이던 수, 실패 수) — 진단·표시용.
    @discardableResult
    func pushPhotos() async -> (uploaded: Int, pending: Int, failed: Int, error: String?) {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { return (0, 0, 0, "iCloud 계정 사용 불가") }
        // 0) 삭제 툼스톤 처리 — CK 레코드 삭제 + 업로드 원장/툼스톤에서 제거(부활 차단).
        let tombstones = Set(UserDefaults.standard.stringArray(forKey: Self.tombstoneKey) ?? [])
        if !tombstones.isEmpty {
            var up = Set(UserDefaults.standard.stringArray(forKey: Self.uploadedKey) ?? [])
            var remaining = tombstones
            for batch in Array(tombstones).chunked(into: 40) {
                let ids = batch.map { CKRecord.ID(recordName: "photo-\($0)") }
                // 배치 반환을 무조건 성공으로 보지 않고 레코드별 결과를 확인 — 실패분은 툼스톤에 남겨
                // 다음 백업에서 재시도(민감영역: 지운 사진이 부활하면 안 됨). 이미 없는 레코드는 정리.
                if let result = try? await database.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys) {
                    for (rid, res) in result.deleteResults {
                        let name = String(rid.recordName.dropFirst("photo-".count))
                        switch res {
                        case .success:
                            up.remove(name); remaining.remove(name)
                        case .failure(let err):
                            if let ck = err as? CKError, ck.code == .unknownItem {
                                up.remove(name); remaining.remove(name)   // CK에 이미 없음 → 툼스톤 유지 불필요
                            }   // 그 외 실패는 remaining 유지 → 다음 백업 재시도
                        }
                    }
                }
            }
            UserDefaults.standard.set(Array(up), forKey: Self.uploadedKey)
            UserDefaults.standard.set(Array(remaining), forKey: Self.tombstoneKey)
        }
        var uploaded = Set(UserDefaults.standard.stringArray(forKey: Self.uploadedKey) ?? [])
        let pending = PhotoStore.allPhotoFileURLs().filter { !uploaded.contains($0.lastPathComponent) }
        guard !pending.isEmpty else { return (0, 0, 0, nil) }
        var uploadedCount = 0, failedCount = 0
        var firstError: String? = nil
        // 작은 배치 + 실패해도 break하지 않고 다음 배치 계속 — 한 사진의 문제가 전체 업로드를
        // 막아 사진이 통째로 안 올라가던 문제 방지(증분이라 다음 백업에서 실패분 재시도).
        for batch in pending.chunked(into: 5) {
            let records = batch.map { url -> CKRecord in
                let rec = CKRecord(recordType: Self.photoRecordType,
                                   recordID: CKRecord.ID(recordName: "photo-\(url.lastPathComponent)"))
                rec["name"] = url.lastPathComponent as CKRecordValue
                rec["asset"] = CKAsset(fileURL: url)
                return rec
            }
            do {
                // ⚠️ async modifyRecords는 개별 레코드 실패를 throw하지 않고 saveResults에 담는다.
                //    예전엔 _ = try ... 로 무시해 '거짓 성공'(실제 저장 실패인데 올림으로 카운트)이 났다.
                //    → 반드시 per-record 결과를 검사해 성공한 것만 원장에 기록한다.
                let result = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
                for (id, res) in result.saveResults {
                    switch res {
                    case .success:
                        let name = String(id.recordName.dropFirst("photo-".count))
                        uploaded.insert(name); uploadedCount += 1
                    case .failure(let err):
                        failedCount += 1
                        if firstError == nil { firstError = Self.message(for: err) }
                    }
                }
                UserDefaults.standard.set(Array(uploaded), forKey: Self.uploadedKey)
            } catch {
                failedCount += batch.count
                if firstError == nil { firstError = Self.message(for: error) }
                continue   // 이 배치만 건너뛰고 나머지는 계속 시도
            }
        }
        return (uploadedCount, pending.count, failedCount, firstError)
        #else
        return (0, 0, 0, nil)
        #endif
    }

    /// 복원에 필요한 사진을 CloudKit에서 로컬로 가져온다(로컬에 없는 것만). 새 기기/재설치 복원용.
    /// ⚠️ recordID로 직접 일괄 조회한다 — CKQuery(전체검색)는 recordName에 Queryable 인덱스가
    ///    없으면 실패해 사진이 하나도 안 내려온다(상태 JSON은 record(for:)라 정상이라 불일치 발생).
    ///    refs는 복원한 상태(state.allPhotoRefs)에서 넘어온 모든 사진·영상 파일명.
    /// 반환: (요청 수, CloudKit에서 찾은 레코드 수, 실제 복사한 수, 에러) — 진단·표시용.
    @discardableResult
    func pullPhotos(refs: [String]) async -> (requested: Int, found: Int, copied: Int, error: String?) {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { return (0, 0, 0, "iCloud 계정 사용 불가") }
        let tombstones = Set(UserDefaults.standard.stringArray(forKey: Self.tombstoneKey) ?? [])
        let needed = refs.filter { name in
            guard !name.isEmpty, !tombstones.contains(name),
                  let dest = PhotoStore.safeRestoreURL(for: name) else { return false }
            return !FileManager.default.fileExists(atPath: dest.path)   // 이미 있으면 건너뜀
        }
        guard !needed.isEmpty else { return (0, 0, 0, nil) }
        var found = 0, copied = 0
        var firstError: String? = nil
        var confirmedInCloud: [String] = []   // 클라우드에 존재 확인된 파일 — 복원 직후 '미백업 N장' 오인 방지(원장 반영)
        for batch in needed.chunked(into: 100) {           // records(for:) 일괄 조회(쿼리 인덱스 불필요)
            let ids = batch.map { CKRecord.ID(recordName: "photo-\($0)") }
            let results: [CKRecord.ID: Result<CKRecord, Error>]
            do {
                results = try await database.records(for: ids)
            } catch {
                if firstError == nil { firstError = Self.message(for: error) }
                continue
            }
            for (_, result) in results {
                guard let rec = try? result.get() else { continue }
                found += 1
                guard let name = rec["name"] as? String,
                      let asset = rec["asset"] as? CKAsset, let src = asset.fileURL,
                      let dest = PhotoStore.safeRestoreURL(for: name),
                      !FileManager.default.fileExists(atPath: dest.path) else { continue }
                if (try? FileManager.default.copyItem(at: src, to: dest)) != nil {
                    copied += 1
                    confirmedInCloud.append(name)   // 클라우드→로컬 복사 성공: 이미 백업된 파일
                    // 온디바이스 저장과 동일 보호 클래스 적용(복원본도 잠금 시 보호 — 아동 사진).
                    try? FileManager.default.setAttributes(
                        [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: dest.path)
                }
            }
        }
        // 클라우드에서 받은 사진은 이미 백업돼 있는 것 → 업로드 원장에 합쳐, 복원 직후 가짜 '미백업 N장' 경고를 막는다.
        if !confirmedInCloud.isEmpty {
            var up = Set(UserDefaults.standard.stringArray(forKey: Self.uploadedKey) ?? [])
            up.formUnion(confirmedInCloud)
            UserDefaults.standard.set(Array(up), forKey: Self.uploadedKey)
        }
        return (needed.count, found, copied, firstError)
        #else
        return (0, 0, 0, nil)
        #endif
    }
}

extension PersistableState {
    /// 백업/복원에 필요한 모든 로컬 사진·영상 파일명(중복 제거). pullPhotos가 ID로 조회할 대상.
    var allPhotoRefs: [String] {
        var refs: [String] = []
        for e in diaryEntries {
            refs.append(contentsOf: e.photoRefList)
            if let v = e.videoRef, !v.isEmpty { refs.append(v) }
        }
        for log in pregnancyLogs where log.kind == .belly {
            if let r = log.photoRef, !r.isEmpty { refs.append(r) }
        }
        for c in children { if let r = c.profileImageRef, !r.isEmpty { refs.append(r) } }
        for m in marketItems { refs.append(contentsOf: m.photoRefs) }
        // 성장 보드 전용 사진(기록 참조분은 diaryEntries에서 이미 포함) — 재설치 복원 시 빈 카드 방지.
        for b in growthBoards { for card in b.cards { if let r = card.photoRef, !r.isEmpty { refs.append(r) } } }
        return Array(Set(refs.filter { !$0.isEmpty }))
    }
}

#if BL_CLOUDKIT
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0 ..< Swift.min($0 + size, count)]) }
    }
}
#endif
