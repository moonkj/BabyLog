// MarketThreadListSheet.swift
// BabyLog · Features/Dongne
// 판매자용 — 내 매물에 들어온 1:1 문의 스레드 목록.
// 개인정보: 채팅은 매물·구매자별 1:1 스레드다. 판매자는 자기 매물의 모든 스레드를 보지만,
// 각 스레드는 그 구매자와 판매자만 열람한다(공개방 아님). 탭하면 해당 구매자와의 대화로 들어간다.
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketThreadListSheet

struct MarketThreadListSheet: View {
    let item: MarketItem

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// 구매자별 스레드(미로드 시 nil → 로딩 스피너).
    @State private var threads: [MarketBackend.ChatThread]? = nil
    /// 탭한 스레드(=특정 구매자와의 1:1 대화 진입).
    @State private var openThread: MarketBackend.ChatThread? = nil

    /// 스레드 로드(폴링 없이 진입·복귀 시 1회씩 — 판매자 화면은 가벼운 점검이면 충분).
    private func load() async {
        if let t = await MarketBackend.fetchThreads(itemId: item.id) { threads = t }
        else { threads = [] }   // 미구성/실패 → 빈 상태로(데모/오프라인)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("문의 목록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
            }
            .task(id: item.id) { await load() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await load() } }
            }
            .sheet(item: $openThread) { thread in
                MarketChatSheet(item: item, buyer: thread.buyer, buyerName: thread.buyerName)
                    .environmentObject(store)
                    .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let threads {
            if threads.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        headerNote
                        ForEach(threads) { thread in
                            Button {
                                Haptics.light()
                                openThread = thread
                            } label: {
                                threadRow(thread)
                            }
                            .buttonStyle(LiquidPressStyle(scale: 0.99))
                            .accessibilityLabel("\(thread.buyerName) 문의, \(thread.lastText)")
                            .accessibilityHint("탭하면 이 구매자와의 1:1 대화를 엽니다")
                        }
                    }
                    .padding(Spacing.s4)
                }
            }
        } else {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.primary)
                .accessibilityLabel("문의를 불러오는 중")
        }
    }

    /// 1:1 안내 — 채팅이 구매자별로 분리됨을 명확히.
    private var headerNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("구매자별 1:1 대화예요.")
                .font(AppFont.caption).foregroundStyle(AppColors.ink3)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("구매자별 1:1 대화예요.")
    }

    private func threadRow(_ thread: MarketBackend.ChatThread) -> some View {
        BLCard(padding: 14, flat: true) {
            HStack(spacing: 12) {
                // 구매자 아바타(이니셜 대신 중립 아이콘 — 성별 중립)
                ZStack {
                    Circle().fill(AppColors.surface2).frame(width: 44, height: 44)
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(thread.buyerName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(relativeTime(thread.lastDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                    Text(thread.lastText)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.ink3)
                    .accessibilityHidden(true)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("아직 들어온 문의가 없어요.")
                .font(AppFont.body).foregroundStyle(AppColors.ink2)
            Text("구매자가 문의를 보내면 여기에 1:1 대화로 모여요.")
                .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.s6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("아직 들어온 문의가 없어요. 구매자가 문의를 보내면 여기에 1:1 대화로 모여요.")
    }

    /// 상대 시간 표기 — CrewBackend.relativeTime과 동일한 한국어 톤.
    private func relativeTime(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "방금" }
        if s < 3600 { return "\(s / 60)분 전" }
        if s < 86400 { return "\(s / 3600)시간 전" }
        return "\(s / 86400)일 전"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("문의 목록") {
    MarketThreadListSheet(item: MarketItem(
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
        photoSeed: 5,
        mine: true
    ))
    .environmentObject(AppStore())
}
#endif
