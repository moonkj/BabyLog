import SwiftUI

/// 생애 시계 ★ — DESIGN.md §8.2 (계층 1, 최우선 시그니처, 상시 노출)
///
/// TickLab 회전 나사의 직계 후손. "시간이 흐르고 아이가 자란다"는 앱의 본질을
/// 작은 초침 시계로 표현한다. 아이 프로필 옆에 두고 D+day와 함께 노출한다.
///
/// - 실제 현재 초에 맞춰 초침이 똑딱(steps 느낌) 회전한다(TimelineView .periodic).
/// - transform(rotation)만 애니메이션 → 60fps.
/// - reduce motion 시 애니메이션 없이 현재 초 위치로 스냅.
/// - 장식 모션이므로 VoiceOver에서는 숨김(의미는 동반 D+day 텍스트가 전달).
struct LifeClockView: View {
    var size: CGFloat = 28
    var hand: Color = AppColors.gold
    var ring: Color = AppColors.ink3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let second = Calendar.current.component(.second, from: context.date)
            ZStack {
                Circle()
                    .stroke(ring.opacity(0.45), lineWidth: max(1, size * 0.045))

                // 12·3·6·9 위치 미세 눈금
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(ring.opacity(0.4))
                        .frame(width: size * 0.05, height: size * 0.1)
                        .offset(y: -size * 0.40)
                        .rotationEffect(.degrees(Double(i) * 90))
                }

                // 초침
                Capsule()
                    .fill(hand)
                    .frame(width: max(1.2, size * 0.06), height: size * 0.36)
                    .offset(y: -size * 0.16)
                    .rotationEffect(.degrees(Double(second) * 6))
                    .animation(Motion.respecting(reduceMotion, .easeOut(duration: 0.18)),
                               value: second)

                // 중심 허브
                Circle()
                    .fill(hand)
                    .frame(width: size * 0.12, height: size * 0.12)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        LifeClockView(size: 28)
        LifeClockView(size: 44, hand: AppColors.primary)
    }
    .padding()
}
