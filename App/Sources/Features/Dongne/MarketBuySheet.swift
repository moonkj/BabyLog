// MarketBuySheet.swift
// BabyLog · Features/Dongne — 마켓 구매 플로우 (로컬 거래 확정)
//
// 당근마켓식 구매 진행: 매물 확인 → 거래 방식·안심거래 안내 → 거래 확정.
// 확정 시 매물이 판매완료로 바뀌고 채팅에 거래 메시지가 남는다. (실시간 결제·에스크로는 백엔드 단계)

import SwiftUI

struct MarketBuySheet: View {
    let item: MarketItem
    var onChat: () -> Void = {}

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var method: TradeMethod = .direct
    @State private var done = false

    enum TradeMethod: String, CaseIterable {
        case direct = "직거래"
        case delivery = "택배거래"
        var icon: String { self == .direct ? "figure.2.arms.open" : "shippingbox.fill" }
        var note: String { self == .direct ? "동네에서 직접 만나 거래" : "택배로 받기 (배송비 협의)" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.s5) {
                        itemSummary
                        methodPicker
                        safeTradeCard
                        Spacer(minLength: Spacing.s2)
                    }
                    .padding(Spacing.s4)
                    .padding(.bottom, 90)
                }
                .background(AppColors.canvas.ignoresSafeArea())

                VStack { Spacer(); bottomBar }

                if done { rewardOverlay }
            }
            .navigationTitle("구매하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }

    private var itemSummary: some View {
        BLCard(padding: 12) {
            HStack(spacing: 12) {
                Group {
                    if let img = PhotoStore.image(item.photoRefs.first) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        PhotoPlaceholder(seed: item.photoSeed, cornerRadius: 0)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink).lineLimit(2)
                    Text(item.isFree ? "무료나눔" : "\(item.price.formatted())원")
                        .font(AppFont.num(17, weight: .heavy))
                        .foregroundStyle(item.isFree ? AppColors.primary : AppColors.ink)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("거래 방식").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
            ForEach(TradeMethod.allCases, id: \.self) { m in
                Button { method = m } label: {
                    HStack(spacing: 12) {
                        Image(systemName: m.icon).font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(method == m ? AppColors.primary : AppColors.ink3)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.rawValue).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                            Text(m.note).font(AppFont.caption).foregroundStyle(AppColors.ink3)
                        }
                        Spacer()
                        Image(systemName: method == m ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(method == m ? AppColors.primary : AppColors.line2)
                    }
                    .padding(Spacing.s3)
                    .background(method == m ? AppColors.primaryTint : AppColors.surface,
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(method == m ? AppColors.primary.opacity(0.4) : AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))
            }
        }
    }

    private var safeTradeCard: some View {
        BLCard(padding: 13, flat: true) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "shield.checkered").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3B6FA8))
                Text("주민센터·공공도서관 앞 등 공공장소에서 만나면 더 안전해요. BabyLog는 거래에 직접 개입하지 않습니다.")
                    .font(AppFont.caption).foregroundStyle(AppColors.ink2).lineSpacing(3)
            }
        }
        .background(Color(hex: 0xE6F1FB), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { dismiss(); onChat() } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.ink2)
                    .frame(width: 52, height: 52)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
            }
            .accessibilityLabel("판매자와 채팅")

            LiquidButton(action: {
                store.purchaseMarketItem(id: item.id)
                Haptics.success()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { done = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
            }) {
                Text(item.isFree ? "나눔 받기" : "거래 확정하기").frame(maxWidth: .infinity)
            }
            .accessibilityLabel("거래 확정하기")
        }
        .padding(.horizontal, Spacing.s4).padding(.top, 12).padding(.bottom, 26)
        .background(AppColors.surface)
        .overlay(alignment: .top) { Rectangle().fill(AppColors.line).frame(height: 1) }
    }

    private var rewardOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: Spacing.s4) {
                ZStack {
                    MilestoneBurst()
                    Circle().fill(AppColors.primaryTint).frame(width: 96, height: 96)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                Text("거래가 확정됐어요!").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                Text("따뜻한 거래 감사해요 🤍").font(AppFont.callout).foregroundStyle(AppColors.ink3)
            }
            .padding(Spacing.s6)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .blShadow(.card)
        }
        .transition(.opacity)
    }
}
