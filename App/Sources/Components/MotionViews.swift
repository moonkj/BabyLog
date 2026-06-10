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

#Preview {
    CheckDrawView(isOn: true, size: 40)
        .padding()
}
