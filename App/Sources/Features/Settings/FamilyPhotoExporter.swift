// FamilyPhotoExporter.swift
// BabyLog — 조부모 사진 공유 지원
//
// 아이 사진을 사용자 본인의 '사진 앱(iCloud Photos)' 전용 앨범에 담는다.
// 이렇게 사진 앱에 들어가면 사용자가 거기서 'iCloud 공유 앨범 + 공개 웹사이트'를 켜서
// - 아이폰 조부모: 공유 앨범 구독(사진 앱에서 큰 사진으로 봄)
// - 안드로이드 조부모: 공개 웹 링크(브라우저로 봄, Apple ID 불필요)
// 양쪽 모두 무료로 공유할 수 있다. 우리 서버를 거치지 않아 비용 0 + '사진 서버 비전송' 원칙 유지.
//
// ⚠️ iOS는 '공개 앨범 링크'를 앱이 자동 생성하는 API를 제공하지 않는다.
//    따라서 앱은 '사진 앱 앨범에 담기 + 안내'까지만 하고, 마지막 공유 링크 생성은
//    사용자가 사진 앱에서 직접 한다(가장 적은 단계로 안내).

import Photos
import UIKit

enum FamilyPhotoExporter {

    enum ExportError: Error { case noPermission, changeFailed }

    /// 사진 권한 요청(읽기/쓰기 — 기존 앨범 재사용 위해). 허용/제한 시 true.
    static func ensurePermission() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .authorized || current == .limited { return true }
        let status: PHAuthorizationStatus = await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
        }
        return status == .authorized || status == .limited
    }

    /// 지정 이름의 앨범을 찾는다(없으면 nil). readWrite 권한 필요.
    private static func findAlbum(named name: String) -> PHAssetCollection? {
        let fetch = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        var found: PHAssetCollection?
        fetch.enumerateObjects { collection, _, stop in
            if collection.localizedTitle == name { found = collection; stop.pointee = true }
        }
        return found
    }

    /// 아이 사진(로컬 ref들)을 사진 앱의 전용 앨범에 담는다.
    /// - Parameters:
    ///   - refs: PhotoStore 로컬 파일명 목록(오래된→최신 순 권장)
    ///   - albumName: "베이비로그 · {아이}" 같은 앨범명(없으면 생성, 있으면 추가)
    ///   - skip: 이미 내보낸 ref(중복 추가 방지)
    /// - Returns: 새로 추가된 사진 수와 그 ref 목록(호출측이 누적 저장).
    static func export(refs: [String], albumName: String, skip: Set<String>) async throws -> (added: Int, exported: [String]) {
        guard await ensurePermission() else { throw ExportError.noPermission }

        // 아직 안 내보낸 것만, 실제 이미지가 있는 것만
        let pending: [(ref: String, image: UIImage)] = refs
            .filter { !skip.contains($0) }
            .compactMap { ref in PhotoStore.image(ref).map { (ref, $0) } }

        guard !pending.isEmpty else { return (0, []) }   // 권한은 OK, 새로 담을 사진 없음

        let existing = findAlbum(named: albumName)

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let albumRequest: PHAssetCollectionChangeRequest
                if let existing {
                    albumRequest = PHAssetCollectionChangeRequest(for: existing)!
                } else {
                    albumRequest = PHAssetCollectionChangeRequest
                        .creationRequestForAssetCollection(withTitle: albumName)
                }
                var placeholders: [PHObjectPlaceholder] = []
                for (_, image) in pending {
                    let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    if let ph = assetRequest.placeholderForCreatedAsset { placeholders.append(ph) }
                }
                albumRequest.addAssets(placeholders as NSArray)
            } completionHandler: { success, error in
                if success { cont.resume(returning: ()) }
                else { cont.resume(throwing: error ?? ExportError.changeFailed) }
            }
        }

        return (pending.count, pending.map(\.ref))
    }
}
