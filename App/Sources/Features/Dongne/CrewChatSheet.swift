// CrewChatSheet.swift
// BabyLog · Features/Dongne
// 크루 모임 그룹 채팅 시트 — CrewMeetupDetail.swift에서 사용 (참가자 전용)
// Swift 5 / iOS 17 / SwiftUI + Foundation only
//
// MarketChatSheet 의 말풍선 스타일을 미러링한다.
// (mine = primary 우측 / other = surface 좌측)

import SwiftUI
import Foundation

// MARK: - CrewChatSheet

struct CrewChatSheet: View {
    let meetup: CrewMeetup

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var messageText = ""
    /// 서버 전송 실패 시 입력 바 위에 안내를 띄운다(다시 편집하면 자동 해제).
    @State private var sendFailed = false
    /// 전송 실패로 입력란에 되돌려둔 텍스트. 이 값과 달라질 때(=사용자가 실제로 고칠 때)만 배너를 해제한다.
    @State private var lastFailedText: String? = nil
    /// 서버 공유 메시지(미구성/미로드 시 nil → 로컬 폴백)
    @State private var serverMessages: [ChatMessage]? = nil
    @State private var reportTarget: ChatMessage? = nil
    @State private var reportDone = false

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var messages: [ChatMessage] { serverMessages ?? store.crewChat(meetupId: meetup.id) }

    /// 채팅 열려 있는 동안 3초 주기 폴링(시트 닫히면 task 취소, 백그라운드면 건너뜀).
    private func pollLoop() async {
        guard SupabaseConfig.isConfigured else { return }
        while !Task.isCancelled {
            if scenePhase == .active,
               let msgs = await CrewBackend.fetchMessages(meetupId: meetup.id) { serverMessages = msgs }
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
                let ok = await CrewBackend.sendMessage(meetupId: meetup.id, body: text, authorName: nickname)
                if ok {
                    if let msgs = await CrewBackend.fetchMessages(meetupId: meetup.id) { serverMessages = msgs }
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
            store.sendCrewChat(meetupId: meetup.id, text: text, mine: true)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 핸들 + 헤더
            chatHeader

            // 모임 정보 미리보기 카드
            meetupPreviewCard
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s3)

            // 채팅 말풍선
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            Text("첫 메시지를 보내 모임을 시작해보세요.")
                                .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s4)
                        }
                        ForEach(messages) { msg in
                            CrewChatBubble(text: msg.text, isMe: msg.mine, author: msg.author,
                                           onReport: { reportTarget = msg })
                        }

                        // 안전 안내 뱃지
                        HStack {
                            Spacer()
                            BLBadge(
                                tone: .blue,
                                text: "공개 장소에서 안전하게 만나요",
                                systemIcon: "shield.checkered",
                                dot: false
                            )
                            Spacer()
                        }
                        .padding(.top, 4)
                        .accessibilityLabel("공개 장소에서 안전하게 만나요")

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
                .onAppear {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            // 입력 바
            inputBar
        }
        .background(AppColors.canvas)
        .accessibilityElement(children: .contain)
        .task(id: meetup.id) { await pollLoop() }
        .confirmationDialog("이 사용자를 신고할까요?", isPresented: Binding(
            get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }
        ), titleVisibility: .visible, presenting: reportTarget) { msg in
            ForEach(ReportBackend.reasons, id: \.self) { reason in
                Button(reason, role: .destructive) {
                    let snap = messages.suffix(20).map { ["author": $0.author ?? ($0.mine ? "나" : "상대"), "text": $0.text] }
                    Task { _ = await ReportBackend.submit(surface: "crew_meetup", contextId: meetup.id,
                        reportedName: msg.author, reportedId: msg.authorId, reason: reason, transcript: snap) }
                    reportDone = true
                }
            }
            Button("취소", role: .cancel) {}
        } message: { msg in Text("‘\(msg.author ?? "사용자")’ 님을 신고합니다. 대화 내용이 운영자에게 증거로 전달돼요.") }
        .alert("신고 접수됐어요", isPresented: $reportDone) {
            Button("확인", role: .cancel) {}
        } message: { Text("운영자가 확인 후 조치합니다. 감사합니다.") }
    }

    // MARK: 헤더
    private var chatHeader: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppColors.primaryTint)
                        .frame(width: 40, height: 40)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(meetup.place) 모임")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(meetup.when)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(meetup.place) 모임 채팅, \(meetup.when)")
    }

    // MARK: 모임 미리보기 카드
    private var meetupPreviewCard: some View {
        BLCard(padding: 10, flat: true) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(meetup.meetupType.iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: meetup.meetupType.systemIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(meetup.meetupType.iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(meetup.place)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text("주최: \(meetup.hostName)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer(minLength: 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityLabel("모임: \(meetup.place), 주최 \(meetup.hostName)")
    }

    // MARK: 입력 바
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
                    .frame(maxWidth: .infinity, minHeight: 44)
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
                .frame(width: 44, height: 44)
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

// MARK: - CrewChatBubble

private struct CrewChatBubble: View {
    let text: String
    let isMe: Bool
    var author: String? = nil
    var onReport: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top) {
            if isMe { Spacer(minLength: 48) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 2) {
                if !isMe, let author, !author.isEmpty {
                    Button { onReport?() } label: {
                        HStack(spacing: 3) {
                            Text(author).font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                            Image(systemName: "ellipsis").font(.system(size: 9, weight: .bold)).foregroundStyle(AppColors.ink3)
                        }
                    }.buttonStyle(.plain).padding(.leading, 2)
                }
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
            }   // VStack

            if !isMe { Spacer(minLength: 48) }
        }
        .accessibilityLabel(isMe ? "나: \(text)" : "\(text)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("크루 모임 채팅") {
    CrewChatSheet(meetup: CrewMeetup(id: "pm1",
        place: "망원한강공원 잔디밭",
        when: "오늘 오후 3시",
        hostName: "보리맘",
        hostTier: .golden,
        joined: 5,
        capacity: 8,
        meetupType: .park
    ))
}
#endif
