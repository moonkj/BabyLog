// MarketItemDetailSections.swift
// BabyLog · Features/Dongne
// 마켓 매물 상세 화면 섹션 서브뷰 — MarketItemDetail.swift에서 분리
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MarketDetailHeroPhoto

/// 히어로 사진
struct MarketDetailHeroPhoto: View {
    let item: MarketItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 사진 + 장식 뱃지 — VoiceOver에서 숨김(장식)
            ZStack(alignment: .topLeading) {
                MarketPhotoView(urls: item.photoURLs, refs: item.photoRefs, seed: item.photoSeed, index: 0, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()

                // 상태 뱃지 (예약/판매완료)
                if item.status != .selling {
                    BLBadge(tone: item.statusTone, text: item.statusDisplay, systemIcon: nil, dot: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 52).padding(.trailing, Spacing.s5)
                }

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

            // 사진은 VoiceOver에서 숨기되, 사진 위에 그려진 상태(예약중·판매완료·리콜)는
            // 별도 접근성 요소로 노출(시각 정보 손실 방지).
            if let stateLabel = heroStateAccessibilityLabel {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel(stateLabel)
            }
        }
    }

    /// 사진 오버레이로 표시되는 거래 상태를 VoiceOver 레이블로 합성. 없으면 nil.
    private var heroStateAccessibilityLabel: String? {
        var parts: [String] = []
        if item.status != .selling { parts.append(item.status.rawValue) }   // 예약중 / 판매완료
        if item.hasRecall { parts.append("리콜 대상") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - MarketDetailContent

/// 콘텐츠 섹션
struct MarketDetailContent: View {
    let item: MarketItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 리콜 경고 박스
            if item.hasRecall {
                MarketDetailRecallWarning()
            }

            // 등급/월령 + 제목/가격
            MarketDetailInfoBlock(item: item)

            // 판매자 카드
            MarketDetailSellerCard(item: item)

            // 위생 셀프체크 — 판매자가 체크한 항목이 있을 때만
            if !item.hygieneChecks.isEmpty {
                MarketDetailHygieneChecklist(checks: item.hygieneChecks)
            }

            // 안심 거래존 안내
            MarketDetailSafeTradeGuide()

            // 면책 문구
            MarketDetailDisclaimerLine()
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, 18)
    }
}

// MARK: - MarketDetailRecallWarning

/// 리콜 경고 박스
struct MarketDetailRecallWarning: View {
    var body: some View {
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
}

// MARK: - MarketDetailInfoBlock

/// 아이템 정보 블록
struct MarketDetailInfoBlock: View {
    let item: MarketItem

    var body: some View {
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

            // 상품 설명 — 판매자가 쓴 것만 그대로 표시. 설명이 없으면 문구를 지어내지 않는다
            // (정직 원칙: 판매자가 안 쓴 사용기간·인사말을 앱이 만들어내면 안 됨).
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.system(size: 14.5, weight: .regular))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(4)
                    .padding(.top, 4)
            } else {
                Text("판매자가 남긴 설명이 없어요.")
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .padding(.top, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(itemAccessibilityLabel)
    }

    // MARK: 접근성 레이블
    private var itemAccessibilityLabel: String {
        let gradeDesc = "\(item.grade.rawValue)등급 \(item.grade.label)"
        let priceDesc = item.isFree ? "무료나눔" : "\(item.price.formatted())원"
        let recallDesc = item.hasRecall ? " 리콜 이력 있음." : ""
        return "\(item.title). \(gradeDesc). \(item.monthsTag).\(recallDesc) \(priceDesc)."
    }
}

// MARK: - MarketDetailSellerCard

/// 판매자 카드
struct MarketDetailSellerCard: View {
    let item: MarketItem

    var body: some View {
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
                        BLBadge(tone: item.sellerTier.badgeTone, text: item.sellerTier.rawValue, systemIcon: item.sellerTier.systemIcon, dot: false)
                    }

                    if item.mine {
                        BLBadge(tone: .mint, text: "내 매물", systemIcon: nil, dot: false)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.ink3)
                            Text(item.distanceText)
                                .font(AppFont.num(12))
                                .foregroundStyle(AppColors.ink3)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("판매자 \(item.sellerName), \(item.sellerTier.rawValue), \(item.mine ? "내 매물" : item.distanceText)")
        .accessibilityHint("판매자 프로필 보기")
    }
}

// MARK: - MarketDetailHygieneChecklist

/// 위생 셀프체크 리스트 — 판매자가 직접 체크한 항목만 표시
struct MarketDetailHygieneChecklist: View {
    let checks: [String]
    var body: some View {
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

                ForEach(checks, id: \.self) { item in
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
        .accessibilityLabel("위생 상태 셀프 체크. \(checks.joined(separator: ", ")) 확인됨.")
    }
}

// MARK: - MarketDetailSafeTradeGuide

/// 안심 거래존 안내
struct MarketDetailSafeTradeGuide: View {
    var body: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BadgeTone.blue.ink)
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
        .background(BadgeTone.blue.bg, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("안심 거래존 이용 권장. 주민센터·공공도서관 앞 등 공공장소에서 거래하면 더 안전해요.")
    }
}

// MARK: - MarketDetailDisclaimerLine

/// 면책 문구
struct MarketDetailDisclaimerLine: View {
    var body: some View {
        Text("이 정보는 판매자가 제공했으며, BabyLog는 거래에 직접 개입하지 않습니다.")
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(AppColors.ink3)
            .multilineTextAlignment(.leading)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .accessibilityHidden(true)
    }
}

// MARK: - MarketDetailBottomBar

/// 하단 고정 바
struct MarketDetailBottomBar: View {
    let item: MarketItem
    @Binding var isFavorited: Bool
    var isMine: Bool = false
    let onChat: () -> Void
    var onBuy: () -> Void = {}

    var body: some View {
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

            if isMine {
                // 내 매물 — 상태 표시
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 15, weight: .bold))
                    Text(item.status == .sold ? "판매완료된 내 매물" : "내가 등록한 매물")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(AppColors.ink2)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            } else if item.status == .sold {
                // 판매완료 — 비활성
                Text("판매완료된 상품")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            } else if item.status == .reserved {
                // 예약중 — 구매는 비활성(예약자 보호), 채팅은 가능(대기 문의)
                Button { onChat() } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 19, weight: .bold)).foregroundStyle(AppColors.ink2)
                        .frame(width: 50, height: 50)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.92))
                .accessibilityLabel("판매자와 채팅")

                Text("예약중")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityLabel("예약중인 상품")
            } else {
                // 채팅(보조) + 구매하기(주)
                Button { onChat() } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 19, weight: .bold)).foregroundStyle(AppColors.ink2)
                        .frame(width: 50, height: 50)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.92))
                .accessibilityLabel("판매자와 채팅")

                LiquidButton(action: onBuy) {
                    Text(item.isFree ? "나눔 받기" : "구매하기")
                        .font(.system(size: 16, weight: .bold)).frame(maxWidth: .infinity)
                }
                .accessibilityLabel(item.isFree ? "나눔 받기" : "구매하기")
            }
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
}
