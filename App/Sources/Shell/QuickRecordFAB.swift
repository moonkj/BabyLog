import SwiftUI

/// 빠른 기록 스피드다이얼 (기능 8.4) — 탭 시 액션이 위로 펼쳐지고 FAB는 45° 회전.
/// 모드별 액션 분기(육아: 성장측정/사진/메모 · 임신: 태동/배사진/메모).
struct QuickRecordFAB: View {
    var mode: AppMode
    /// 방금 드래그로 이동했으면 true — 직후 탭(메뉴 열림)을 무시한다.
    var suppressTap: Bool = false
    var onQuickRecord: () -> Void = {}
    @State private var open = false

    // 글래스 FAB 배경 — 프로스티드(뒤 화면이 블러로 비침) + 아주 옅은 틴트 + 약한 글로스
    // 뱃지 카드 수준 투명도: 흰 글로스/틴트를 최소화해 ultraThinMaterial 블러가 드러나게 한다.
    // 글래스 FAB 배경 — 뱃지카드와 동일 구조(반투명 단색 + ultraThinMaterial)로 뒤가 비침.
    // 세이지 그린(브랜드) 틴트. 회전 sheen/흰 글로스 제거 → 은색 느낌 없이 명확한 색 글래스.
    private var fabBackground: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial)                      // 글래스 블러(뒤가 비침)
            Circle().fill(BadgeTone.mint.ink.opacity(0.5))         // 세이지 그린 반투명(뱃지카드 톤)
            // 아주 옅은 상단 하이라이트(정적) — 유리 질감만, 투명도 유지
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.18), .clear],
                        center: .topLeading, startRadius: 1, endRadius: 30
                    )
                )
            // 얇은 림
            Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1)
        }
    }

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
                        onQuickRecord()
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
                    .accessibilityLabel(a.label)   // 디버거 D-FIX: 하위 액션 VoiceOver 라벨
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }

            // Button 대신 onTapGesture — 이동한 터치는 탭으로 인식되지 않아(드래그와 충돌 없음)
            // 드래그 후 메뉴가 열리는 문제를 근본적으로 막는다.
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(fabBackground)
                .clipShape(Circle())
                .rotationEffect(.degrees(open ? 45 : 0))
                .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
                .contentShape(Circle())
                .onTapGesture {
                    if suppressTap { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { open.toggle() }
                }
                .accessibilityLabel("빠른 기록")
                .accessibilityAddTraits(.isButton)
        }
    }
}
