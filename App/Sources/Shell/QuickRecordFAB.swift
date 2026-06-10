import SwiftUI

/// 빠른 기록 스피드다이얼 (기능 8.4) — 탭 시 액션이 위로 펼쳐지고 FAB는 45° 회전.
/// 모드별 액션 분기(육아: 성장측정/사진/메모 · 임신: 태동/배사진/메모).
struct QuickRecordFAB: View {
    var mode: AppMode
    @State private var open = false

    private var actions: [(icon: String, label: String)] {
        mode == .pregnancy
            ? [("heart.fill", "태동"), ("photo.fill", "배 사진"), ("square.and.pencil", "메모")]
            : [("ruler.fill", "성장 측정"), ("camera.fill", "사진"), ("square.and.pencil", "메모")]
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if open {
                ForEach(actions, id: \.label) { a in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { open = false }
                    } label: {
                        HStack(spacing: 9) {
                            Text(a.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColors.ink)
                                .padding(.horizontal, 11).frame(height: 32)
                                .background(AppColors.surface, in: Capsule())
                                .blShadow(.card)
                            Image(systemName: a.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppColors.primary)
                                .frame(width: 44, height: 44)
                                .background(AppColors.surface, in: Circle())
                                .blShadow(.card)
                        }
                    }
                    .buttonStyle(LiquidPressStyle())
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { open.toggle() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AppColors.primary, in: Circle())
                    .rotationEffect(.degrees(open ? 45 : 0))
            }
            .buttonStyle(LiquidPressStyle())
            .blShadow(.fab)
            .accessibilityLabel("빠른 기록")
        }
    }
}
