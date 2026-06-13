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
    @State private var showChatSheet = false   // 구매자: 판매자와 1:1 대화
    @State private var showThreads = false      // 판매자: 들어온 문의 스레드 목록
    @State private var showBuySheet = false
    @State private var statusBusy = false       // 상태 변경 중복 탭 방지(서버 정합)
    @State private var deleteBusy = false        // 삭제 중복 탭 방지
    @State private var showDeleteFailAlert = false
    @State private var showStatusFailAlert = false
    // 서버 모드에선 매물이 store.marketItems에 없어 liveItem.status가 진입 시점 스냅샷으로 고정된다.
    // 상태 변경을 화면에 즉시 반영하기 위한 낙관적 오버라이드(서버 동기화 실패 시 롤백).
    @State private var overrideStatus: MarketStatus?
    @Environment(\.dismiss) private var dismiss

    private var liveItem: MarketItem { store.marketItems.first(where: { $0.id == item.id }) ?? item }

    /// 화면이 읽어야 할 현재 상태 — 오버라이드 우선, 없으면 store/스냅샷 값.
    private var currentStatus: MarketStatus { overrideStatus ?? liveItem.status }

    /// 모든 하위 뷰가 currentStatus를 읽도록 status만 덮어쓴 표시용 사본.
    private var displayItem: MarketItem {
        var copy = liveItem
        copy.status = currentStatus
        return copy
    }

    /// 판매 상태 변경 — 화면 즉시 반영(오버라이드) + 로컬 우선 갱신 + (구성 시) 서버 동기화, 실패 시 롤백.
    private func changeStatus(_ newStatus: MarketStatus) {
        guard !statusBusy else { return }
        let prev = currentStatus                          // 화면이 현재 보여주는 상태(서버 모드에선 스냅샷 아님)
        guard prev != newStatus else { return }
        overrideStatus = newStatus                        // 화면 낙관적 반영(서버 모드 포함)
        store.setMarketStatus(id: item.id, newStatus)     // 로컬 우선 반영(로컬 모드용)
        guard SupabaseConfig.isConfigured else { return }
        let id = item.id
        statusBusy = true
        Task { @MainActor in
            let ok = await MarketBackend.setStatus(id: id, status: newStatus)
            if !ok {
                overrideStatus = prev                     // 화면 롤백
                store.setMarketStatus(id: id, prev)       // 로컬 변경도 되돌림
                showStatusFailAlert = true
            }
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
        store.deleteMarketItem(id: id)     // 로컬 우선 삭제(서버 모드에선 store에 없어 무동작)
        deleteBusy = true
        Task { @MainActor in
            let ok = await MarketBackend.deleteItem(id: id, photoURLs: urls)
            deleteBusy = false
            if ok {
                dismiss()
            } else {
                // 서버 모드 전용 경로(로컬 모드는 위에서 early-return). 로컬 삭제가 무동작이라
                // 재삽입하면 서버 매물이 로컬 store를 오염시키므로 복원하지 않고 안내만, 화면 유지.
                showDeleteFailAlert = true
            }
        }
    }

    /// 상태 변경 메뉴 항목 — 현재 상태(currentStatus)면 체크 표시 + 비활성.
    @ViewBuilder
    private func statusMenuButton(_ target: MarketStatus, _ title: String) -> some View {
        Button { changeStatus(target) } label: {
            if currentStatus == target {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
        .disabled(statusBusy || currentStatus == target)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    MarketDetailHeroPhoto(item: displayItem)
                    MarketDetailContent(item: displayItem)
                        .padding(.bottom, 96) // 하단 바 여백
                }
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            MarketDetailBottomBar(
                item: displayItem,
                isFavorited: Binding(
                    get: { store.isMarketSaved(item.id) },
                    set: { _ in store.toggleMarketSaved(displayItem) }   // 스냅샷 저장(관심 목록 보존)
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
                // 판매자 전용 — 들어온 문의(구매자별 1:1 스레드) 바로가기
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showThreads = true } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                    .accessibilityLabel("들어온 문의 보기")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // 현재 상태에 체크 표시 + 같은 상태/변경 중엔 비활성(currentStatus 경유)
                        statusMenuButton(.selling, "판매중으로")
                        statusMenuButton(.reserved, "예약중으로")
                        statusMenuButton(.sold, "판매완료로")
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
            // 구매자 화면 — 내 식별자를 스레드 buyer로 해석(buyer: nil).
            MarketChatSheet(item: displayItem, buyer: nil)
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showThreads) {
            // 판매자 화면 — 내 매물에 들어온 구매자별 1:1 문의 목록.
            MarketThreadListSheet(item: displayItem)
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showBuySheet) {
            MarketBuySheet(item: displayItem, onChat: { showChatSheet = true })
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .alert("삭제하지 못했어요", isPresented: $showDeleteFailAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("네트워크 문제로 매물을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        .alert("상태를 변경하지 못했어요", isPresented: $showStatusFailAlert) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("네트워크 문제로 판매 상태를 변경하지 못했어요. 잠시 후 다시 시도해 주세요.")
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
    ), buyer: nil)
}

#Preview("판매 플로우") {
    MkSellFlowSheet()
        .presentationDetents([.large])
}
#endif
