// MarketItemDetail.swift
// BabyLog · Features/Dongne
// 마켓 매물 상세 화면 (NavigationStack push)
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketItemDetail

struct MarketItemDetail: View {
    let item: MarketItem

    @EnvironmentObject private var store: AppStore
    @State private var showChatSheet = false
    @Environment(\.dismiss) private var dismiss

    private var liveItem: MarketItem { store.marketItems.first(where: { $0.id == item.id }) ?? item }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    MarketDetailHeroPhoto(item: liveItem)
                    MarketDetailContent(item: liveItem)
                        .padding(.bottom, 96) // 하단 바 여백
                }
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            MarketDetailBottomBar(
                item: liveItem,
                isFavorited: Binding(
                    get: { store.isMarketSaved(item.id) },
                    set: { _ in store.toggleMarketSaved(item.id) }
                ),
                isMine: liveItem.mine,
                onChat: { showChatSheet = true }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if liveItem.mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("판매중으로") { store.setMarketStatus(id: item.id, .selling) }
                        Button("예약중으로") { store.setMarketStatus(id: item.id, .reserved) }
                        Button("판매완료로") { store.setMarketStatus(id: item.id, .sold) }
                        Divider()
                        Button("매물 삭제", role: .destructive) {
                            store.deleteMarketItem(id: item.id); dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("내 매물 관리")
                }
            }
        }
        .sheet(isPresented: $showChatSheet) {
            MarketChatSheet(item: liveItem)
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("마켓 상세 — 일반") {
    NavigationStack {
        MarketItemDetail(item: MarketItem(
            id: "p1",
            title: "스토케 트립트랩 식사의자",
            category: .meal,
            grade: .s,
            monthsTag: "6개월+",
            price: 180_000,
            originalPrice: 350_000,
            isFree: false,
            hasRecall: false,
            isGraduate: false,
            sellerName: "보리맘",
            sellerTier: .golden,
            distanceText: "210m",
            favoriteCount: 34,
            photoSeed: 5
        ))
    }
}

#Preview("마켓 상세 — 리콜 경고") {
    NavigationStack {
        MarketItemDetail(item: MarketItem(
            id: "p3",
            title: "코니 바운서 아기 그네",
            category: .toy,
            grade: .b,
            monthsTag: "0–6개월",
            price: 35_000,
            originalPrice: 89_000,
            isFree: false,
            hasRecall: true,
            isGraduate: true,
            sellerName: "민서맘",
            sellerTier: .warm,
            distanceText: "320m",
            favoriteCount: 12,
            photoSeed: 3
        ))
    }
}

#Preview("채팅 시트") {
    MarketChatSheet(item: MarketItem(
        id: "p1",
        title: "스토케 트립트랩 식사의자",
        category: .meal,
        grade: .s,
        monthsTag: "6개월+",
        price: 180_000,
        originalPrice: 350_000,
        isFree: false,
        hasRecall: false,
        isGraduate: false,
        sellerName: "보리맘",
        sellerTier: .golden,
        distanceText: "210m",
        favoriteCount: 34,
        photoSeed: 5
    ))
}

#Preview("판매 플로우") {
    MkSellFlowSheet()
        .presentationDetents([.large])
}
#endif
