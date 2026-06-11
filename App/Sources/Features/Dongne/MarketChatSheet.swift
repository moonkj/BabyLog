// MarketChatSheet.swift
// BabyLog · Features/Dongne
// 마켓 매물 채팅 시트 — MarketItemDetail.swift에서 분리
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketChatSheet

struct MarketChatSheet: View {
    let item: MarketItem

    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var sellerTyping = false

    @State private var messages: [(text: String, isMe: Bool)] = [
        ("안녕하세요! 혹시 직거래 가능할까요?", true),
        ("네, 가능해요 :) 같은 동네시면 더 편하실 거예요", false),
        ("오늘 저녁 7시에 정문 앞 어떠세요?", false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 핸들 + 헤더
            chatHeader

            // 매물 미리보기 카드
            itemPreviewCard
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s3)

            // 채팅 말풍선
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messages.indices, id: \.self) { i in
                        MkChatBubble(text: messages[i].text, isMe: messages[i].isMe)
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
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            // 입력 바
            inputBar
        }
        .background(AppColors.canvas)
        .accessibilityElement(children: .contain)
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
                PhotoPlaceholder(seed: item.photoSeed, cornerRadius: 10)
                    .frame(width: 44, height: 44)
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
        .accessibilityLabel("매물: \(item.title), \(item.isFree ? "무료나눔" : "\(item.price.formatted())원")")
    }

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
                withAnimation(.easeOut(duration: 0.2)) {
                    messages.append((text: text, isMe: true))
                }
                messageText = ""
                Haptics.light()
                // 데모: 판매자 입력 중 → 응답 (샘플 화면)
                withAnimation { sellerTyping = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation {
                        sellerTyping = false
                        messages.append((text: "네, 확인했어요! 😊 편하신 시간 알려주세요.", isMe: false))
                    }
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
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isMe ? AppColors.primary : AppColors.surface,
                    in: isMe
                        ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                        : RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(radius: isMe ? 0 : 1, y: isMe ? 0 : 1)

            if !isMe { Spacer(minLength: 48) }
        }
        .accessibilityLabel(isMe ? "나: \(text)" : "\(text)")
    }
}
