import SwiftUI

// DESIGN.md §8.4 / §8.5 — 요소별 시그니처 애니메이션 모음 (추가분)
// 모두 transform/opacity만, reduce motion 존중, 진입 시 재생.

// MARK: - 동전 플립 (가계부) §8.4

/// 3D Y축 회전으로 동전이 뒤집히는 모션. 진입 시 한 바퀴 돌고 멈춘다.
struct CoinFlipView: View {
    var size: CGFloat = 30
    var symbol: String = "wonsign.circle.fill"
    var tint: Color = AppColors.gold

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(tint)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.7)) { angle = 360 }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 뱃지 광택 (프로필) §8.4

/// 획득 뱃지 위로 빛이 한 번 스치는 광택. 진입 시 1회.
struct BadgeShineModifier: ViewModifier {
    var active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var x: CGFloat = -1

    func body(content: Content) -> some View {
        content.overlay {
            if active && !reduceMotion {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: x * geo.size.width)
                    .blendMode(.plusLighter)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.9).delay(0.2)) { x = 1.4 }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    /// 뱃지 광택 스침 (획득 시).
    func badgeShine(_ active: Bool) -> some View { modifier(BadgeShineModifier(active: active)) }
}

// MARK: - 반짝임 (AI) §8.4

/// AI 기능을 암시하는 별빛 반짝임. 은은하게 반복(소수 회).
struct SparkleTwinkleView: View {
    var size: CGFloat = 15
    var tint: Color = AppColors.gold

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .scaleEffect(on ? 1.15 : 0.9)
            .opacity(on ? 1 : 0.6)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { on = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 야간 달 (설정) §8.4

/// 야간 모드를 표현하는 달 — 살짝 차오르듯 흔들린다.
struct MoonSwingView: View {
    var size: CGFloat = 17
    var tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Image(systemName: "moon.fill")
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(on ? 10 : -10), anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { on = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 대화 말풍선 점 (채팅) §8.5

/// 입력 중을 나타내는 점 3개 통통.
struct TypingDotsView: View {
    var tint: Color = AppColors.ink3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.0 : 0.55)
                    .opacity(phase == i ? 1 : 0.5)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) { phase = (phase + 1) % 3 }
            }
        }
        .accessibilityLabel("입력 중")
    }
}

// MARK: - 카메라 포커스 (성장 카드 공유) §8.4

/// 렌즈 초점 잡히듯 포커스 브라켓이 좁혀졌다 펴진다.
struct CameraFocusView: View {
    var size: CGFloat = 16
    var tint: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focus = false

    var body: some View {
        ZStack {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
                .scaleEffect(focus ? 0.92 : 1.0)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) { focus = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 까닥이는 이웃 (동네 크루) §8.4

/// 사람 아이콘이 까닥(좌우 기울임)하며 친근함을 표현.
struct NoddingNeighborView: View {
    var size: CGFloat = 30
    var tint: Color = AppColors.primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nod = false

    var body: some View {
        Image(systemName: "person.2.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(nod ? 6 : -6), anchor: .bottom)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { nod = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 30) {
        CoinFlipView(size: 40)
        SparkleTwinkleView(size: 28)
        MoonSwingView(size: 28, tint: .indigo)
        CameraFocusView(size: 28, tint: .indigo)
        NoddingNeighborView(size: 40)
        TypingDotsView()
    }
    .padding()
}
