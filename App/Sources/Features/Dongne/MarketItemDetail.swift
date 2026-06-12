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
    @State private var showBuySheet = false
    @State private var statusBusy = false       // 상태 변경 중복 탭 방지(서버 정합)
    @State private var deleteBusy = false        // 삭제 중복 탭 방지
    @State private var showDeleteFailAlert = false
    @Environment(\.dismiss) private var dismiss

    private var liveItem: MarketItem { store.marketItems.first(where: { $0.id == item.id }) ?? item }

    /// 판매 상태 변경 — 로컬 우선 갱신 + (구성 시) 서버 동기화, 실패 시 롤백.
    private func changeStatus(_ newStatus: MarketStatus) {
        guard !statusBusy else { return }
        let prev = liveItem.status
        guard prev != newStatus else { return }
        store.setMarketStatus(id: item.id, newStatus)   // 로컬 우선 반영
        guard SupabaseConfig.isConfigured else { return }
        let id = item.id
        statusBusy = true
        Task { @MainActor in
            let ok = await MarketBackend.setStatus(id: id, status: newStatus)
            if !ok { store.setMarketStatus(id: id, prev) }   // 실패 시 이전 상태로 롤백
            statusBusy = false
        }
    }

    /// 매물 삭제 — 로컬 우선 삭제 + (구성 시) 서버 동기화. 서버 실패 시 복원 후 안내, 화면 유지.
    private func deleteItem() {
        guard !deleteBusy else { return }
        guard SupabaseConfig.isConfigured else {
            store.deleteMarketItem(id: item.id)
            dismiss()
            return
        }
        let id = item.id
        let urls = liveItem.photoURLs
        let snapshot = liveItem            // 서버 실패 시 로컬 복원용
        store.deleteMarketItem(id: id)     // 로컬 우선 삭제
        deleteBusy = true
        Task { @MainActor in
            let ok = await MarketBackend.deleteItem(id: id, photoURLs: urls)
            deleteBusy = false
            if ok {
                dismiss()
            } else {
                store.addMarketItem(snapshot)   // 실패 시 복원, 화면 유지
                showDeleteFailAlert = true
            }
        }
    }

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
                onChat: { showChatSheet = true },
                onBuy: { showBuySheet = true }
            )
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if liveItem.mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("판매중으로") { changeStatus(.selling) }
                        Button("예약중으로") { changeStatus(.reserved) }
                        Button("판매완료로") { changeStatus(.sold) }
                        Divider()
                        Button("매물 삭제", role: .destructive) { deleteItem() }
                            .disabled(deleteBusy)
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
        .sheet(isPresented: $showBuySheet) {
            MarketBuySheet(item: liveItem, onChat: { showChatSheet = true })
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .alert("삭제하지 못했어요", isPresented: $showDeleteFailAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("네트워크 문제로 매물을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.")
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
