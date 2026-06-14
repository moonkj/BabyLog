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

    /// iCloud 계정 사용 가능 여부.
    func accountAvailable() async -> Bool {
        #if BL_CLOUDKIT
        guard Self.isEnabled else { return false }
        return (try? await CKContainer.default().accountStatus()) == .available
        #else
        return false
        #endif
    }

    /// 로컬 상태를 iCloud로 업로드 (last-write-wins).
    func push(_ state: PersistableState) async throws {
        #if BL_CLOUDKIT
        guard Self.isEnabled else { throw CloudSyncError.notEnabled }
        guard await accountAvailable() else { throw CloudSyncError.accountUnavailable }
        let id = CKRecord.ID(recordName: recordName)
        let record = (try? await database.record(for: id))
            ?? CKRecord(recordType: recordType, recordID: id)
        record["json"] = try Self.encoder.encode(state) as CKRecordValue
        record["updatedAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
        #else
        throw CloudSyncError.notEnabled
        #endif
    }

    /// iCloud에서 상태를 가져온다 (없으면 nil).
    func pull() async throws -> PersistableState? {
        #if BL_CLOUDKIT
        guard Self.isEnabled else { throw CloudSyncError.notEnabled }
        guard await accountAvailable() else { throw CloudSyncError.accountUnavailable }
        let id = CKRecord.ID(recordName: recordName)
        guard let record = try? await database.record(for: id),
              let data = record["json"] as? Data else { return nil }
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

    /// 새 사진 파일만 CloudKit에 업로드(증분). best-effort — 실패분은 다음 기회에 재시도.
    func pushPhotos() async {
        #if BL_CLOUDKIT
        guard Self.isEnabled, await accountAvailable() else { return }
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
        guard Self.isEnabled, await accountAvailable() else { return }
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
