// BadgeAwardCard.swift
// BabyLog — 뱃지 획득 전역 축하 카드
//
// 조건 충족으로 뱃지를 획득하면 어느 화면에 있든 이 카드가 떠서 알린다.
// (AppStore.pendingBadgeAward → MainTabView 오버레이에서 표시)

import SwiftUI

struct BadgeAwardCard: View {
    let badge: BadgeCatalogItem
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: Spacing.s4) {
                Text("🎉 새 뱃지 획득!")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(badge.tone.ink)

                // 회전+확대 등장하는 뱃지 + 버스트
                ZStack {
                    MilestoneBurst()
                    Circle()
                        .fill(badge.tone.bg)
                        .frame(width: 116, height: 116)
                        .overlay { Circle().stroke(badge.tone.ink.opacity(0.4), lineWidth: 2) }
                    Image(systemName: badge.systemIcon)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(badge.tone.ink)
                }
                .frame(height: 140)
                .scaleEffect(pop ? 1 : 0.3)
                .rotationEffect(.degrees(pop || reduceMotion ? 0 : -160))

                VStack(spacing: 4) {
                    Text(badge.name)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text(badge.condition)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink3)
                        .multilineTextAlignment(.center)
                }

                Button { onDismiss() } label: {
                    Text("좋아요")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(badge.tone.ink, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
            }
            .padding(Spacing.s5)
            .frame(maxWidth: 320)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .blShadow(.card)
            .padding(Spacing.s5)
        }
        .onAppear {
            Haptics.success()
            if reduceMotion { pop = true }
            else { withAnimation(.spring(response: 0.5, dampingFraction: 0.58)) { pop = true } }
            // 자동 닫힘 (사용자가 먼저 닫지 않으면)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { onDismiss() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("새 뱃지 획득: \(badge.name). \(badge.condition)")
        .accessibilityAddTraits(.isModal)
    }
}
