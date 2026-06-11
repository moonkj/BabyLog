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
