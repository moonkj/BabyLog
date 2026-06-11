import Foundation

// MARK: - Tier

/// SPEC 7.2 · 4단계 신뢰도 티어.
/// 골든 맘/파파 호칭은 사용자 호칭 설정으로 결정 — 이 enum은 성별 중립 displayName 제공.
enum Tier: String, CaseIterable, Equatable {
    case sprout       = "sprout"
    case warmNeighbor = "warmNeighbor"
    case trusted      = "trusted"
    case golden       = "golden"

    /// 성별 중립 기본 명칭. 맘/파파 호칭은 호칭 설정 레이어에서 처리.
    var displayName: String {
        switch self {
        case .sprout:       return "새싹"
        case .warmNeighbor: return "따뜻한 이웃"
        case .trusted:      return "믿음직한 이웃"
        case .golden:       return "골든"
        }
    }

    /// 3중 인코딩용 색조 (색+아이콘+레이블) — AppColors.BadgeTone 매핑
    var badgeTone: BadgeTone {
        switch self {
        case .sprout:       return .grey
        case .warmNeighbor: return .mint
        case .trusted:      return .purple
        case .golden:       return .amber
        }
    }

    /// SF Symbol 아이콘 이름 (3중 인코딩: 색 + 아이콘 + 레이블)
    var systemIcon: String {
        switch self {
        case .sprout:       return "leaf.fill"
        case .warmNeighbor: return "heart.fill"
        case .trusted:      return "checkmark.seal.fill"
        case .golden:       return "star.fill"
        }
    }

    /// 다음 티어 (최상위는 nil)
    var next: Tier? {
        switch self {
        case .sprout:       return .warmNeighbor
        case .warmNeighbor: return .trusted
        case .trusted:      return .golden
        case .golden:       return nil
        }
    }
}

// MARK: - TierCalculator

/// SPEC 7.2 티어 계산 — 순수 함수, 부작용 없음. QA 단위 테스트 계약.
///
/// 승급 조건:
/// - `.golden`      : 거래 30+ AND 평점 4.8+ AND 가입 6개월+
/// - `.trusted`     : 거래 10+ AND 평점 4.5+
/// - `.warmNeighbor`: 거래 3+
/// - `.sprout`      : 나머지
///
/// 판정 순서: golden → trusted → warmNeighbor → sprout (하향 평가)
enum TierCalculator {

    /// SPEC 7.2 기준으로 티어를 결정한다.
    /// - Parameters:
    ///   - tradeCount:   완료 거래 횟수 (분쟁 감산 후 값을 전달)
    ///   - avgRating:    후기 평균 평점 0.0~5.0
    ///   - joinedMonths: 가입 경과 개월 수
    /// - Returns: 해당 유저의 현재 `Tier`
    static func tier(tradeCount: Int, avgRating: Double, joinedMonths: Int) -> Tier {
        if tradeCount >= 30, avgRating >= 4.8, joinedMonths >= 6 {
            return .golden
        }
        if tradeCount >= 10, avgRating >= 4.5 {
            return .trusted
        }
        if tradeCount >= 3 {
            return .warmNeighbor
        }
        return .sprout
    }

    // MARK: Progress helpers (ProfileScreen 진행바용)

    /// 다음 티어까지 남은 거래 수. 현재 티어가 골든이면 0.
    static func tradesNeededForNext(currentTier: Tier, tradeCount: Int) -> Int {
        switch currentTier {
        case .sprout:       return max(0, 3  - tradeCount)
        case .warmNeighbor: return max(0, 10 - tradeCount)
        case .trusted:      return max(0, 30 - tradeCount)
        case .golden:       return 0
        }
    }

    /// 다음 티어의 거래 기준치 (진행바 분모)
    static func tradeThresholdForNext(currentTier: Tier) -> Int {
        switch currentTier {
        case .sprout:       return 3
        case .warmNeighbor: return 10
        case .trusted:      return 30
        case .golden:       return 30 // 최상위 — 분모용 참조값
        }
    }

    /// 진행률 0.0~1.0 (분자: 현재 거래수, 분모: 다음 티어 기준치)
    static func progress(tradeCount: Int, currentTier: Tier) -> Double {
        let threshold = tradeThresholdForNext(currentTier: currentTier)
        guard threshold > 0 else { return 1.0 }
        // 이전 티어 기준치를 기점으로 구간 내 진행률 계산
        let base: Int
        switch currentTier {
        case .sprout:       base = 0
        case .warmNeighbor: base = 3
        case .trusted:      base = 10
        case .golden:       base = 30
        }
        let span = threshold - base
        guard span > 0 else { return 1.0 }
        let done = min(tradeCount - base, span)
        return Double(max(0, done)) / Double(span)
    }
}

// MARK: - BadgeCatalogItem

/// SPEC 7.3 뱃지 카탈로그 — 로컬 샘플 (서버 응답 전 UI 렌더링용)
struct BadgeCatalogItem: Identifiable, Equatable {
    let id: String
    let name: String
    let condition: String
    let tone: BadgeTone
    let systemIcon: String
    let category: BadgeCategory
    var isEarned: Bool

    enum BadgeCategory: String {
        case tier       = "등급"
        case milestone  = "성장"
        case record     = "기록"
        case trade      = "거래"
        case community  = "커뮤니티"
        case special    = "특별"
    }
}

extension BadgeCatalogItem {
    /// SPEC 7.3 전체 카탈로그 중 ProfileScreen 표시용 10개 샘플
    static let sampleCatalog: [BadgeCatalogItem] = [
        // 성장(마일스톤) — 실데이터 기반
        .init(id: "first_child",      name: "첫 아이 등록",  condition: "아이 프로필 만들기",        tone: .mint,   systemIcon: "figure.and.child.holdinghands", category: .milestone, isEarned: false),
        .init(id: "pregnancy_logged", name: "태교 시작",     condition: "임신 기록 시작",            tone: .pink,   systemIcon: "heart.circle.fill",     category: .milestone, isEarned: false),
        .init(id: "first_photo",      name: "첫 사진",       condition: "사진 기록 1장",             tone: .blue,   systemIcon: "camera.fill",           category: .milestone, isEarned: false),
        .init(id: "hundred_days",     name: "백일의 기적",   condition: "아이 100일 달성",           tone: .amber,  systemIcon: "star.circle.fill",      category: .milestone, isEarned: false),
        .init(id: "first_birthday",   name: "첫 생일",       condition: "아이 첫 돌 달성",           tone: .amber,  systemIcon: "birthday.cake.fill",    category: .milestone, isEarned: false),
        .init(id: "multi_child",      name: "다둥이 양육자", condition: "아이 2명 이상 등록",        tone: .purple, systemIcon: "person.2.fill",         category: .milestone, isEarned: false),
        .init(id: "growth_tracker",   name: "성장 기록가",   condition: "성장 측정 5회 이상",        tone: .mint,   systemIcon: "ruler.fill",            category: .milestone, isEarned: false),
        .init(id: "memory_keeper",    name: "추억 수집가",   condition: "기록 10개 이상",            tone: .purple, systemIcon: "photo.stack.fill",      category: .milestone, isEarned: false),
        // 거래
        .init(id: "first_listing",  name: "첫 매물 등록", condition: "마켓에 첫 매물 올리기",        tone: .mint,   systemIcon: "tag.fill",              category: .trade,     isEarned: false),
        .init(id: "first_trade",    name: "첫 거래 완료", condition: "첫 거래 성사",                tone: .grey,   systemIcon: "bag.fill",              category: .trade,     isEarned: true),
        .init(id: "share_angel",    name: "나눔 천사",    condition: "무료나눔 3회 이상",            tone: .mint,   systemIcon: "gift.fill",             category: .trade,     isEarned: true),
        .init(id: "fast_reply",     name: "빠른 답장",    condition: "응답률 90% 이상 30일",        tone: .mint,   systemIcon: "bolt.fill",             category: .trade,     isEarned: false),
        .init(id: "safe_seller",    name: "안심 판매자",  condition: "거래 10회+ / 분쟁 0 / 4.5+", tone: .purple, systemIcon: "shield.fill",           category: .trade,     isEarned: false),
        // 기록
        .init(id: "record_start",   name: "기록 시작",    condition: "첫 성장 기록 작성",            tone: .mint,   systemIcon: "pencil",                category: .record,    isEarned: true),
        .init(id: "streak_30",      name: "30일 연속",    condition: "30일 연속 일지 작성",          tone: .mint,   systemIcon: "flame.fill",            category: .record,    isEarned: false),
        .init(id: "parenting_pro",  name: "육아고수",     condition: "총 기록 50회 이상",            tone: .purple, systemIcon: "book.fill",             category: .record,    isEarned: false),
        // 커뮤니티
        .init(id: "first_crew",     name: "첫 크루 모임", condition: "첫 번째 크루 참여",            tone: .blue,   systemIcon: "person.3.fill",         category: .community, isEarned: true),
        .init(id: "neighborhood",   name: "든든한 이웃",  condition: "도움 반응 50회 이상",          tone: .purple, systemIcon: "hands.sparkles.fill",   category: .community, isEarned: false),
        // 특별
        .init(id: "early_member",   name: "초기 멤버",    condition: "정식 출시 30일 이내 가입",     tone: .amber,  systemIcon: "crown.fill",            category: .special,   isEarned: true),
    ]
}
