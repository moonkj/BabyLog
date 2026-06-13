import Foundation

// MARK: - BadgeEngine

/// SPEC 7.3 활동 기준 뱃지 자동 부여 엔진 — 순수 함수, 부작용 없음. QA 단위 테스트 계약.
///
/// 각 조건은 독립 평가되며, 충족된 뱃지 key만 Set에 포함됩니다.
/// TierCalculator(SPEC 7.2)와 역할이 분리됨 — 티어 계산은 TierCalculator에 위임.
///
/// 부여 규칙 (SPEC 7.3):
/// - "record_start"    : recordCount >= 1          (기록 시작)
/// - "streak_30"       : consecutiveDays >= 30     (30일 연속 기록)
/// - "parenting_pro"   : recordCount >= 50         (육아고수)        ← 실제 발급 id와 일치하도록 문서 정정(parenting_master 오기)
/// - "share_angel"     : tradeCount >= 3           (나눔 천사)        ← 카탈로그 id에 맞춰 정합화(구 sharing_angel)
/// - "trade_50"        : tradeCount >= 50          (거래 50회)
/// - "first_crew"      : crewMeetings >= 1         (첫 크루 모임)
/// - "info_master"     : postLikes >= 500          (동네 인플루언서)  ← 성별 중립 원칙에 따라 명칭 정정(구 맘 인플루언서)
enum BadgeEngine {

    /// 활동 지표를 기반으로 조건이 충족된 뱃지 식별자 집합을 반환한다.
    ///
    /// - Parameters:
    ///   - recordCount:      총 성장 기록 작성 횟수 (0 이상)
    ///   - consecutiveDays:  현재까지 연속 일지 작성일 수 (0 이상)
    ///   - tradeCount:       완료된 거래 횟수 (무료나눔 포함, 0 이상)
    ///   - crewMeetings:     참여한 크루 모임 횟수 (0 이상)
    ///   - postLikes:        게시글 좋아요 누적 개수 (0 이상)
    /// - Returns: 조건을 충족한 뱃지 key의 `Set<String>`. 조건 미충족 시 빈 Set.
    static func earnedBadges(
        recordCount: Int,
        consecutiveDays: Int,
        tradeCount: Int,
        crewMeetings: Int,
        postLikes: Int
    ) -> Set<String> {
        var badges: Set<String> = []

        // MARK: 육아 기록 뱃지
        if recordCount >= 1  { badges.insert("record_start") }
        if consecutiveDays >= 30 { badges.insert("streak_30") }
        if recordCount >= 50 { badges.insert("parenting_pro") }   // 카탈로그 id와 일치(육아고수)

        // MARK: 거래 활동 뱃지
        if tradeCount >= 3   { badges.insert("share_angel") }     // 카탈로그 id와 일치(나눔 천사) — 구 "sharing_angel" 정합화
        if tradeCount >= 50  { badges.insert("trade_50") }

        // MARK: 커뮤니티 활동 뱃지
        if crewMeetings >= 1 { badges.insert("first_crew") }
        if postLikes >= 500  { badges.insert("info_master") }

        return badges
    }
}
