// PhotoStore.swift
// BabyLog — 로컬 사진 저장 (서버 업로드 없음 · CLAUDE.md 절대 원칙)
//
// 사진은 기기 로컬(Application Support)에만 저장한다. 무료=로컬, 서버 백업=Pro(추후).

import UIKit

enum PhotoStore {

    /// 사진 디렉토리 (없으면 생성)
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BabyLog/photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 이미지를 JPEG로 저장하고 파일명을 반환. 실패 시 nil.
    /// 과도한 해상도를 줄여 용량을 아낀다(최대 변 2048px).
    static func save(_ image: UIImage, quality: CGFloat = 0.85) -> String? {
        let resized = downscaled(image, maxDimension: 2048)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// 파일명으로 이미지를 로드. 없으면 nil.
    static func image(_ name: String?) -> UIImage? {
        guard let name, !name.isEmpty else { return nil }
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// 사진 삭제 (기록 삭제 시).
    static func delete(_ name: String?) {
        guard let name, !name.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
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

    /// photos 디렉토리의 모든 파일을 파일명→원본 데이터로 반환(레거시 백업 포맷 폴백용).
    static func allPhotoData() -> [String: Data] {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return [:] }
        var out: [String: Data] = [:]
        for name in names {
            if let data = try? Data(contentsOf: directory.appendingPathComponent(name)) {
                out[name] = data
            }
        }
        return out
    }

    /// 백업에서 사진 파일들을 복원(이미 있으면 유지, 없으면 기록).
    /// 보안: 조작된 백업의 경로 탈출(`../`·하위경로) 방지 — 안전한 파일명만 photos 디렉토리에 기록.
    static func restorePhotos(_ files: [String: Data]) {
        for (name, data) in files where isSafeFilename(name) {
            let url = directory.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? data.write(to: url, options: .atomic)
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
