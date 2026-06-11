// MarketScreen.swift
// BabyLog · Features/Dongne
// DongneTab의 "마켓" 세그먼트에 임베드하여 사용합니다.
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - Market Models

/// 상태 등급 S/A/B/C
enum MarketItemGrade: String, CaseIterable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"

    var label: String {
        switch self {
        case .s: return "거의새것"
        case .a: return "깨끗"
        case .b: return "사용감있음"
        case .c: return "하자있음"
        }
    }

    var badgeTone: BadgeTone {
        switch self {
        case .s: return .blue
        case .a: return .mint
        case .b: return .amber
        case .c: return .coral
        }
    }

    var systemIcon: String {
        switch self {
        case .s: return "seal.fill"
        case .a: return "checkmark.circle.fill"
        case .b: return "minus.circle.fill"
        case .c: return "exclamationmark.circle.fill"
        }
    }
}

/// 판매자 티어
enum MarketSellerTier: String {
    case golden = "골든 맘"
    case warm   = "따뜻한 이웃"
    case new    = "신규"

    var badgeTone: BadgeTone {
        switch self {
        case .golden: return .amber
        case .warm:   return .mint
        case .new:    return .grey
        }
    }
}

/// 마켓 카테고리
enum MarketCategory: String, CaseIterable {
    case all    = "전체"
    case cloth  = "의류"
    case feed   = "수유용품"
    case ride   = "이동수단"
    case toy    = "완구"
    case meal   = "식사"
    case book   = "도서·교구"
    case bath   = "목욕·위생"
    case safety = "안전·외출"
    case furn   = "가구·침구"
    case etc    = "기타"

    var systemIcon: String {
        switch self {
        case .all:    return "square.grid.2x2.fill"
        case .cloth:  return "tshirt.fill"
        case .feed:   return "drop.fill"
        case .ride:   return "stroller.fill"
        case .toy:    return "teddybear.fill"
        case .meal:   return "fork.knife"
        case .book:   return "books.vertical.fill"
        case .bath:   return "shower.fill"
        case .safety: return "shield.fill"
        case .furn:   return "bed.double.fill"
        case .etc:    return "ellipsis.circle.fill"
        }
    }
}

enum MarketStatus: String, Codable, CaseIterable {
    case selling  = "판매중"
    case reserved = "예약중"
    case sold     = "판매완료"
}

struct MarketItem: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var title: String
    var category: MarketCategory
    var grade: MarketItemGrade
    var monthsTag: String        // 예: "6–12개월"
    var price: Int               // 0 = 무료나눔
    var originalPrice: Int?
    var isFree: Bool
    var hasRecall: Bool
    var isGraduate: Bool         // 졸업템
    var sellerName: String
    var sellerTier: MarketSellerTier
    var distanceText: String
    var favoriteCount: Int
    var photoSeed: Int
    // 실데이터(사용자 등록)
    var description: String = ""
    var photoRefs: [String] = []
    var mine: Bool = false
    var status: MarketStatus = .selling
    var createdAt: Date = Date()
    /// 판매자가 직접 체크한 위생 항목 (선택한 것만 상세에 표시)
    var hygieneChecks: [String] = []

    /// 위생 셀프체크 선택지
    static let hygieneOptions = ["세척·소독 완료", "부품 누락 없음", "곰팡이·얼룩 없음"]
}

// enum들 Codable 적합성 (rawValue String)
extension MarketItemGrade: Codable {}
extension MarketSellerTier: Codable {}
extension MarketCategory: Codable {}

/// "곧 필요해요" 월령 연동 추천 아이템
struct MarketNeedSoonItem: Identifiable {
    let id: Int
    let title: String
    let reason: String
    let photoSeed: Int
    let category: MarketCategory   // 탭 시 해당 카테고리로 필터
}

// MARK: - Mock Data

private let mkNeedSoonItems: [MarketNeedSoonItem] = [
    MarketNeedSoonItem(id: 1, title: "걸음마 보조기",   reason: "10개월쯤 필요해요",    photoSeed: 2, category: .ride),
    MarketNeedSoonItem(id: 2, title: "식사 의자",        reason: "이유식 시작 전 준비", photoSeed: 5, category: .meal),
    MarketNeedSoonItem(id: 3, title: "욕조 샴푸의자",    reason: "목 가눌 때 부터",     photoSeed: 3, category: .feed),
    MarketNeedSoonItem(id: 4, title: "보행기",           reason: "6개월+ 권장",         photoSeed: 0, category: .ride),
    MarketNeedSoonItem(id: 5, title: "유아 체온계",      reason: "지금 당장 필요해요",  photoSeed: 4, category: .feed),
]

extension MarketItem {
    /// 데모 시드(첫 실행 시 AppStore에 1회 주입). 이후 사용자가 등록/삭제 가능.
    static let seedSamples: [MarketItem] = rawSeed.map {
        var i = $0; i.hygieneChecks = hygieneOptions; return i
    }
    private static let rawSeed: [MarketItem] = [
        MarketItem(id: "s1", title: "스토케 트립트랩 식사의자",  category: .meal,  grade: .s, monthsTag: "6개월+",    price: 180_000, originalPrice: 350_000, isFree: false, hasRecall: false, isGraduate: false, sellerName: "보리맘",  sellerTier: .golden, distanceText: "210m",  favoriteCount: 34, photoSeed: 5),
        MarketItem(id: "s2", title: "에어웨이브 공기청정 유모차", category: .ride,  grade: .a, monthsTag: "0–36개월",  price: 95_000,  originalPrice: 280_000, isFree: false, hasRecall: false, isGraduate: true,  sellerName: "하준이네", sellerTier: .warm,   distanceText: "480m",  favoriteCount: 21, photoSeed: 1),
        MarketItem(id: "s3", title: "코니 바운서 아기 그네",     category: .toy,   grade: .b, monthsTag: "0–6개월",   price: 35_000,  originalPrice: 89_000,  isFree: false, hasRecall: true,  isGraduate: true,  sellerName: "민서맘",  sellerTier: .warm,   distanceText: "320m",  favoriteCount: 12, photoSeed: 3),
        MarketItem(id: "s4", title: "모유 냉동 보관팩 80매",     category: .feed,  grade: .s, monthsTag: "전 월령",    price: 0,       originalPrice: nil,     isFree: true,  hasRecall: false, isGraduate: false, sellerName: "서연이네", sellerTier: .golden, distanceText: "90m",   favoriteCount: 8,  photoSeed: 2),
        MarketItem(id: "s5", title: "노르딕 방수 점프수트",      category: .cloth, grade: .a, monthsTag: "12–18개월",  price: 22_000,  originalPrice: 68_000,  isFree: false, hasRecall: false, isGraduate: true,  sellerName: "지우맘",  sellerTier: .new,    distanceText: "560m",  favoriteCount: 5,  photoSeed: 4),
        MarketItem(id: "s6", title: "베이비뵨 바운서 블리스",    category: .toy,   grade: .s, monthsTag: "0–8개월",   price: 120_000, originalPrice: 249_000, isFree: false, hasRecall: false, isGraduate: false, sellerName: "태양맘",  sellerTier: .warm,   distanceText: "740m",  favoriteCount: 27, photoSeed: 0),
    ]
}

// MARK: - MarketScreen

/// DongneTab의 "마켓" 세그먼트에 임베드하는 메인 뷰.
struct MarketScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedCategory: MarketCategory = .all
    @State private var showSellSheet: Bool = false

    private var filteredItems: [MarketItem] {
        if selectedCategory == .all { return store.marketItems }
        return store.marketItems.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                BLSampleNote(message: "내가 등록한 매물은 기기에 저장돼요. 동네 이웃과의 실시간 거래는 곧 열려요.")
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s3)
                    .padding(.bottom, Spacing.s2)
                needSoonSection
                categoryChips
                itemList
                    .padding(.bottom, 80) // FAB 여백
            }
        }
        .background(AppColors.canvas.ignoresSafeArea())
        // 공용 글래스 FAB — 팔기 (모양·위치는 전 화면 공유, 기능만 다름)
        .appFAB { Haptics.light(); showSellSheet = true }
        .sheet(isPresented: $showSellSheet) {
            MkSellFlowSheet()
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 곧 필요해요 섹션
    private var needSoonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                Text("곧 필요해요")
                    .font(AppFont.title)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("월령 기반")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s3)
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(mkNeedSoonItems) { item in
                        MkNeedSoonCard(item: item) {
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.2)) { selectedCategory = item.category }
                        }
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("곧 필요해요 — 월령 기반 추천")
    }

    // MARK: 카테고리 칩
    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(MarketCategory.allCases, id: \.self) { cat in
                    Button {
                        selectedCategory = cat
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: cat.systemIcon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(cat.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(selectedCategory == cat ? Color.white : AppColors.ink2)
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                        .background(selectedCategory == cat ? AppColors.ink : AppColors.surface, in: Capsule())
                        .overlay { Capsule().stroke(selectedCategory == cat ? AppColors.ink.opacity(0.25) : AppColors.line, lineWidth: 1) }
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.96))
                    .accessibilityLabel(cat.rawValue)
                    .accessibilityAddTraits(selectedCategory == cat ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.s5)
        }
        .padding(.bottom, 14)
    }

    // MARK: 매물 리스트
    private var itemList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(filteredItems.count)개 매물")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .padding(.horizontal, 2)
                .padding(.bottom, Spacing.s2)

            if filteredItems.isEmpty {
                BLEmptyState(
                    icon: "tag",
                    title: "이 카테고리에 매물이 없어요",
                    message: "다른 카테고리를 둘러보거나 직접 올려보세요."
                )
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s4)
            } else {
                ForEach(filteredItems) { item in
                    NavigationLink(value: item) {
                        MkItemCard(item: item)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, Spacing.s5)
        .navigationDestination(for: MarketItem.self) { item in
            MarketItemDetail(item: item)
        }
    }

}

// MARK: - MkNeedSoonCard

private struct MkNeedSoonCard: View {
    let item: MarketNeedSoonItem
    var onTap: () -> Void = {}

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    PhotoPlaceholder(seed: item.photoSeed, cornerRadius: 14)
                        .frame(width: 124, height: 92)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .overlay {
                    // 캔버스와 카드가 섞이지 않도록 옅은 테두리로 구분
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 0.5)
                }

                Text(item.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)

                Text(item.reason)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .lineLimit(1)
            }
            .frame(width: 124)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(item.title) — \(item.reason)")
    }
}

// MARK: - MkItemCard

private struct MkItemCard: View {
    let item: MarketItem

    private let photoSide: CGFloat = 116

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            photo
            VStack(alignment: .leading, spacing: 5) {
                // 제목
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // 메타: 거리 · 시간
                Text(metaText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .lineLimit(1)

                // 가격
                Text(item.isFree ? "무료나눔" : "\(item.price.formatted())원")
                    .font(AppFont.num(16, weight: .heavy))
                    .foregroundStyle(item.isFree ? AppColors.primary : AppColors.ink)
                    .padding(.top, 1)

                // 상태/리콜/졸업 칩 (있을 때만)
                if item.status != .selling || item.hasRecall || item.isGraduate {
                    HStack(spacing: 5) {
                        if item.status != .selling {
                            BLBadge(tone: item.status == .sold ? .grey : .amber, text: item.status.rawValue, systemIcon: nil, dot: false)
                        }
                        if item.hasRecall {
                            BLBadge(tone: .coral, text: "리콜", systemIcon: "exclamationmark.triangle.fill", dot: false)
                        }
                        if item.isGraduate {
                            BLBadge(tone: .mint, text: "졸업템", systemIcon: nil, dot: true)
                        }
                    }
                    .padding(.top, 1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 관심 수 (우하단 정렬)
            VStack {
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    Image(systemName: "heart")
                        .font(.system(size: 12, weight: .semibold))
                    Text("\(item.favoriteCount)")
                        .font(.system(size: 12.5, weight: .medium))
                }
                .foregroundStyle(AppColors.ink3)
            }
        }
        .frame(minHeight: photoSide)
        .padding(.vertical, Spacing.s3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.line2).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var photo: some View {
        Group {
            if let img = PhotoStore.image(item.photoRefs.first) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                PhotoPlaceholder(seed: item.photoSeed, cornerRadius: 0)
            }
        }
        .frame(width: photoSide, height: photoSide)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .stroke(AppColors.line, lineWidth: 0.5)
        }
        .overlay(alignment: .topLeading) {
            if item.isFree {
                BLBadge(tone: .mint, text: "나눔", systemIcon: nil, dot: false).padding(7)
            }
        }
        .accessibilityHidden(true)
    }

    private var metaText: String {
        var parts: [String] = []
        if !item.distanceText.isEmpty { parts.append(item.distanceText) }
        parts.append(item.createdAt.blRelativeShort)
        return parts.joined(separator: " · ")
    }

    private var accessibilityDescription: String {
        let priceDesc = item.isFree ? "무료나눔" : "\(item.price.formatted())원"
        let recallDesc = item.hasRecall ? ", 리콜 이력 있음" : ""
        return "\(item.title), \(priceDesc), \(item.distanceText), 관심 \(item.favoriteCount)\(recallDesc)"
    }
}

private extension Date {
    /// "방금 전 / N분 전 / N시간 전 / N일 전 / N개월 전"
    var blRelativeShort: String {
        let s = Int(Date().timeIntervalSince(self))
        if s < 60 { return "방금 전" }
        if s < 3600 { return "\(s/60)분 전" }
        if s < 86400 { return "\(s/3600)시간 전" }
        if s < 86400*30 { return "\(s/86400)일 전" }
        return "\(s/(86400*30))개월 전"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        MarketScreen()
    }
}
#endif
