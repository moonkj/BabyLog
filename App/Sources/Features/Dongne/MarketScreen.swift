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
    var photoRefs: [String] = []          // 로컬 PhotoStore 참조(무료·오프라인)
    var photoURLs: [String] = []          // 서버 공개 사진 URL(마켓 공유 시)
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

// 하위 호환 디코딩 — 필드 추가 시 구 저장파일 keyNotFound로 전체 상태가 날아가는 사고 방지
// (실제 이력: hygieneChecks·photoURLs 추가 때 두 번 발생). 알 수 없는 enum 값도 기본값으로 흡수.
extension MarketItem {
    enum CodingKeys: String, CodingKey {
        case id, title, category, grade, monthsTag, price, originalPrice, isFree, hasRecall
        case isGraduate, sellerName, sellerTier, distanceText, favoriteCount, photoSeed
        case description, photoRefs, photoURLs, mine, status, createdAt, hygieneChecks
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title         = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        category      = MarketCategory(rawValue: (try? c.decode(String.self, forKey: .category)) ?? "") ?? .etc
        grade         = MarketItemGrade(rawValue: (try? c.decode(String.self, forKey: .grade)) ?? "") ?? .a
        monthsTag     = try c.decodeIfPresent(String.self, forKey: .monthsTag) ?? "전 월령"
        price         = try c.decodeIfPresent(Int.self, forKey: .price) ?? 0
        originalPrice = try c.decodeIfPresent(Int.self, forKey: .originalPrice)
        isFree        = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        hasRecall     = try c.decodeIfPresent(Bool.self, forKey: .hasRecall) ?? false
        isGraduate    = try c.decodeIfPresent(Bool.self, forKey: .isGraduate) ?? false
        sellerName    = try c.decodeIfPresent(String.self, forKey: .sellerName) ?? "이웃"
        sellerTier    = MarketSellerTier(rawValue: (try? c.decode(String.self, forKey: .sellerTier)) ?? "") ?? .new
        distanceText  = try c.decodeIfPresent(String.self, forKey: .distanceText) ?? ""
        favoriteCount = try c.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        photoSeed     = try c.decodeIfPresent(Int.self, forKey: .photoSeed) ?? 0
        description   = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        photoRefs     = try c.decodeIfPresent([String].self, forKey: .photoRefs) ?? []
        photoURLs     = try c.decodeIfPresent([String].self, forKey: .photoURLs) ?? []
        mine          = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        status        = MarketStatus(rawValue: (try? c.decode(String.self, forKey: .status)) ?? "") ?? .selling
        createdAt     = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        hygieneChecks = try c.decodeIfPresent([String].self, forKey: .hygieneChecks) ?? []
    }
}

/// "곧 필요해요" 월령 연동 추천 아이템.
/// 실제 매물이 아니라 월령별 육아용품 타임라인(편집 콘텐츠)에서 산출되는 '카테고리 추천'.
/// 탭하면 해당 카테고리의 실제 매물로 필터된다.
struct MarketNeedSoonItem: Identifiable {
    let id: Int
    let title: String
    let category: MarketCategory   // 탭 시 해당 카테고리로 필터
    let fromMonth: Int             // 보통 이 월령부터 필요해지는 용품

    /// 현재 아이 월령 기준 안내 문구.
    func reason(ageMonths: Int) -> String {
        let diff = fromMonth - ageMonths
        if diff <= 0 { return "지금 쓰기 좋아요" }
        if diff <= 2 { return "곧 필요해요" }
        return "\(fromMonth)개월쯤 필요해요"
    }
}

// MARK: - 월령별 육아용품 타임라인 (편집 콘텐츠)

/// 월령별로 보통 필요해지는 육아용품 카탈로그. 신청·구매가 아닌 '둘러보기 추천'.
private let mkNeedSoonCatalog: [MarketNeedSoonItem] = [
    .init(id: 1,  title: "모빌·바운서",      category: .toy,    fromMonth: 1),
    .init(id: 2,  title: "목욕 의자",        category: .bath,   fromMonth: 3),
    .init(id: 3,  title: "치발기·쪽쪽이",    category: .feed,   fromMonth: 3),
    .init(id: 4,  title: "이유식 식기",      category: .meal,   fromMonth: 5),
    .init(id: 5,  title: "이유식 의자",      category: .meal,   fromMonth: 6),
    .init(id: 6,  title: "점퍼루·보행기",    category: .ride,   fromMonth: 6),
    .init(id: 7,  title: "안전문·안전용품",  category: .safety, fromMonth: 8),
    .init(id: 8,  title: "걸음마 보조기",    category: .ride,   fromMonth: 10),
    .init(id: 9,  title: "빨대컵·유아식기",  category: .meal,   fromMonth: 12),
    .init(id: 10, title: "유아 신발",        category: .cloth,  fromMonth: 12),
    .init(id: 11, title: "회전형 카시트",    category: .safety, fromMonth: 12),
    .init(id: 12, title: "유아 도서·교구",   category: .book,   fromMonth: 14),
    .init(id: 13, title: "실내 놀이기구",    category: .toy,    fromMonth: 18),
    .init(id: 14, title: "배변훈련 변기",    category: .bath,   fromMonth: 20),
    .init(id: 15, title: "유아 책상·의자",   category: .furn,   fromMonth: 24),
]

/// 아이 월령 기준 추천 목록 — 다가올(아직 안 된) 용품을 가까운 순으로 먼저, 그다음 지난 것.
/// 어떤 월령에서도 항상 채워지도록 거리순 정렬 후 상위 6개.
private func mkNeedSoonItems(ageMonths: Int) -> [MarketNeedSoonItem] {
    mkNeedSoonCatalog
        .sorted { a, b in
            let ua = a.fromMonth >= ageMonths, ub = b.fromMonth >= ageMonths
            if ua != ub { return ua }                       // 다가올 것 먼저
            return abs(a.fromMonth - ageMonths) < abs(b.fromMonth - ageMonths)  // 가까운 순
        }
        .prefix(6)
        .map { $0 }
}

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
    @ObservedObject private var location = NearbyLocationProvider.shared
    @State private var selectedCategory: MarketCategory = .all
    @State private var showSellSheet: Bool = false
    @State private var sharedItems: [MarketItem]? = nil
    @State private var didLoad = false
    @State private var loadFailed = false
    /// '관심'만 보기 — 내가 좋아요(저장)한 매물만 필터.
    @State private var showSavedOnly = false
    /// 첫 등장 이후 재등장(상세에서 복귀 등) 시 목록을 갱신해 상태 변경을 반영하기 위한 플래그.
    @State private var hasAppeared = false

    /// 서버 공유 모드(Supabase 구성됨). 미구성 시 로컬(기기 저장) 폴백.
    private var serverMode: Bool { SupabaseConfig.isConfigured }
    private var hood: String { location.localityName ?? "우리 동네" }
    /// 동네(localityName) 확정 전엔 로딩 유지 — 폴백("우리 동네")으로 조회한 빈 목록이
    /// "0개 매물"로 플래시되는 것 방지(CrewScreen 패턴). 위치 거부 시엔 폴백으로 바로 표시.
    private var isLoading: Bool { serverMode && (!didLoad || (location.localityName == nil && !location.denied)) }

    /// 선택된 아이의 월령(없으면 nil) — "곧 필요해요" 월령 기반 추천에 사용.
    private var childAgeMonths: Int? {
        guard let child = store.selectedChild else { return nil }
        return AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: Date()).months
    }

    /// 화면에 쓸 매물 — 서버 모드면 공유 목록, 아니면 로컬.
    private var items: [MarketItem] { serverMode ? (sharedItems ?? []) : store.marketItems }

    private var filteredItems: [MarketItem] {
        var result = items
        if showSavedOnly { result = result.filter { store.isMarketSaved($0.id) } }   // 관심만
        if selectedCategory != .all { result = result.filter { $0.category == selectedCategory } }
        return result
    }

    private func loadItems() async {
        guard serverMode else { return }
        if let s = await MarketBackend.fetchItems(hood: hood) {
            sharedItems = s
            loadFailed = false
        } else {
            loadFailed = true   // 네트워크 실패 — 빈 동네와 구분
        }
        didLoad = true
        // 업로드 실패한 신고 재시도(증거 유실 방지).
        for r in store.pendingReports {
            if await MarketBackend.uploadReport(r) { store.markReportUploaded(r.id) }
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if !serverMode {
                    BLSampleNote(message: "내가 등록한 매물은 기기에 저장돼요. 동네 이웃과의 실시간 거래는 곧 열려요.")
                        .padding(.horizontal, Spacing.s5)
                        .padding(.top, Spacing.s3)
                        .padding(.bottom, Spacing.s2)
                }
                // 월령 기반 추천 — 아이가 등록돼 월령을 알 때만 노출(없으면 '월령 기반'이 거짓이 됨).
                if let age = childAgeMonths {
                    needSoonSection(age: age)
                }
                categoryChips
                if isLoading {
                    marketLoadingView
                } else {
                    itemList
                        .padding(.bottom, 80) // FAB 여백
                }
            }
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .refreshable { await loadItems() }
        // 공용 글래스 FAB — 팔기 (모양·위치는 전 화면 공유, 기능만 다름)
        .appFAB { Haptics.light(); showSellSheet = true }
        .sheet(isPresented: $showSellSheet) {
            MkSellFlowSheet()
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .task(id: hood) { didLoad = false; loadFailed = false; await loadItems() }
        .onChange(of: showSellSheet) { _, open in if !open { Task { await loadItems() } } }
        // 상세에서 상태 변경(예약중/판매완료)·삭제 후 돌아오면 목록을 갱신해 반영한다.
        // (첫 등장은 .task가 처리하므로 재등장부터)
        .onAppear {
            if hasAppeared { Task { await loadItems() } }
            hasAppeared = true
        }
        .accessibilityElement(children: .contain)
    }

    private var marketLoadingView: some View {
        VStack(spacing: Spacing.s3) {
            ProgressView()
            Text("우리 동네 매물을 불러오는 중…")
                .font(AppFont.caption).foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .accessibilityLabel("우리 동네 매물을 불러오는 중")
    }

    // MARK: 곧 필요해요 섹션 (월령 기반)
    private func needSoonSection(age: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                Text("곧 필요해요")
                    .font(AppFont.title)
                    .foregroundStyle(AppColors.ink)
                Spacer()
                BLBadge(tone: .grey, text: "\(age)개월 기준", systemIcon: nil, dot: false)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s3)
            .padding(.bottom, Spacing.s3)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s3) {
                    ForEach(mkNeedSoonItems(ageMonths: age)) { item in
                        MkNeedSoonCard(item: item, reason: item.reason(ageMonths: age)) {
                            Haptics.selection()
                            withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = item.category }
                        }
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s1)
            }
        }
        .padding(.bottom, Spacing.s4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("곧 필요해요 — \(age)개월 기준 추천")
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
            if loadFailed && items.isEmpty {
                marketLoadFailedView
            } else {
                // 개수 + '관심만 보기' 토글
                HStack(spacing: Spacing.s2) {
                    Text("\(showSavedOnly ? "관심 " : "")\(filteredItems.count)개 매물")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                    Spacer(minLength: 0)
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.2)) { showSavedOnly.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSavedOnly ? "heart.fill" : "heart")
                                .font(.system(size: 12, weight: .bold))
                            Text("관심").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(showSavedOnly ? AppColors.danger : AppColors.ink2)
                        .padding(.horizontal, 12).frame(height: 32)
                        .background(showSavedOnly ? AppColors.dangerTint : AppColors.surface, in: Capsule())
                        .overlay { Capsule().stroke(showSavedOnly ? AppColors.danger.opacity(0.4) : AppColors.line, lineWidth: 1) }
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.95))
                    .accessibilityLabel(showSavedOnly ? "관심 매물만 보는 중 — 해제" : "관심 매물만 보기")
                    .accessibilityAddTraits(showSavedOnly ? [.isSelected] : [])
                }
                .padding(.horizontal, 2)
                .padding(.bottom, Spacing.s2)

                if filteredItems.isEmpty {
                    BLEmptyState(
                        icon: showSavedOnly ? "heart" : "tag",
                        title: showSavedOnly ? "관심 매물이 없어요" : "이 카테고리에 매물이 없어요",
                        message: showSavedOnly ? "마음에 드는 매물에 하트를 눌러 모아보세요." : "다른 카테고리를 둘러보거나 직접 올려보세요."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s4)
                } else {
                    // 긴 목록 성능 — 행/이미지를 화면에 보일 때 지연 로드
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                MkItemCard(item: item, isSaved: store.isMarketSaved(item.id))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.s5)
        .navigationDestination(for: MarketItem.self) { item in
            MarketItemDetail(item: item)
        }
    }

    // MARK: 불러오기 실패 (네트워크) — 빈 동네와 구분
    private var marketLoadFailedView: some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("매물을 불러오지 못했어요")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.ink)
            Text("네트워크 연결을 확인하고 다시 시도해 주세요.")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)

            Button {
                Haptics.light()
                Task { await loadItems() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("다시 시도")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(AppColors.surface, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.96))
            .padding(.top, Spacing.s1)
            .accessibilityLabel("다시 시도")
            .accessibilityHint("매물 목록을 다시 불러옵니다")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("매물을 불러오지 못했어요. 네트워크 연결을 확인하고 다시 시도해 주세요.")
    }

}

// MARK: - MkNeedSoonCard

private struct MkNeedSoonCard: View {
    let item: MarketNeedSoonItem
    let reason: String
    var onTap: () -> Void = {}

    var body: some View {
        Button { onTap() } label: {
            VStack(alignment: .leading, spacing: 7) {
                // 실제 매물이 아니라 카테고리 추천이므로 가짜 사진 대신 카테고리 아이콘 타일.
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primaryTint, AppColors.primaryTint.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 124, height: 92)
                    Image(systemName: item.category.systemIcon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(AppColors.primary)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 0.5)
                }

                Text(item.title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(item.category.rawValue)
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(AppColors.primary)
                    Text("·")
                        .font(.system(size: 10.5))
                        .foregroundStyle(AppColors.ink3)
                    Text(reason)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .lineLimit(1)
                }
            }
            .frame(width: 124)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(item.title), \(item.category.rawValue) — \(reason). 탭하면 해당 카테고리 매물을 봅니다.")
    }
}

// MARK: - MkItemCard

private struct MkItemCard: View {
    let item: MarketItem
    /// 내가 관심(좋아요)한 매물인지 — 상세에서 누른 하트가 목록에도 반영되도록.
    var isSaved: Bool = false

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

            // 내 관심 표시 (우하단) — 상세에서 누른 하트가 여기 반영된다.
            // 서버는 좋아요 수를 집계하지 않으므로(항상 0) 가짜 카운트 대신 '내 저장' 상태만 정직 표시.
            VStack {
                Spacer(minLength: 0)
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSaved ? AppColors.danger : AppColors.ink3.opacity(0.5))
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
        MarketPhotoView(urls: item.photoURLs, refs: item.photoRefs, seed: item.photoSeed, index: 0, cornerRadius: 0)
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
        let statusDesc = item.status != .selling ? ", \(item.status.rawValue)" : ""
        let savedDesc = isSaved ? ", 관심 등록됨" : ""
        return "\(item.title), \(priceDesc), \(item.distanceText)\(statusDesc)\(savedDesc)\(recallDesc)"
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
