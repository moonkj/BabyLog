import SwiftUI

/// 스플래시 새싹 ★ — DESIGN.md §8.2 (계층1)
/// 앱 콜드 스타트 시 씨앗→새싹이 돋고 물결이 한 번 퍼진 뒤 사라진다(약 0.9초).
/// transform/opacity만(60fps). reduce motion 시 정적 로고만 잠깐 노출.
struct SeedlingSplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sprout = false
    @State private var ripple = false
    @State private var fade = false

    var body: some View {
        ZStack {
            AppColors.canvas.ignoresSafeArea()

            // 물결 1회
            Circle()
                .stroke(Color(hex: 0x2E7A5C).opacity(0.18), lineWidth: 2)
                .frame(width: 120, height: 120)
                .scaleEffect(ripple ? 2.2 : 0.3)
                .opacity(ripple ? 0 : 0.9)

            VStack(spacing: 14) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2E7A5C))
                    .scaleEffect(sprout ? 1 : 0.2)
                    .rotationEffect(.degrees(sprout ? 0 : -25), anchor: .bottom)
                    .opacity(sprout ? 1 : 0)

                Text("베이비로그")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
                    .opacity(sprout ? 1 : 0)
            }
        }
        .opacity(fade ? 0 : 1)
        .onAppear { run() }
        .accessibilityHidden(true)
    }

    private func run() {
        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) { sprout = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeIn(duration: 0.3)) { fade = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onFinish() }
            }
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { sprout = true }
        withAnimation(.easeOut(duration: 0.9)) { ripple = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeIn(duration: 0.35)) { fade = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinish() }
        }
    }
}
