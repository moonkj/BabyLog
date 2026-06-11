import SwiftUI
import UIKit

// MARK: - 공용 플로팅 버튼 글래스 배경

/// 모든 플로팅 버튼 공용 글래스 원 배경 — 세이지 반투명(뒤 화면이 비침).
/// 화면이 바뀌어도 FAB 모양은 동일하게 유지하기 위한 단일 소스.
/// (ultraThinMaterial은 UIKit 탭뷰 위에서 블러가 안 잡혀 은색 불투명으로 보이므로 알파 반투명 사용)
struct FABGlassCircle: View {
    var body: some View {
        ZStack {
            Circle().fill(BadgeTone.mint.ink.opacity(0.45))   // 반투명 세이지 — 뒤가 비침
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.16), .clear],
                        center: .topLeading, startRadius: 1, endRadius: 30
                    )
                )
            Circle().strokeBorder(.white.opacity(0.45), lineWidth: 1)
        }
    }
}

// MARK: - 공용 드래그형 FAB (꾹 눌러 위치 이동, 위치는 전 화면 공유)

/// 화면별로 기능(action)만 다른 공용 플로팅 버튼.
/// 위치(`bl_fab_dx/dy`)·좌우(`bl_fab_side`)를 **모든 화면이 공유**하므로,
/// 한 화면에서 옮기면 홈/기록/가계부/팔기/모임 버튼이 모두 같은 자리로 이동한다.
struct DraggableFAB: View {
    let systemIcon: String
    let action: () -> Void

    @AppStorage("bl_fab_dx")   private var dx: Double = 0
    @AppStorage("bl_fab_dy")   private var dy: Double = 0
    @AppStorage("bl_fab_side") private var fabSide: String = "right"
    private var onLeft: Bool { fabSide == "left" }

    @State private var drag: CGSize = .zero
    @State private var dragging = false
    @State private var suppressTap = false

    var body: some View {
        Image(systemName: systemIcon)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(FABGlassCircle())
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
            .contentShape(Circle())
            .onTapGesture {
                if suppressTap { return }
                action()
            }
            .offset(x: dx + drag.width, y: dy + drag.height)
            .scaleEffect(dragging ? 1.12 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragging)
            .simultaneousGesture(moveGesture)
            .onAppear { clamp() }
            .accessibilityAddTraits(.isButton)
    }

    private var moveGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let d) = value {
                    if !dragging { dragging = true; Haptics.light() }
                    if let d {
                        drag = d.translation
                        if abs(d.translation.width) > 6 || abs(d.translation.height) > 6 {
                            suppressTap = true
                        }
                    }
                }
            }
            .onEnded { value in
                if case .second(true, let d?) = value {
                    let b = UIScreen.main.bounds
                    let span = b.width - 100, maxUp = b.height - 240
                    let nx = dx + d.translation.width
                    let ny = dy + d.translation.height
                    dx = onLeft ? min(span, max(0, nx)) : min(0, max(-span, nx))
                    dy = min(0, max(-maxUp, ny))
                    if abs(d.translation.width) > 6 || abs(d.translation.height) > 6 {
                        suppressTap = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { suppressTap = false }
                    }
                }
                drag = .zero
                dragging = false
                Haptics.success()
            }
    }

    /// 화면 밖에 저장된 좌표로 사라지는 것 방지 — 로드 시 화면 안으로 보정.
    private func clamp() {
        let b = UIScreen.main.bounds
        let span = b.width - 100, maxUp = b.height - 240
        dx = onLeft ? min(span, max(0, dx)) : min(0, max(-span, dx))
        dy = min(0, max(-maxUp, dy))
    }
}

// MARK: - 화면에 공용 FAB를 붙이는 모디파이어

private struct AppFABModifier: ViewModifier {
    @AppStorage("bl_fab_side") private var fabSide: String = "right"
    private var onLeft: Bool { fabSide == "left" }

    let icon: String
    let bottomPadding: CGFloat
    let action: () -> Void

    func body(content: Content) -> some View {
        content.overlay(alignment: onLeft ? .bottomLeading : .bottomTrailing) {
            DraggableFAB(systemIcon: icon, action: action)
                .padding(onLeft ? .leading : .trailing, Spacing.s5)
                .padding(.bottom, bottomPadding)
        }
    }
}

extension View {
    /// 화면별 기능만 다른 공용 플로팅 버튼을 붙인다. 모양·위치는 전 화면 공유.
    func appFAB(icon: String = "plus", bottomPadding: CGFloat = 12,
                action: @escaping () -> Void) -> some View {
        modifier(AppFABModifier(icon: icon, bottomPadding: bottomPadding, action: action))
    }
}
