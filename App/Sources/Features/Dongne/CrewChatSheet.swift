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
    @State private var messageText = ""
    @State private var memberTyping = false

    private var messages: [ChatMessage] { store.crewChat(meetupId: meetup.id) }

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
                            CrewChatBubble(text: msg.text, isMe: msg.mine)
                        }

                        // 다른 참가자 입력 중 (데모)
                        if memberTyping {
                            HStack {
                                TypingDotsView(tint: AppColors.ink3)
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Spacer()
                            }
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
                .onChange(of: memberTyping) { _ in
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
        .accessibilityLabel("모임: \(meetup.place), 주최 \(meetup.hostName)")
    }

    // MARK: 입력 바
    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("메시지 보내기", text: $messageText)
                .font(.system(size: 14, weight: .regular))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColors.surface2, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                .accessibilityLabel("메시지 입력")

            Button {
                let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                store.sendCrewChat(meetupId: meetup.id, text: text, mine: true)
                messageText = ""
                Haptics.light()
                // 데모: 다른 참가자 입력 중 → 자동 응답 (백엔드 연동 전)
                withAnimation { memberTyping = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation { memberTyping = false }
                    store.sendCrewChat(meetupId: meetup.id,
                                       text: "네, 곧 봬요! 😊", mine: false)
                }
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

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 48) }

            Text(text)
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(isMe ? Color.white : AppColors.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isMe ? AppColors.primary : AppColors.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(radius: isMe ? 0 : 1, y: isMe ? 0 : 1)

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
