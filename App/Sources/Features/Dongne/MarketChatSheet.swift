// MarketChatSheet.swift
// BabyLog · Features/Dongne
// 마켓 매물 채팅 시트 — MarketItemDetail.swift에서 분리
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketChatSheet

struct MarketChatSheet: View {
    let item: MarketItem

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var messageText = ""
    @State private var sellerTyping = false
    @State private var showReport = false
    /// 서버 전송 실패 시 입력 바 위에 안내를 띄운다(다시 편집하면 자동 해제).
    @State private var sendFailed = false
    /// 전송 실패로 입력란에 되돌려둔 텍스트. 이 값과 달라질 때(=사용자가 실제로 고칠 때)만 배너를 해제한다.
    @State private var lastFailedText: String? = nil
    /// 서버 공유 메시지(미구성/미로드 시 nil → 로컬 폴백)
    @State private var serverMessages: [ChatMessage]? = nil

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var messages: [ChatMessage] { serverMessages ?? store.marketMessages(itemId: item.id) }
    private var transcriptText: String {
        ChatTranscript.text(itemTitle: item.title, counterpart: item.sellerName, messages: messages)
    }

    /// 채팅 열려 있는 동안 3초 주기 폴링(시트 닫히면 task 취소, 백그라운드면 건너뜀).
    private func pollLoop() async {
        guard SupabaseConfig.isConfigured else { return }
        while !Task.isCancelled {
            if scenePhase == .active,
               let msgs = await MarketBackend.fetchMessages(itemId: item.id) { serverMessages = msgs }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    private func send() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        Haptics.light()
        if SupabaseConfig.isConfigured {
            Task {
                let ok = await MarketBackend.sendMessage(itemId: item.id, body: text, authorName: nickname)
                if ok {
                    if let msgs = await MarketBackend.fetchMessages(itemId: item.id) { serverMessages = msgs }
                } else {
                    // 전송 실패 — 입력한 내용을 되돌려 다시 시도할 수 있게 한다.
                    // messageText 복원이 .onChange를 트리거하므로, 복원값을 lastFailedText로 기억해
                    // 같은 트랜잭션에서 배너가 즉시 사라지는 것을 막는다(사용자가 고칠 때만 해제).
                    messageText = text
                    lastFailedText = text
                    sendFailed = true
                    Haptics.warning()
                }
            }
        } else {
            store.sendMarketMessage(itemId: item.id, text: text, mine: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 핸들 + 헤더
            chatHeader

            // 매물 미리보기 카드
            itemPreviewCard
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s3)

            // 채팅 말풍선
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            VStack(spacing: Spacing.s2) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 26, weight: .regular))
                                    .foregroundStyle(AppColors.ink3)
                                    .accessibilityHidden(true)
                                Text("첫 메시지를 보내 거래를 시작해보세요.")
                                    .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, Spacing.s6)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("첫 메시지를 보내 거래를 시작해보세요.")
                        }
                        ForEach(messages) { msg in
                            MkChatBubble(text: msg.text, isMe: msg.mine)
                        }

                        // 판매자 입력 중 (§8.5 대화 말풍선 점)
                        if sellerTyping {
                            HStack {
                                TypingDotsView(tint: AppColors.ink3)
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Spacer()
                            }
                        }

                        // 안심 거래존 뱃지
                        HStack {
                            Spacer()
                            BLBadge(
                                tone: .blue,
                                text: "주민센터 앞 안심 거래존 추천",
                                systemIcon: "shield.checkered",
                                dot: false
                            )
                            Spacer()
                        }
                        .padding(.top, 4)
                        .accessibilityLabel("주민센터 앞 안심 거래존 추천")

                        // 최신 메시지로 자동 스크롤하기 위한 하단 앵커
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
                .onChange(of: sellerTyping) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            // 입력 바
            inputBar
        }
        .background(AppColors.canvas)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showReport) {
            TradeReportSheet(item: item, transcript: messages).environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .task(id: item.id) { await pollLoop() }
    }

    private var chatHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.sellerName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(item.sellerTier.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Menu {
                    ShareLink(item: transcriptText) {
                        Label("대화 내보내기", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { showReport = true } label: {
                        Label("거래 신고하기", systemImage: "exclamationmark.bubble.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.ink2)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("대화 메뉴 — 내보내기·신고")

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                }
                .accessibilityLabel("닫기")
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s3)
        }
    }

    private var itemPreviewCard: some View {
        BLCard(padding: 10, flat: true) {
            HStack(spacing: 10) {
                MarketPhotoView(urls: item.photoURLs, refs: item.photoRefs,
                                seed: item.photoSeed, index: 0, cornerRadius: 10)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(item.isFree ? "무료나눔" : "\(item.price.formatted())원")
                        .font(AppFont.num(14, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                }
                Spacer(minLength: 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityLabel("매물: \(item.title), \(item.isFree ? "무료나눔" : "\(item.price.formatted())원")")
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            if sendFailed {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .accessibilityHidden(true)
                    Text("전송 실패 — 다시 시도해 주세요")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.danger)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, 8)
                .accessibilityLabel("전송 실패, 다시 시도해 주세요")
            }

            HStack(spacing: 10) {
                TextField("메시지 보내기", text: $messageText)
                    .font(.system(size: 14, weight: .regular))
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(AppColors.surface2, in: Capsule())
                    .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                    .accessibilityLabel("메시지 입력")
                    .onChange(of: messageText) { newValue in
                        // 복원된 실패 텍스트와 달라질 때(=사용자가 실제로 편집)만 배너 해제.
                        if sendFailed, newValue != lastFailedText {
                            sendFailed = false
                            lastFailedText = nil
                        }
                    }

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(messageText.isEmpty ? AppColors.ink3 : AppColors.primary)
                }
                .disabled(messageText.isEmpty)
                .frame(width: 52, height: 52)
                .accessibilityLabel("전송")
            }
            .padding(.horizontal, Spacing.s4)
        }
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(AppColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.line).frame(height: 1)
        }
    }
}

// MARK: - MkChatBubble

private struct MkChatBubble: View {
    let text: String
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 48) }

            Text(text)
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(isMe ? Color.white : AppColors.ink)
                .lineSpacing(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isMe ? AppColors.primary : AppColors.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    if !isMe {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColors.line, lineWidth: 1)
                    }
                }

            if !isMe { Spacer(minLength: 48) }
        }
        .accessibilityLabel(isMe ? "나: \(text)" : "\(text)")
    }
}

// MARK: - 거래 신고 시트

private struct TradeReportSheet: View {
    let item: MarketItem
    var transcript: [ChatMessage] = []   // 신고 시점 화면 대화(증거)
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let reasons = ["사기·미수령", "욕설·협박", "안전 위협", "가품·허위 정보", "기타"]
    @State private var reason = "사기·미수령"
    @State private var note = ""
    @State private var submitted = false
    @State private var reportText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    if submitted { submittedView } else { formView }
                }
                .padding(Spacing.s5)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("거래 신고")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("어떤 문제가 있었나요?")
                .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)

            VStack(spacing: 8) {
                ForEach(reasons, id: \.self) { r in
                    Button { Haptics.selection(); reason = r } label: {
                        HStack {
                            Text(r).font(AppFont.body).foregroundStyle(AppColors.ink)
                            Spacer()
                            Image(systemName: reason == r ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(reason == r ? AppColors.danger : AppColors.ink3)
                        }
                        .padding(.horizontal, 14).frame(minHeight: 48)
                        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(reason == r ? AppColors.danger.opacity(0.4) : AppColors.line, lineWidth: 1)
                        }
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.99))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("상세 내용 (선택)").font(AppFont.caption).foregroundStyle(AppColors.ink3)
                TextField("무슨 일이 있었는지 적어주세요", text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
            }

            Text(SupabaseConfig.isConfigured
                 ? "신고 내용과 대화는 안전하게 보관돼요(운영자만 열람). 안전·분쟁 대응을 위해 보관되며, 적법한 절차(수사기관 요청 등)에 따라 제출될 수 있어요."
                 : "신고하면 신고 시점의 대화가 증거로 보존돼요. 안전·분쟁 대응을 위해 보관되며, 적법한 절차(수사기관 요청 등)에 따라 제출될 수 있어요. 지금은 기기에 안전하게 보관되고, 서버 연동 시 보관처가 확대됩니다.")
                .font(AppFont.caption).foregroundStyle(AppColors.ink3).lineSpacing(2)

            LiquidButton(fill: AppColors.danger, cornerRadius: Radius.md) {
                let r = store.reportTrade(item: item, reason: reason, note: note, transcript: transcript)
                reportText = ChatTranscript.text(itemTitle: item.title, counterpart: item.sellerName,
                                                 messages: r.transcript, reason: r.reason, note: r.note)
                // 증거 서버 보존(운영자 열람). 미구성/실패 시 로컬 보관 유지(uploaded=false).
                if SupabaseConfig.isConfigured {
                    Task { if await MarketBackend.uploadReport(r) { store.markReportUploaded(r.id) } }
                }
                Haptics.success()
                withAnimation { submitted = true }
            } label: {
                Label("신고 접수", systemImage: "checkmark.shield.fill").foregroundStyle(.white)
            }
        }
    }

    private var submittedView: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(BadgeTone.mint.ink)
                Text("신고가 접수됐어요")
                    .font(.system(size: 17, weight: .heavy)).foregroundStyle(AppColors.ink)
            }
            Text("신고 시점의 대화가 증거로 보존됐어요. 아래에서 대화·신고 내용을 내보내 경찰이나 지원기관에 제출할 수 있어요.")
                .font(AppFont.body).foregroundStyle(AppColors.ink2).lineSpacing(2)

            ShareLink(item: reportText) {
                Label("대화·신고 내용 내보내기", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(AppColors.ink, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }

            Button { dismiss() } label: {
                Text("닫기").font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.ink2)
                    .frame(maxWidth: .infinity).frame(height: 48)
            }
            .buttonStyle(LiquidPressStyle(scale: 0.98))
        }
    }
}
