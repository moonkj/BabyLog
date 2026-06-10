import SwiftUI

// MARK: - 체크 드로우 (계층 4) — DESIGN.md §8.5

/// 체크마크 Path — 코드 기반 에셋(§8.6).
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.18, y: h * 0.53))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.74))
        p.addLine(to: CGPoint(x: w * 0.84, y: h * 0.28))
        return p
    }
}

/// 체크 드로우 — 예방접종 완료·체크리스트에서 체크마크가 그려진다.
/// trim 진행도만 애니메이션(60fps). reduce motion 시 즉시 표시. 완료 시 성공 햅틱.
struct CheckDrawView: View {
    var isOn: Bool
    var size: CGFloat = 22
    var color: Color = AppColors.primary
    var haptics: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        CheckmarkShape()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: max(2, size * 0.1),
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .onAppear { progress = isOn ? 1 : 0 }
            .onChange(of: isOn) { _, on in
                withAnimation(Motion.respecting(reduceMotion, .easeOut(duration: 0.3))) {
                    progress = on ? 1 : 0
                }
                if on && haptics { Haptics.success() }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 태동 하트비트 (계층 3, 기능 진입) — DESIGN.md §8.4

/// 임신 태동/심박을 표현하는 작은 하트 펄스. 화면 진입 시 잠깐 뛰고 멈춘다(상시 아님).
/// scale만 애니메이션(60fps). reduce motion 시 정적.
struct HeartbeatView: View {
    var size: CGFloat = 16
    var color: Color = AppColors.pregnancyPink

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beat = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(color)
            .scaleEffect(beat ? 1.18 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                // 진입 시 몇 번만 뛰고 정지 ("진입했을 때만 잠깐")
                withAnimation(.easeInOut(duration: 0.5).repeatCount(6, autoreverses: true)) {
                    beat = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 에러 가벼운 흔들림 (계층 4) — DESIGN.md §8.5

/// 입력 검증 실패 시 가벼운 좌우 흔들림 (비난 없이). translation만 사용(60fps).
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat = 3
    var travel: CGFloat = 6
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = travel * sin(animatableData * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

private struct ShakeModifier: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var amount: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: amount))
            .onChange(of: trigger) { _, newValue in
                guard newValue > 0 else { return }
                Haptics.warning()
                guard !reduceMotion else { return }
                amount = 0
                withAnimation(.linear(duration: 0.4)) { amount = 1 }
            }
    }
}

extension View {
    /// 검증 실패 흔들림. `trigger`(>0, 증가)를 바꾸면 한 번 흔들리고 경고 햅틱이 울린다.
    func blShake(_ trigger: Int) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

#Preview {
    VStack(spacing: 40) {
        CheckDrawView(isOn: true, size: 40)
        HeartbeatView(size: 28)
    }
    .padding()
}
