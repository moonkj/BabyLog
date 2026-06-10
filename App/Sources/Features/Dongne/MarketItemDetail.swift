// MarketItemDetail.swift
// BabyLog · Features/Dongne
// 마켓 매물 상세 화면 (NavigationStack push)
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketItemDetail

struct MarketItemDetail: View {
    let item: MarketItem

    @State private var showChatSheet = false
    @State private var isFavorited = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroPhoto
                    contentSection
                        .padding(.bottom, 96) // 하단 바 여백
                }
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)

            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $showChatSheet) {
            MarketChatSheet(item: item)
                .presentationDetents([.large])
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 히어로 사진
    private var heroPhoto: some View {
        ZStack(alignment: .topLeading) {
            PhotoPlaceholder(seed: item.photoSeed, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 280)

            // 리콜 뱃지
            if item.hasRecall {
                BLBadge(tone: .coral, text: "리콜", systemIcon: "exclamationmark.triangle.fill", dot: false)
                    .padding(.top, 52)
                    .padding(.leading, Spacing.s5)
            }

            // 졸업템 뱃지
            if item.isGraduate {
                BLBadge(tone: .mint, text: "동네 졸업템", systemIcon: nil, dot: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.bottom, Spacing.s3)
                    .padding(.leading, Spacing.s5)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 콘텐츠 섹션
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 리콜 경고 박스
            if item.hasRecall {
                recallWarningBox
            }

            // 등급/월령 + 제목/가격
            itemInfoBlock

            // 판매자 카드
            sellerCard

            // 위생 셀프체크
            hygieneChecklist

            // 안심 거래존 안내
            safeTradeGuide

            // 면책 문구
            disclaimerLine
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, 18)
    }

    // MARK: 리콜 경고 박스
    private var recallWarningBox: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.danger)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("리콜 이력이 있는 모델이에요")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: 0x9A3A29))

                    Text("KATSA·KERI 리콜 DB 기준. 구매 전 제조사 무상 점검 여부를 꼭 확인하세요.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color(hex: 0xA8513F))
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.dangerTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(Color(hex: 0xF0C6BB), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("주의. 리콜 이력이 있는 모델이에요. KATSA·KERI 리콜 DB 기준. 구매 전 제조사 무상 점검 여부를 꼭 확인하세요.")
    }

    // MARK: 아이템 정보 블록
    private var itemInfoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 등급 + 월령 태그
            HStack(spacing: 6) {
                BLBadge(
                    tone: item.grade.badgeTone,
                    text: "\(item.grade.rawValue)등급 · \(item.grade.label)",
                    systemIcon: item.grade.systemIcon,
                    dot: false
                )
                BLBadge(tone: .grey, text: item.monthsTag, systemIcon: nil, dot: false)
            }

            // 제목
            Text(item.title)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(AppColors.ink)
                .lineSpacing(3)

            // 가격
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(item.isFree ? "무료나눔" : "\(item.price.formatted())원")
                    .font(AppFont.num(26, weight: .heavy))
                    .foregroundStyle(item.isFree ? AppColors.primary : AppColors.ink)

                if !item.isFree, let orig = item.originalPrice {
                    Text("정가 \(orig.formatted())원")
                        .font(AppFont.num(14))
                        .foregroundStyle(AppColors.ink3)
                }
            }

            // 상품 설명
            Text("\(item.monthsTag) 동안 사용했어요. 큰 하자 없이 깨끗하게 썼고, 위생 상태 체크리스트 항목을 모두 확인했어요. 같은 동네라 직거래 환영합니다 :)")
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(4)
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemAccessibilityLabel)
    }

    // MARK: 판매자 카드
    private var sellerCard: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .center, spacing: 12) {
                // 아바타
                ZStack {
                    Circle()
                        .fill(AppColors.primaryTint)
                        .frame(width: 42, height: 42)
                    Text(String(item.sellerName.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.sellerName)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        BLBadge(tone: item.sellerTier.badgeTone, text: item.sellerTier.rawValue, systemIcon: nil, dot: false)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                        Text("\(item.distanceText) · 거래 47회 · 응답률 94%")
                            .font(AppFont.num(12))
                            .foregroundStyle(AppColors.ink3)
                    }

                    // 평점 표시
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < 4 ? "star.fill" : "star.leadinghalf.filled")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(AppColors.gold)
                        }
                        Text("4.8")
                            .font(AppFont.num(11, weight: .semibold))
                            .foregroundStyle(AppColors.ink2)
                    }
                    .padding(.top, 1)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("판매자 \(item.sellerName), \(item.sellerTier.rawValue), \(item.distanceText), 거래 47회, 응답률 94%, 평점 4.8")
        .accessibilityHint("판매자 프로필 보기")
    }

    // MARK: 위생 셀프체크 리스트
    private var hygieneChecklist: some View {
        BLCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                    Text("위생 상태 셀프 체크")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                }

                ForEach(["세척·소독 완료", "부품 누락 없음", "곰팡이·얼룩 없음"], id: \.self) { item in
                    HStack(spacing: 9) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(AppColors.primaryTint)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.primary)
                        }
                        .accessibilityHidden(true)

                        Text(item)
                            .font(.system(size: 13.5, weight: .regular))
                            .foregroundStyle(AppColors.ink2)
                    }
                    .accessibilityLabel("\(item) 확인됨")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("위생 상태 셀프 체크. 세척·소독 완료, 부품 누락 없음, 곰팡이·얼룩 없음 모두 확인됨.")
    }

    // MARK: 안심 거래존 안내
    private var safeTradeGuide: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3B6FA8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("안심 거래존 이용 권장")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)

                    Text("주민센터·공공도서관 앞 등 공공장소에서 거래하면 더 안전해요. 채팅에서 안심 거래존을 확인할 수 있어요.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(AppColors.ink2)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(hex: 0xE6F1FB), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("안심 거래존 이용 권장. 주민센터·공공도서관 앞 등 공공장소에서 거래하면 더 안전해요.")
    }

    // MARK: 면책 문구
    private var disclaimerLine: some View {
        Text("이 정보는 판매자가 제공했으며, BabyLog는 거래에 직접 개입하지 않습니다.")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppColors.ink3)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }

    // MARK: 하단 고정 바
    private var bottomBar: some View {
        HStack(spacing: 12) {
            // 관심 버튼
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isFavorited.toggle()
                }
            } label: {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isFavorited ? AppColors.danger : AppColors.ink2)
                    .frame(width: 50, height: 50)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.line, lineWidth: 1)
                    }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.92))
            .accessibilityLabel(isFavorited ? "관심 해제" : "관심 등록")
            .accessibilityHint("관심 목록에 추가하거나 제거합니다")

            // 채팅하기 버튼
            LiquidButton(action: { showChatSheet = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 17, weight: .bold))
                        .accessibilityHidden(true)
                    Text("채팅하기")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .accessibilityLabel("채팅하기")
            .accessibilityHint("\(item.sellerName)에게 채팅 메시지를 보냅니다")
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, 12)
        .padding(.bottom, 26)
        .background(AppColors.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.line)
                .frame(height: 1)
        }
    }

    // MARK: 접근성 레이블
    private var itemAccessibilityLabel: String {
        let gradeDesc = "\(item.grade.rawValue)등급 \(item.grade.label)"
        let priceDesc = item.isFree ? "무료나눔" : "\(item.price.formatted())원"
        let recallDesc = item.hasRecall ? " 리콜 이력 있음." : ""
        return "\(item.title). \(gradeDesc). \(item.monthsTag).\(recallDesc) \(priceDesc)."
    }
}

// MARK: - MarketChatSheet

struct MarketChatSheet: View {
    let item: MarketItem

    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""

    private let mockMessages: [(text: String, isMe: Bool)] = [
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
                    ForEach(mockMessages.indices, id: \.self) { i in
                        MkChatBubble(text: mockMessages[i].text, isMe: mockMessages[i].isMe)
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
                // 목업: 입력 초기화
                messageText = ""
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

// MARK: - MkSellFlowSheet (판매 플로우 3단계)

struct MkSellFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var selectedGrade: MarketItemGrade = .a
    @State private var priceText: String = "95,000"
    @State private var showComplete = false

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .accessibilityHidden(true)

            // 단계 인디케이터
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AppColors.ink : AppColors.line2)
                        .frame(width: i == step ? 24 : 8, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
                }
            }
            .accessibilityLabel("단계 \(step + 1) / 3")
            .padding(.bottom, 20)

            if showComplete {
                sellCompleteView
            } else {
                switch step {
                case 0: sellStep0
                case 1: sellStep1
                default: sellStep2
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s5)
        .background(AppColors.canvas)
        .frame(maxHeight: .infinity)
    }

    // MARK: Step 0 — 사진 + AI 분류
    private var sellStep0: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("무엇을 정리할까요?")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            Text("사진을 올리면 AI가 자동 분류해드려요.")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(AppColors.ink2)

            // 사진 영역
            ZStack {
                PhotoPlaceholder(seed: 0, cornerRadius: 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("사진 추가 (최소 2장)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .accessibilityLabel("사진 추가 영역. 최소 2장")

            // AI 자동 인식 카드
            BLCard(padding: 13, flat: true) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 자동 인식")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text("식사 의자 · 6개월+ 로 분류했어요")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink2)
                    }

                    Spacer(minLength: 0)

                    BLBadge(tone: .mint, text: "온디바이스", systemIcon: nil, dot: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.line, lineWidth: 1)
            }
            .accessibilityLabel("AI 자동 인식. 식사 의자 6개월+로 분류했어요. 온디바이스 처리.")

            LiquidButton(action: { withAnimation { step = 1 } }) {
                Text("다음")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("다음 단계로")
        }
    }

    // MARK: Step 1 — 등급 + 가격
    private var sellStep1: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("상태와 가격")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            // 등급 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("상태 등급")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AppColors.ink3)

                HStack(spacing: 8) {
                    ForEach(MarketItemGrade.allCases, id: \.self) { grade in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedGrade = grade
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(grade.rawValue)
                                    .font(.system(size: 17, weight: .heavy))
                                Text(grade.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(selectedGrade == grade ? Color.white : AppColors.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                selectedGrade == grade ? AppColors.ink : AppColors.surface,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(
                                        selectedGrade == grade ? AppColors.ink : AppColors.line,
                                        lineWidth: selectedGrade == grade ? 1.5 : 1
                                    )
                            }
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.95))
                        .accessibilityLabel("\(grade.rawValue)등급 \(grade.label)")
                        .accessibilityAddTraits(selectedGrade == grade ? [.isSelected] : [])
                    }
                }
            }

            // 가격 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("가격 · AI 시세 제안")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AppColors.ink3)

                HStack(alignment: .center, spacing: 10) {
                    Text(priceText)
                        .font(AppFont.num(22, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    Text("원")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.ink2)

                    Spacer(minLength: 0)

                    BLBadge(tone: .mint, text: "비슷한 매물 평균", systemIcon: nil, dot: true)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                }
                .accessibilityLabel("제안 가격 \(priceText)원. 비슷한 매물 평균 기준.")
            }

            LiquidButton(action: { withAnimation { step = 2 } }) {
                Text("다음")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("다음 단계로")
        }
    }

    // MARK: Step 2 — 등록 완료 보상
    private var sellStep2: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("마지막으로 확인해요")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            // 요약 카드
            BLCard(padding: 14, flat: true) {
                VStack(alignment: .leading, spacing: 8) {
                    SellSummaryRow(icon: "photo.on.rectangle", label: "사진", value: "2장 첨부됨")
                    SellSummaryRow(icon: selectedGrade.systemIcon, label: "등급", value: "\(selectedGrade.rawValue)등급 · \(selectedGrade.label)")
                    SellSummaryRow(icon: "wonsign.circle.fill", label: "가격", value: "\(priceText)원")
                    SellSummaryRow(icon: "sparkles", label: "AI 분류", value: "식사 의자 · 6개월+")
                }
            }
            .accessibilityElement(children: .contain)

            LiquidButton(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showComplete = true
                }
            }) {
                Text("등록하기")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("매물 등록하기")
        }
    }

    // MARK: 등록 완료 보상
    private var sellCompleteView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(AppColors.goldTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("매물이 등록됐어요!")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppColors.ink)

                Text("동네 이웃에게 알림이 가요.\n빠른 거래를 응원해요 :)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // 보상 뱃지
            BLCard(padding: 13, flat: true) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("첫 매물 등록 뱃지 획득!")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                        Text("따뜻한 이웃이 되어주셔서 감사해요.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: 0xA8813A))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .accessibilityLabel("첫 매물 등록 뱃지 획득! 따뜻한 이웃이 되어주셔서 감사해요.")

            LiquidButton(action: { dismiss() }) {
                Text("확인")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("닫기")

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SellSummaryRow (헬퍼)

private struct SellSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(AppColors.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("마켓 상세 — 일반") {
    NavigationStack {
        MarketItemDetail(item: MarketItem(
            id: 1,
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
            id: 3,
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
        id: 1,
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
