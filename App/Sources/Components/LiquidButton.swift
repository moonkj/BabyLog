import SwiftUI

/// 누르면 살짝 축소 (DESIGN.md §7 PressBtn / babylog-ds.css .bl-btn:active)
struct LiquidPressStyle: ButtonStyle {
    var scale: CGFloat = 0.975
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 시그니처 "물 흐르는" 리퀴드 CTA (`.bl-liquid`) — 광택 메니스커스 + 흐르는 빛 띠.
/// 핸드오프 §3.4 / babylog-ds.css 이식. reduce-motion 시 빛 띠 비활성.
struct LiquidButton<Label: View>: View {
    var fill: Color = AppColors.primary
    var cornerRadius: CGFloat = Radius.md
    var action: () -> Void
    @ViewBuilder var label: () -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flow = false

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(fill)
                .overlay { meniscus }
                .overlay { if !reduceMotion { band } }
                .clipShape(shape)
        }
        .buttonStyle(LiquidPressStyle())
        .blShadow(.fab)
        .onAppear { flow = true }
        .onDisappear { flow = false }   // 디버거 D-FIX: 오프스크린 시 애니 중단(배터리/GPU)
    }

    // 광택 메니스커스 (항상)
    private var meniscus: some View {
        ZStack {
            RadialGradient(colors: [.white.opacity(0.34), .clear],
                           center: UnitPoint(x: 0.5, y: -0.16),
                           startRadius: 0, endRadius: 200)
            LinearGradient(colors: [.white.opacity(0.12), .black.opacity(0.05)],
                           startPoint: .top, endPoint: .bottom)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }

    // 흐르는 빛 띠 (4.6s 루프, skewX -14°)
    private var band: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(colors: [.clear, .white.opacity(0.6), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.5, height: geo.size.height * 1.6)
                .blur(radius: 3)
                .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.249, d: 1, tx: 0, ty: 0))
                .offset(x: flow ? w * 1.28 : -w * 0.5, y: -geo.size.height * 0.3)
                .animation(.timingCurve(0.55, 0.06, 0.2, 1, duration: 4.6).repeatForever(autoreverses: false),
                           value: flow)
        }
        .allowsHitTesting(false)
    }
}
