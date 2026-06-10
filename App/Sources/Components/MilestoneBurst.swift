import SwiftUI

/// 이정표 축하 ★ — DESIGN.md §8.3 (계층 2, 감정 피크)
///
/// 첫 걸음마·100일·돌 등 특별한 순간에 별 + 색종이가 터진다.
/// 진입(삽입) 시 1회 재생 후 사라진다. transform(offset·rotation·scale)·opacity만 → 60fps.
/// reduce motion 시 중앙 별만 잠깐 정적으로 보여준다(과한 모션 배제).
///
/// 민감영역: 임신 상실 흐름에서는 호출 자체를 하지 않는다(출산 전환·아이 이정표에서만 사용).
struct MilestoneBurst: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var go = false
    @State private var starScale: CGFloat = 0.2
    @State private var starOpacity: Double = 0

    private struct Piece: Identifiable {
        let id: Int
        let color: Color
        let size: CGFloat
        let dx: CGFloat
        let dy: CGFloat
        let rotation: Double
        let isStrip: Bool
    }

    private let palette: [Color] = [
        AppColors.gold, AppColors.pregnancyPink,
        Color(hex: 0x2E7A5C), Color(hex: 0x3B6FA8), Color(hex: 0x8A5BB0)
    ]

    private var pieces: [Piece] {
        let count = 22
        return (0..<count).map { i in
            // 방사형으로 고르게 + 약간의 변주(결정적)
            let angle = (Double(i) / Double(count)) * 2 * .pi + Double(i % 3) * 0.18
            let dist: CGFloat = 90 + CGFloat((i * 37) % 70)
            return Piece(
                id: i,
                color: palette[i % palette.count],
                size: 6 + CGFloat((i * 13) % 7),
                dx: CGFloat(cos(angle)) * dist,
                dy: CGFloat(sin(angle)) * dist + 20,   // 살짝 아래로(중력감)
                rotation: Double((i * 53) % 360) + 180,
                isStrip: i % 2 == 0
            )
        }
    }

    var body: some View {
        ZStack {
            if !reduceMotion {
                ForEach(pieces) { p in
                    Group {
                        if p.isStrip {
                            Capsule().fill(p.color)
                                .frame(width: p.size * 0.5, height: p.size * 1.6)
                        } else {
                            Circle().fill(p.color)
                                .frame(width: p.size, height: p.size)
                        }
                    }
                    .rotationEffect(.degrees(go ? p.rotation : 0))
                    .offset(x: go ? p.dx : 0, y: go ? p.dy : 0)
                    .opacity(go ? 0 : 1)
                }
            }

            Image(systemName: "star.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(AppColors.gold)
                .scaleEffect(starScale)
                .opacity(starOpacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                // 정적: 별만 짧게 노출 후 사라짐
                withAnimation(.easeOut(duration: 0.25)) { starScale = 1; starOpacity = 1 }
                withAnimation(.easeIn(duration: 0.3).delay(0.7)) { starOpacity = 0 }
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { starScale = 1; starOpacity = 1 }
            withAnimation(.easeOut(duration: 1.1)) { go = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.7)) { starOpacity = 0; starScale = 1.3 }
        }
    }
}

#Preview {
    ZStack {
        AppColors.canvas.ignoresSafeArea()
        MilestoneBurst()
    }
}
