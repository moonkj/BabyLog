// MarketPhotoView.swift
// BabyLog · 마켓 사진 뷰 — 원격(Storage URL) > 로컬(PhotoStore) > 플레이스홀더 순으로 표시.
// 목록 카드·상세 공용. scaledToFill 가정(상위에서 frame/clip).

import SwiftUI

struct MarketPhotoView: View {
    var urls: [String] = []      // 서버 공개 사진 URL
    var refs: [String] = []      // 로컬 PhotoStore 참조
    var seed: Int = 0            // 플레이스홀더 그라데이션 시드
    var index: Int = 0
    var cornerRadius: CGFloat = 0

    var body: some View {
        if index < urls.count, let url = URL(string: urls[index]) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    PhotoPlaceholder(seed: seed, cornerRadius: cornerRadius)
                case .empty:
                    ZStack {
                        PhotoPlaceholder(seed: seed, cornerRadius: cornerRadius)
                        ProgressView()
                    }
                @unknown default:
                    PhotoPlaceholder(seed: seed, cornerRadius: cornerRadius)
                }
            }
        } else if index < refs.count, let img = PhotoStore.image(refs[index]) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            PhotoPlaceholder(seed: seed, cornerRadius: cornerRadius)
        }
    }
}
