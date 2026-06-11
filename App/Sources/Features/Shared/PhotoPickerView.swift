// PhotoPickerView.swift
// BabyLog · 재사용 사진 선택 컴포넌트
// SwiftUI + PhotosUI 전용 — 서버 미전송, 온디바이스 로컬 처리 (CLAUDE.md 절대원칙)

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

// MARK: - VideoPreviewView (로컬 동영상 재생)

struct VideoPreviewView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .onAppear { if player == nil { player = AVPlayer(url: url) } }
        .onDisappear { player?.pause() }
    }
}

// MARK: - PickedMovie (PhotosPicker 동영상 로드용 Transferable)

struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: received.file, to: temp)
            return PickedMovie(url: temp)
        }
    }
}

// 공용 다운샘플 (최대 변 maxDimension)
func blDownsample(data: Data, maxDimension: CGFloat = 2000) async -> UIImage? {
    await Task.detached(priority: .userInitiated) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }.value
}

// MARK: - MediaPickerButton (다중 사진 + 동영상)

/// 사진 최대 maxImages장 + 동영상 1개를 한 번에 선택. 온디바이스 로컬 처리(서버 비전송).
struct MediaPickerButton<Label: View>: View {
    var maxImages: Int = 5
    @Binding var images: [UIImage]
    @Binding var videoURL: URL?
    @ViewBuilder var label: () -> Label

    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: maxImages,
            matching: .any(of: [.images, .videos]),
            photoLibrary: .shared()
        ) {
            label()
        }
        .onChange(of: items) { _, newItems in
            Task { await load(newItems) }
        }
    }

    private func load(_ newItems: [PhotosPickerItem]) async {
        var imgs: [UIImage] = []
        var vid: URL? = nil
        for item in newItems {
            let isMovie = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            if isMovie {
                if vid == nil, let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    vid = movie.url
                }
            } else if imgs.count < maxImages {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let ui = await blDownsample(data: data) {
                    imgs.append(ui)
                }
            }
        }
        let finalImgs = imgs, finalVid = vid
        await MainActor.run {
            images = finalImgs
            videoURL = finalVid
        }
    }
}

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
            // scaledToFill은 프레임을 넘치므로, 클리핑은 호출부에서 프레임 적용 후 수행한다.
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder()
        }
    }
}
