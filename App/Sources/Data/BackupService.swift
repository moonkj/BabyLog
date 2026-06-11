// BackupService.swift
// BabyLog — 전체 데이터 백업/복원 (사진·영상 포함 단일 파일)
//
// 아기 사진은 이 앱의 가장 중요한 자산이다. 앱 삭제·기기 변경에도 데이터를 지키기 위한
// 사용자 주도 백업: 상태(JSON) + 모든 사진/영상을 단일 .babylogbackup(바이너리 plist)로 묶어
// 파일 앱/iCloud Drive/AirDrop으로 저장·이전한다. 서버 불필요(무료), CloudKit 자동백업은 별도(Pro).

import Foundation

/// 단일 백업 아카이브 — 전체 상태 + 모든 사진/영상 원본.
struct BackupArchive: Codable {
    var version: Int = 1
    var exportedAt: Date = Date()
    var state: PersistableState
    var photos: [String: Data]   // 파일명 → 원본 바이트
}

enum BackupService {
    static let fileExtension = "babylogbackup"

    private static func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }

    /// 백업 파일을 임시 경로에 생성하고 URL을 반환(공유 시트로 저장 유도).
    @MainActor
    static func makeArchive(_ store: AppStore) -> URL? {
        let archive = BackupArchive(state: store.snapshot(), photos: PhotoStore.allPhotoData())
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary           // Data를 base64 없이 그대로 → 작고 빠름
        guard let data = try? encoder.encode(archive) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyLog-Backup-\(stamp()).\(fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 백업 파일에서 복원. 사진 먼저 기록 후 상태 복원.
    @MainActor
    static func restore(from url: URL, into store: AppStore) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let archive = try? PropertyListDecoder().decode(BackupArchive.self, from: data) else {
            return false
        }
        PhotoStore.restorePhotos(archive.photos)
        store.restore(archive.state)
        return true
    }
}
