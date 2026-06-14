import SwiftUI
import UIKit

/// 전체화면 사진 뷰어 — DESIGN.md §7.2 (사진 탭 풀스크린 · 핀치 줌, 인스타식).
///
/// 사진 감상 컨텍스트라 배경은 어둡게(앱 라이트 정책과 별개, 사진이 돋보이도록).
/// 핀치 줌 · 더블탭 줌 토글 · 아래로 스와이프 닫기 지원.
struct FullScreenPhotoView: View {
    let image: UIImage
    var onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var gestureScale: CGFloat = 1
    @State private var dragOffset: CGSize = .zero

    private var totalScale: CGFloat { max(1, scale * gestureScale) }

    var body: some View {
        // ZStack 기본 정렬(center) — 사진이 화면 가운데에 오도록. (이전 .topTrailing은
        // 닫기 버튼용이었지만 사진까지 상단에 붙던 문제 → 닫기 버튼은 overlay로 분리)
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(totalScale)
                .offset(dragOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { gestureScale = $0 }
                        .onEnded { _ in
                            scale = max(1, min(4, scale * gestureScale))
                            gestureScale = 1
                        }
                )
                .simultaneousGesture(
                    // 확대 안 했을 때만 아래로 스와이프 → 닫기
                    DragGesture()
                        .onChanged { v in
                            if totalScale <= 1.01 { dragOffset = v.translation }
                        }
                        .onEnded { v in
                            if totalScale <= 1.01, v.translation.height > 110 {
                                onClose()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { dragOffset = .zero }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.easeOut(duration: 0.22)) {
                        scale = totalScale > 1.01 ? 1 : 2.5
                    }
                }
                .accessibilityLabel("사진 전체보기. 핀치로 확대, 더블탭으로 확대·축소.")
        }
        // 닫기 버튼 — 사진 정렬과 무관하게 항상 우상단 고정
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                ZStack {
                    Circle().fill(.black.opacity(0.4)).frame(width: 40, height: 40)
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, Spacing.s4)
            .padding(.trailing, Spacing.s4)
            .accessibilityLabel("사진 닫기")
        }
        .statusBarHidden(true)
    }
}
