import SwiftUI

// MARK: - 성장 링 (계층 3, 기능 진입) — DESIGN.md §8.4

/// 성장 기록의 정체성 모션. 진입 시 링이 차오르고 몇 번 호흡한 뒤 정지한다.
/// trim·scale만 애니메이션(60fps). reduce motion 시 즉시 채운 정적 링.
struct GrowthRingView: View {
    var size: CGFloat = 22
    var lineWidth: CGFloat = 3
    var color: Color = AppColors.primary
    var progress: CGFloat = 0.72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trim: CGFloat = 0
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: trim)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
        .scaleEffect(breathe ? 1.06 : 1.0)
        .onAppear {
            guard !reduceMotion else { trim = progress; return }
            withAnimation(.easeOut(duration: 0.9)) { trim = progress }
            withAnimation(.easeInOut(duration: 1.5).repeatCount(4, autoreverses: true).delay(0.9)) {
                breathe = true
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 레이더 스윕 (계층 3, 기능 진입) — DESIGN.md §8.4

/// 주변/응급 탐색을 표현하는 레이더 스윕. 로딩 인디케이터로 사용(§7.1 로딩 필수).
/// rotation만 애니메이션(60fps). reduce motion 시 정적 동심원 + 중심점.
struct RadarSweepView: View {
    var size: CGFloat = 76
    var color: Color = AppColors.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 0

    var body: some View {
        ZStack {
            ForEach(1...3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.16), lineWidth: 1)
                    .frame(width: size * CGFloat(i) / 3, height: size * CGFloat(i) / 3)
            }

            // 스윕 트레일 (각도 그라데이션)
            Circle()
                .fill(AngularGradient(
                    gradient: Gradient(colors: [color.opacity(0.32), .clear]),
                    center: .center
                ))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(angle))

            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                angle = 360
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 40) {
        GrowthRingView(size: 40)
        RadarSweepView()
    }
    .padding()
}
