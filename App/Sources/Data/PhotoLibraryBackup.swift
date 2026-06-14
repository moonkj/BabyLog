// PhotoLibraryBackup.swift
// BabyLog — 무료 사용자 사진 보호: 등록 사진을 사용자 본인의 iOS '사진' 앱 앨범에 자동 저장.
//
// 절대 원칙 준수: 우리 서버로 올리지 않는다. 사용자의 사진 앱(→ 본인 iCloud 사진)에만 저장하므로
// 앱을 삭제·재설치해도 사진이 사진 앱/iCloud에 그대로 남는다. 추가 전용(addOnly) 권한만 사용.
//
// 대상: 아이/임신 기록의 영구 보존 가치가 있는 사진(다이어리·배사진·프로필). 마켓 등 일시 사진은 제외.

import Photos
import UIKit

enum PhotoLibraryBackup {
    static let albumName = "베이비로그"
    private static let enabledKey  = "bl_photo_lib_backup"
    private static let exportedKey = "bl_photo_lib_exported"   // 이미 내보낸 photoRef

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// 추가 전용(addOnly) 권한 요청. 허용/제한 시 true.
    static func requestAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited: return true
        case .notDetermined:
            let s = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            return s == .authorized || s == .limited
        default: return false
        }
    }

    private static func exportedSet() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: exportedKey) ?? [])
    }
    private static func markExported(_ refs: Set<String>) {
        UserDefaults.standard.set(Array(refs), forKey: exportedKey)
    }

    /// 주어진 photoRef 중 아직 안 내보낸 것을 사진 앱 앨범에 저장. (백그라운드 안전, best-effort)
    /// - Returns: 이번에 새로 저장한 장수.
    @discardableResult
    static func sync(refs: [String]) async -> Int {
        guard isEnabled, await requestAuthorization() else { return 0 }
        var exported = exportedSet()
        let pending = refs.filter { !exported.contains($0) }
        guard !pending.isEmpty else { return 0 }
        let collection = await ensureAlbum()
        var saved = 0
        for ref in pending {
            guard let img = PhotoStore.image(ref) else { continue }
            if await addImage(img, to: collection) { exported.insert(ref); saved += 1 }
        }
        markExported(exported)
        return saved
    }

    // MARK: - 내부

    private static func findAlbum() -> PHAssetCollection? {
        let opts = PHFetchOptions(); opts.predicate = NSPredicate(format: "title = %@", albumName)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: opts).firstObject
    }

    private static func ensureAlbum() async -> PHAssetCollection? {
        if let existing = findAlbum() { return existing }
        return await withCheckedContinuation { cont in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let req = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                placeholder = req.placeholderForCreatedAssetCollection
            } completionHandler: { ok, _ in
                guard ok, let id = placeholder?.localIdentifier else { cont.resume(returning: nil); return }
                cont.resume(returning:
                    PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject)
            }
        }
    }

    private static func addImage(_ image: UIImage, to collection: PHAssetCollection?) async -> Bool {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                let create = PHAssetChangeRequest.creationRequestForAsset(from: image)
                if let collection, let placeholder = create.placeholderForCreatedAsset,
                   let albumReq = PHAssetCollectionChangeRequest(for: collection) {
                    albumReq.addAssets([placeholder] as NSArray)
                }
            } completionHandler: { ok, _ in cont.resume(returning: ok) }
        }
    }
}
