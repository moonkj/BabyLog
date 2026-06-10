// PhotoPickerView.swift
// BabyLog · 재사용 사진 선택 컴포넌트
// SwiftUI + PhotosUI 전용 — 서버 미전송, 온디바이스 로컬 처리 (CLAUDE.md 절대원칙)

import SwiftUI
import PhotosUI

// MARK: - PhotoPickerButton

/// PhotosUI 기반 사진 선택 버튼.
/// 선택한 이미지를 `image` 바인딩으로 전달하며 최대 2000px로 다운샘플한다.
/// 사진은 서버로 전송되지 않고 온디바이스에만 보관된다 (CLAUDE.md 절대원칙).
struct PhotoPickerButton<Label: View>: View {
    @Binding var image: UIImage?
    @ViewBuilder var label: () -> Label

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isLoading = false

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            label()
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadImage(from: newItem)
            }
        }
    }

    // MARK: - Private

    @MainActor
    private func loadImage(from item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let downsampled = await downsample(data: data, maxDimension: 2000)
            image = downsampled
        } catch {
            // 선택 실패 시 기존 이미지 유지
        }
    }

    /// 메모리 보호: 최대 변(max dimension) 2000px 이하로 다운샘플.
    /// CGImageSource 기반 썸네일 API — UIImage 전체 디코드를 피한다.
    private func downsample(data: Data, maxDimension: CGFloat) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,   // EXIF 방향 자동 보정
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ]
            guard
                let source = CGImageSourceCreateWithData(data as CFData, nil),
                let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}

// MARK: - SelectedPhotoView

/// 선택된 이미지 미리보기. 이미지가 없으면 `placeholder`를 표시한다.
struct SelectedPhotoView<Placeholder: View>: View {
    var image: UIImage?
    var cornerRadius: CGFloat = Radius.lg
    @ViewBuilder var placeholder: () -> Placeholder

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            placeholder()
        }
    }
}
