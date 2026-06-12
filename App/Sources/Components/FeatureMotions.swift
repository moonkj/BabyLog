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

/// 주변/응급 탐색 레이더 스윕(핸드오프 loading_radar_handoff).
/// 세이지 3중 동심원 + 회전 스윕(70° 부채꼴) + 코어/헤일로 + 골드 블립 펄스.
/// reduce motion 시 정지(블립은 은은히 표시).
struct RadarSweepView: View {
    var size: CGFloat = 76
    /// 스윕·코어 색(기본 세이지 — 핸드오프 팔레트).
    var color: Color = Color(hex: 0x4E8268)

    private let ringColor = Color(hex: 0xDBD1BF)
    private let blipColor = Color(hex: 0xB0832E)
    private let period: Double = 1.6
    private let blips: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (0.70, 0.32, 0.2), (0.30, 0.62, 0.8), (0.64, 0.70, 1.2),
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let spin = reduceMotion ? 0 : (t.truncatingRemainder(dividingBy: period) / period) * 360
            ZStack {
                // 동심원 3개(반지름 비 13/36/59)
                ring(13.0 / 59.0)
                ring(36.0 / 59.0)
                ring(1.0)

                // 회전 스윕(70° 부채꼴, 세이지 → 투명)
                Circle()
                    .fill(AngularGradient(stops: [
                        .init(color: color.opacity(0.45), location: 0),
                        .init(color: color.opacity(0.0), location: 70.0 / 360.0),
                        .init(color: color.opacity(0.0), location: 1),
                    ], center: .center))
                    .rotationEffect(.degrees(spin))

                // 코어 + 헤일로
                Circle().fill(color.opacity(0.18)).frame(width: size * 0.205, height: size * 0.205)
                Circle().fill(color).frame(width: size * 0.108, height: size * 0.108)

                // 골드 블립 펄스
                ForEach(0..<blips.count, id: \.self) { i in
                    let b = blips[i]
                    let q = reduceMotion ? 0.45 : phase(t, delay: b.delay)
                    Circle()
                        .fill(blipColor)
                        .frame(width: size * 0.075, height: size * 0.075)
                        .scaleEffect(blipScale(q))
                        .opacity(reduceMotion ? 0.75 : blipOpacity(q))
                        .position(x: size * b.x, y: size * b.y)
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private func ring(_ rel: CGFloat) -> some View {
        Circle().stroke(ringColor, lineWidth: 1.5).frame(width: size * rel, height: size * rel)
    }
    private func phase(_ t: Double, delay: Double) -> Double {
        (((t - delay).truncatingRemainder(dividingBy: period) + period).truncatingRemainder(dividingBy: period)) / period
    }
    // blip keyframe: 0~20% 숨김(.4) → 35% 등장(1) → 100% 페이드(1.3)
    private func blipOpacity(_ q: Double) -> Double {
        if q < 0.2 { return 0 }
        if q < 0.35 { return (q - 0.2) / 0.15 }
        return max(0, 1 - (q - 0.35) / 0.65)
    }
    private func blipScale(_ q: Double) -> Double {
        if q < 0.2 { return 0.4 }
        if q < 0.35 { return 0.4 + (q - 0.2) / 0.15 * 0.6 }
        return 1.0 + (q - 0.35) / 0.65 * 0.3
    }
}

#Preview {
    VStack(spacing: 40) {
        GrowthRingView(size: 40)
        RadarSweepView()
    }
    .padding()
}
