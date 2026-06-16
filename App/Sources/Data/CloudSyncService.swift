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

    /// 사용자가 설정에서 켰는지 (엔타이틀먼트 없으면 켜지지 않음).
    @MainActor static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "bl_cloud_sync")
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
        _ = try await database.save(record)
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

    // MARK: - 사진 동기화 (CKAsset)
    // 상태(JSON)만 백업하면 사진 파일이 빠져 복원 시 빈 액자가 된다 → 사진도 CloudKit에 함께 보관.
    // 사진은 파일별 레코드(BabyLogPhoto, recordName=photo-<파일명>)에 CKAsset으로 저장(증분 업로드).

    private static let photoRecordType = "BabyLogPhoto"
    private static let uploadedKey = "bl_ck_uploaded_photos"   // 이미 올린 파일명(증분)
    private static let tombstoneKey = "bl_ck_deleted_photos"   // 로컬에서 지운 파일명 — CK에서도 지우고 복원 시 부활 차단

    /// 로컬 사진 삭제 시 호출(PhotoStore.delete) — 툼스톤 기록. 다음 백업에서 CK 레코드를 지우고
    /// 복원(pullPhotos)이 되살리지 않게 한다(민감영역: 지운 사진이 부활하면 안 됨). CloudKit 미사용이어도 무해.
    nonisolated static func tombstonePhoto(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        var set = Set(UserDefaults.standard.stringArray(forKey: tombstoneKey) ?? [])
        set.insert(name)
        UserDefaults.standard.set(Array(set), forKey: tombstoneKey)
    }

    /// 새 사진 파일만 CloudKit에 업로드(증분) + 툼스톤(삭제된 사진) CK 레코드 제거. best-effort.
    func pushPhotos() async {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { return }
        // 0) 삭제 툼스톤 처리 — CK 레코드 삭제 + 업로드 원장/툼스톤에서 제거(부활 차단).
        let tombstones = Set(UserDefaults.standard.stringArray(forKey: Self.tombstoneKey) ?? [])
        if !tombstones.isEmpty {
            var up = Set(UserDefaults.standard.stringArray(forKey: Self.uploadedKey) ?? [])
            var remaining = tombstones
            for batch in Array(tombstones).chunked(into: 40) {
                let ids = batch.map { CKRecord.ID(recordName: "photo-\($0)") }
                if (try? await database.modifyRecords(saving: [], deleting: ids, savePolicy: .allKeys)) != nil {
                    for n in batch { up.remove(n); remaining.remove(n) }
                }
            }
            UserDefaults.standard.set(Array(up), forKey: Self.uploadedKey)
            UserDefaults.standard.set(Array(remaining), forKey: Self.tombstoneKey)
        }
        var uploaded = Set(UserDefaults.standard.stringArray(forKey: Self.uploadedKey) ?? [])
        let pending = PhotoStore.allPhotoFileURLs().filter { !uploaded.contains($0.lastPathComponent) }
        guard !pending.isEmpty else { return }
        for batch in pending.chunked(into: 40) {
            let records = batch.map { url -> CKRecord in
                let rec = CKRecord(recordType: Self.photoRecordType,
                                   recordID: CKRecord.ID(recordName: "photo-\(url.lastPathComponent)"))
                rec["name"] = url.lastPathComponent as CKRecordValue
                rec["asset"] = CKAsset(fileURL: url)
                return rec
            }
            do {
                _ = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
                for url in batch { uploaded.insert(url.lastPathComponent) }
                UserDefaults.standard.set(Array(uploaded), forKey: Self.uploadedKey)
            } catch {
                break   // 네트워크/용량 문제 — 다음 백업 때 이어서
            }
        }
        #endif
    }

    /// CloudKit의 모든 사진을 로컬로 복원(로컬에 없는 파일만 기록). 새 기기/재설치 복원용.
    func pullPhotos() async {
        #if BL_CLOUDKIT
        guard await accountAvailable() else { return }
        let tombstones = Set(UserDefaults.standard.stringArray(forKey: Self.tombstoneKey) ?? [])
        let query = CKQuery(recordType: Self.photoRecordType, predicate: NSPredicate(value: true))
        var cursor: CKQueryOperation.Cursor?
        repeat {
            do {
                let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
                if let c = cursor {
                    page = try await database.records(continuingMatchFrom: c)
                } else {
                    page = try await database.records(matching: query)
                }
                for (_, result) in page.matchResults {
                    guard let rec = try? result.get(),
                          let name = rec["name"] as? String,
                          !tombstones.contains(name),   // 로컬에서 지운 사진은 복원하지 않음(부활 차단)
                          let asset = rec["asset"] as? CKAsset, let src = asset.fileURL,
                          let dest = PhotoStore.safeRestoreURL(for: name),
                          !FileManager.default.fileExists(atPath: dest.path) else { continue }
                    try? FileManager.default.copyItem(at: src, to: dest)
                }
                cursor = page.queryCursor
            } catch {
                break
            }
        } while cursor != nil
        #endif
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
