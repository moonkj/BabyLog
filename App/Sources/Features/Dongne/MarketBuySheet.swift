// MarketBuySheet.swift
// BabyLog · Features/Dongne — 마켓 구매 플로우
//
// 당근마켓식 구매 진행: 매물 확인 → 거래 방식·안심거래 안내.
// 로컬(미구성) 모드: 거래 확정 시 매물이 판매완료로 바뀌고 채팅에 거래 메시지가 남는다.
// 서버 모드: 앱이 상태를 대신 바꿀 수 없으므로 채팅으로 거래를 약속하도록 정직하게 안내한다.

import SwiftUI

struct MarketBuySheet: View {
    let item: MarketItem
    var onChat: () -> Void = {}

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var method: TradeMethod = .direct
    @State private var done = false

    /// 서버 모드 — 매물 상태는 판매자만 바꿀 수 있다. 가짜 '거래 확정'을 보여주지 않는다.
    private var serverMode: Bool { SupabaseConfig.isConfigured }

    /// 시트를 닫은 뒤 채팅을 연다. dismiss 직후 바로 다른 시트를 띄우면
    /// 시트 교체 레이스로 채팅이 안 뜰 수 있어 살짝 기다린다.
    private func goToChat() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onChat() }
    }

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
                        if serverMode { chatPromiseCard }
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
        BLCard(padding: 12, flat: true) {
            HStack(spacing: 12) {
                MarketPhotoView(urls: item.photoURLs, refs: item.photoRefs,
                                seed: item.photoSeed, index: 0, cornerRadius: 0)
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
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
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
                    .foregroundStyle(BadgeTone.blue.ink)
                Text("주민센터·공공도서관 앞 등 공공장소에서 만나면 더 안전해요. BabyLog는 거래에 직접 개입하지 않습니다.")
                    .font(AppFont.caption).foregroundStyle(AppColors.ink2).lineSpacing(3)
            }
        }
        .background(BadgeTone.blue.bg, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("안심 거래 안내. 주민센터·공공도서관 앞 등 공공장소에서 만나면 더 안전해요.")
    }

    /// 서버 모드 안내 — 거래는 채팅으로 약속하고, 상태 변경은 판매자가 한다.
    private var chatPromiseCard: some View {
        BLCard(padding: 13, flat: true) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("거래는 채팅으로 약속해요. 판매자가 예약중·판매완료로 바꾸면 목록에 반영돼요.")
                    .font(AppFont.caption).foregroundStyle(AppColors.ink2).lineSpacing(3)
            }
        }
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("거래는 채팅으로 약속해요. 판매자가 예약중 또는 판매완료로 바꾸면 목록에 반영돼요.")
    }

    /// 모드별 주 버튼 라벨 — 접근성 라벨도 이 텍스트를 그대로 쓴다.
    private var primaryTitle: String {
        if serverMode { return "채팅으로 거래 약속하기" }
        return item.isFree ? "나눔 받기" : "거래 확정하기"
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button { goToChat() } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(AppColors.ink2)
                    .frame(width: 52, height: 52)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
            }
            .accessibilityLabel("판매자와 채팅")

            LiquidButton(action: {
                if serverMode {
                    // 서버 매물은 앱이 확정할 수 없다 — 가짜 확정 대신 채팅으로 약속.
                    Haptics.light()
                    goToChat()
                } else {
                    store.purchaseMarketItem(id: item.id)
                    Haptics.success()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { done = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { dismiss() }
                }
            }) {
                Text(primaryTitle)
                    .frame(maxWidth: .infinity).frame(height: 52)
            }
            .accessibilityLabel(primaryTitle)
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
