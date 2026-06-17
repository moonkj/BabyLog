// PhotoStore.swift
// BabyLog — 로컬 사진 저장 (서버 업로드 없음 · CLAUDE.md 절대 원칙)
//
// 사진은 기기 로컬(Application Support)에만 저장한다. 무료=로컬, 서버 백업=Pro(추후).

import UIKit
import ImageIO

enum PhotoStore {

    /// 디코드 결과 캐시 — 같은 사진을 뷰 재평가마다 다시 디코드(수 MB)하던 비용 제거.
    /// 파일명 키. 삭제 시 무효화. (NSCache는 메모리 압박 시 자동 비움.)
    /// totalCostLimit(바이트)로 상한 — 4096px 보드 사진은 디코드 시 수십 MB라, 개수 제한만으론
    /// 수백 MB~GB까지 누적돼 메모리 압박 종료를 부른다. 바이트 예산으로 적극 축출.
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>(); c.countLimit = 80
        c.totalCostLimit = 96 * 1024 * 1024   // ~96MB 디코드 백킹스토어 예산
        return c
    }()

    /// 작게 렌더되는 곳(보드 폴라로이드·그리드)용 다운샘플 썸네일 캐시 — 풀해상도 디코드를 피해 메모리 절감.
    private static let thumbCache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>(); c.countLimit = 200
        c.totalCostLimit = 24 * 1024 * 1024
        return c
    }()

    private static func cost(_ img: UIImage) -> Int {
        guard let cg = img.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }

    /// 사진 디렉토리 (없으면 생성)
    /// 사진 저장 베이스 — 프로세스당 1회만 해석(호출마다 달라져 일부 사진이 다른 디렉토리로 갈라지는 것 방지).
    /// 샌드박스 이상 상황에서도 크래시하지 않게 폴백(applicationSupport → caches → temp).
    private static let baseDirectory: URL = {
        let fm = FileManager.default
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
    }()

    private static var directory: URL {
        let base = baseDirectory
        let dir = base.appendingPathComponent("BabyLog/photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 이미지를 JPEG로 저장하고 파일명을 반환. 실패 시 nil.
    /// 과도한 해상도를 줄여 용량을 아낀다(기본 최대 변 2048px). 성장 보드 전용 사진은 인쇄 화질 위해 4096 사용.
    static func save(_ image: UIImage, quality: CGFloat = 0.85, maxDimension: CGFloat = 2048) -> String? {
        let resized = downscaled(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            // 아동 사진은 가장 민감 — 잠금 시 보호(파일이 열려있지 않으면 잠금화면에서 읽기 불가).
            try data.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUnlessOpen])
            return name
        } catch {
            return nil
        }
    }

    /// 파일명으로 이미지를 로드. 없으면 nil.
    static func image(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        let key = name as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: key, cost: cost(img))
        return img
    }

    /// 다운샘플 썸네일 로드 — 작은 프레임에 렌더되는 곳(보드 폴라로이드·사진 그리드)에서 풀해상도 대신 사용.
    /// 풀해상도 경로(image(_:))와 캐시·키가 분리돼 기존 화면(상세·전체보기·공유카드)에는 영향 없음.
    static func thumbnail(_ name: String?, maxPixel: CGFloat) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        let key = "\(name)@\(Int(maxPixel))" as NSString
        if let cached = thumbCache.object(forKey: key) { return cached }
        let url = directory.appendingPathComponent(name)
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return image(name)   // 썸네일 생성 실패 시 풀해상도로 폴백(빈 화면 방지)
        }
        let img = UIImage(cgImage: cg)
        thumbCache.setObject(img, forKey: key, cost: cost(img))
        return img
    }

    /// 기존 사진 파일을 새 파일로 복제하고 새 파일명을 반환. 실패 시 nil.
    /// 출산 전환 시 배 사진을 아이 타임라인으로 승계할 때, 원본(임신 기록)과
    /// 사본(성장 기록)의 파일 수명을 분리하기 위해 사용한다(한쪽 삭제가 다른 쪽을 깨지 않게).
    static func copy(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        let src = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: src.path) else { return nil }
        let ext = src.pathExtension.isEmpty ? "jpg" : src.pathExtension
        let newName = "\(UUID().uuidString).\(ext)"
        do {
            try FileManager.default.copyItem(at: src, to: directory.appendingPathComponent(newName))
            return newName
        } catch {
            return nil
        }
    }

    /// 사진 삭제 (기록 삭제 시).
    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        cache.removeObject(forKey: name as NSString)   // 디코드 캐시 무효화(지운 사진 부활 방지)
        // 썸네일도 해당 파일 키만 제거(앱에서 쓰는 maxPixel: 400 그리드, 700 캔버스, 1000 상세) —
        // 전체 비움(removeAllObjects)은 보드/아이 일괄삭제 시 N번 호출돼 재디코드 폭주를 부른다.
        for px in [400, 700, 1000] { thumbCache.removeObject(forKey: "\(name)@\(px)" as NSString) }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        // iCloud 백업에서도 지우고 복원 시 부활하지 않게 툼스톤 기록(민감영역: 지운 사진 부활 금지).
        CloudSyncService.tombstonePhoto(name)
    }

    /// 동영상을 로컬로 복사하고 파일명을 반환. 서버 업로드 없음.
    static func saveVideo(from sourceURL: URL) -> String? {
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        let dest = directory.appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            return name
        } catch {
            return nil
        }
    }

    /// 동영상 로컬 파일 URL (없으면 nil).
    static func videoURL(_ name: String?) -> URL? {
        guard let name, !name.isEmpty else { return nil }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - 백업/복원 지원

    /// 사진 디렉토리(공개 — 백업 서비스용).
    static var photosDirectory: URL { directory }

    /// photos 디렉토리의 모든 파일 URL(데이터 미로딩 — 스트리밍 백업용).
    /// 안전한 단순 파일명만 포함.
    static func allPhotoFileURLs() -> [URL] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.filter { isSafeFilename($0) }.map { directory.appendingPathComponent($0) }
    }

    /// 복원 시 사진을 쓸 안전한 대상 URL(경로 탈출 차단). 안전하지 않은 이름은 nil.
    static func safeRestoreURL(for name: String) -> URL? {
        guard isSafeFilename(name) else { return nil }
        return directory.appendingPathComponent(name)
    }

    // allPhotoData()는 삭제됨 — 호출처 0(레거시 복원은 restorePhotos만 사용)이고,
    // 전체 사진을 RAM에 올리는 함정이라 무심코 재사용되면 워치독 크래시를 부른다.

    /// 백업에서 사진 파일들을 복원(이미 있으면 유지, 없으면 기록).
    /// 보안: 조작된 백업의 경로 탈출(`../`·하위경로) 방지 — 안전한 파일명만 photos 디렉토리에 기록.
    static func restorePhotos(_ files: [String: Data]) {
        for (name, data) in files where isSafeFilename(name) {
            let url = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                // 복원본도 온디바이스 저장과 동일한 파일 보호 적용(아동 사진 — 잠금 시 보호).
                try? data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            }
        }
    }

    /// 단순 파일명만 허용(경로 구분자·상위경로 토큰 차단). 백업 복원 시 디렉토리 밖 쓰기 방지.
    private static func isSafeFilename(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 255 else { return false }
        if name.contains("/") || name.contains("\\") || name.contains("..") { return false }
        if name.hasPrefix(".") { return false }
        return name == (name as NSString).lastPathComponent
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width, h = image.size.height
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: w * scale, height: h * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
