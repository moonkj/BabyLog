// BudgetModels.swift
// BabyLog — Features/Budget
//
// 도메인 모델 + 순수 계산 레이어.
// UI/SwiftUI 의존 없음 — QA(XCTest)가 직접 임포트해 계약 테스트.

import Foundation

// MARK: - ExpenseCategory

/// 지출 카테고리.
/// color+icon+label 3중 인코딩 → 색약 대응 (DESIGN.md §2.2 / CLAUDE.md 접근성 내재화).
enum ExpenseCategory: String, CaseIterable, Codable {
    case diaper
    case clothing
    case medical
    case education
    case play
    case transport
    case etc

    /// 화면 표시 레이블 (한국어)
    var displayName: String {
        switch self {
        case .diaper:    return "소모품"
        case .clothing:  return "의류·용품"
        case .medical:   return "의료"
        case .education: return "교육"
        case .play:      return "놀이"
        case .transport: return "이동"
        case .etc:       return "기타"
        }
    }

    /// SF Symbol — 색+아이콘+레이블 3중 인코딩 중 아이콘
    var systemIcon: String {
        switch self {
        case .diaper:    return "tray.2.fill"
        case .clothing:  return "tshirt.fill"
        case .medical:   return "cross.case.fill"
        case .education: return "book.fill"
        case .play:      return "teddybear.fill"
        case .transport: return "car.fill"
        case .etc:       return "ellipsis.circle.fill"
        }
    }

    /// VoiceOver용 접근성 레이블 (더 명확한 설명)
    var accessibilityLabel: String {
        switch self {
        case .diaper:    return "소모품 (기저귀·물티슈 등)"
        case .clothing:  return "의류 및 용품"
        case .medical:   return "의료 및 병원비"
        case .education: return "교육 및 학습"
        case .play:      return "놀이 및 장난감"
        case .transport: return "이동 및 교통"
        case .etc:       return "기타 지출"
        }
    }

    /// BadgeTone 매핑 — DesignSystem AppColors.BadgeTone과 1:1 대응
    var badgeTone: BadgeTone {
        switch self {
        case .diaper:    return .amber
        case .clothing:  return .pink
        case .medical:   return .coral
        case .education: return .purple
        case .play:      return .mint
        case .transport: return .blue
        case .etc:       return .grey
        }
    }
}

// MARK: - Expense

/// 단일 지출 항목.
/// `autoCollected == true`이면 마켓/구독에서 자동 수집된 항목.
struct Expense: Identifiable, Equatable, Codable {
    let id: UUID
    var amount: Int              // 단위: 원 (원화)
    var category: ExpenseCategory
    var date: Date
    var memo: String?
    var autoCollected: Bool

    init(
        id: UUID = UUID(),
        amount: Int,
        category: ExpenseCategory,
        date: Date,
        memo: String? = nil,
        autoCollected: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.memo = memo
        self.autoCollected = autoCollected
    }
}

// 하위 호환 디코딩 — ChatMessage 패턴(CodablePersistence.swift 상단 정책 참조):
// 필드 추가/미지의 category rawValue에도 전체 저장 상태가 keyNotFound로 날아가지 않게
// decodeIfPresent + 기본값으로 흡수한다(미지 카테고리는 .etc로).
extension Expense {
    enum CodingKeys: String, CodingKey {
        case id, amount, category, date, memo, autoCollected
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        amount        = try c.decodeIfPresent(Int.self, forKey: .amount) ?? 0
        category      = ExpenseCategory(rawValue: (try? c.decode(String.self, forKey: .category)) ?? "") ?? .etc
        date          = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        memo          = try c.decodeIfPresent(String.self, forKey: .memo)
        autoCollected = try c.decodeIfPresent(Bool.self, forKey: .autoCollected) ?? false
    }
}

// MARK: - BudgetSummary

/// 지출 집계 순수 함수 모음.
/// 모든 메서드는 부수효과(side-effect) 없음 — QA가 XCTest로 직접 계약 검증.
///
/// ## QA 계약
/// - `monthlyTotal`: 입력 연·월과 동일한 연·월 항목만 `amount` 합산. 빈 배열 → 0.
/// - `byCategory`: 카테고리별 `amount` 합산. 해당 카테고리 항목 없으면 결과 딕셔너리에 키 없음.
enum BudgetSummary {

    /// 특정 월의 총 지출 합계를 반환합니다.
    ///
    /// - Parameters:
    ///   - expenses: 전체 지출 배열.
    ///   - month: 기준 날짜 (연·월만 사용; 일·시각 무시).
    ///   - calendar: 날짜 비교에 사용할 캘린더. 기본값 `.current`.
    /// - Returns: 해당 연·월 지출 합계 (원). 항목 없으면 0.
    static func monthlyTotal(
        _ expenses: [Expense],
        in month: Date,
        calendar: Calendar = .current
    ) -> Int {
        let targetComponents = calendar.dateComponents([.year, .month], from: month)
        return expenses
            .filter { expense in
                let c = calendar.dateComponents([.year, .month], from: expense.date)
                return c.year == targetComponents.year && c.month == targetComponents.month
            }
            .reduce(0) { $0 + $1.amount }
    }

    /// 카테고리별 지출 합계를 딕셔너리로 반환합니다.
    ///
    /// - Parameter expenses: 집계 대상 지출 배열.
    /// - Returns: `[ExpenseCategory: Int]` — 지출이 있는 카테고리만 포함.
    static func byCategory(_ expenses: [Expense]) -> [ExpenseCategory: Int] {
        expenses.reduce(into: [ExpenseCategory: Int]()) { result, expense in
            result[expense.category, default: 0] += expense.amount
        }
    }
}

// MARK: - BudgetPeriod (지출 추이 기간 세그먼트)

/// 지출 추이를 보는 기간 단위. 7일/30일은 일별 막대, 6개월/1년은 월별 막대.
enum BudgetPeriod: String, CaseIterable, Identifiable {
    case week, month, sixMonths, year

    var id: String { rawValue }

    /// 세그먼트 버튼 레이블
    var label: String {
        switch self {
        case .week:      return "7일"
        case .month:     return "30일"
        case .sixMonths: return "6개월"
        case .year:      return "1년"
        }
    }

    /// 총액 헤더용 레이블
    var rangeLabel: String {
        switch self {
        case .week:      return "최근 7일"
        case .month:     return "최근 30일"
        case .sixMonths: return "최근 6개월"
        case .year:      return "최근 1년"
        }
    }

    /// 추이 막대 개수 (일별/월별 버킷 수)
    var bucketCount: Int {
        switch self {
        case .week:      return 7
        case .month:     return 30
        case .sixMonths: return 6
        case .year:      return 12
        }
    }

    /// true면 일별 버킷, false면 월별 버킷
    var isDaily: Bool { self == .week || self == .month }
}

// MARK: - TrendBucket (추이 차트 막대 1개)

/// 추이 차트의 한 버킷(일 또는 월). `date`는 버킷 시작 시각, `amount`는 그 구간 지출 합.
struct TrendBucket: Identifiable, Equatable {
    let date: Date
    let amount: Int
    var id: Date { date }
}

// MARK: - BudgetSummary 기간 집계 확장

extension BudgetSummary {

    private static func startOfMonth(_ date: Date, _ cal: Calendar) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: date)) ?? date
    }

    /// 기간의 시작 시각(포함). 종료는 항상 `now`.
    static func periodStart(
        _ period: BudgetPeriod, now: Date = Date(), calendar cal: Calendar = .current
    ) -> Date {
        switch period {
        case .week:      return cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month:     return cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: now)) ?? now
        case .sixMonths: return cal.date(byAdding: .month, value: -5, to: startOfMonth(now, cal)) ?? now
        case .year:      return cal.date(byAdding: .month, value: -11, to: startOfMonth(now, cal)) ?? now
        }
    }

    /// [from, to] 구간의 지출 합계.
    static func total(_ expenses: [Expense], from: Date, to: Date) -> Int {
        expenses.filter { $0.date >= from && $0.date <= to }.reduce(0) { $0 + $1.amount }
    }

    /// 해당 기간에 속하는 지출만 반환.
    static func inPeriod(
        _ expenses: [Expense], _ period: BudgetPeriod,
        now: Date = Date(), calendar cal: Calendar = .current
    ) -> [Expense] {
        let start = periodStart(period, now: now, calendar: cal)
        return expenses.filter { $0.date >= start && $0.date <= now }
    }

    /// 직전 동일 길이 구간의 지출 합계(전기 대비 비교용). 비교 불가(0)면 nil 처리는 호출부에서.
    /// 직전 구간 = [현재구간시작 - 기간, 현재구간시작) — periodStart에서 연속 분할(반개구간).
    /// (기존: 직전 끝점이 `now-7d` 시각 기준이라 [직전끝, 현재시작) 사이 지출이
    ///  어느 구간에도 안 들어가는 공백이 생기던 버그 수정.)
    static func previousTotal(
        _ expenses: [Expense], _ period: BudgetPeriod,
        now: Date = Date(), calendar cal: Calendar = .current
    ) -> Int {
        let currentStart = periodStart(period, now: now, calendar: cal)
        let prevStart: Date
        switch period {
        case .week:      prevStart = cal.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart
        case .month:     prevStart = cal.date(byAdding: .day, value: -30, to: currentStart) ?? currentStart
        case .sixMonths: prevStart = cal.date(byAdding: .month, value: -6, to: currentStart) ?? currentStart
        case .year:      prevStart = cal.date(byAdding: .month, value: -12, to: currentStart) ?? currentStart
        }
        // 반개구간 [prevStart, currentStart) — 현재 구간 시작점은 포함하지 않는다(중복 집계 방지).
        return expenses
            .filter { $0.date >= prevStart && $0.date < currentStart }
            .reduce(0) { $0 + $1.amount }
    }

    /// 특정 연도(1~12월)의 지출 합계.
    static func yearTotal(
        _ expenses: [Expense], year: Int, calendar cal: Calendar = .current
    ) -> Int {
        expenses
            .filter { cal.component(.year, from: $0.date) == year }
            .reduce(0) { $0 + $1.amount }
    }

    /// 진행 연도 비교용 — 해당 연도 1/1부터, `asOf`를 그 연도로 평행이동한 같은 날짜까지의 합계.
    /// (올해 부분합을 전년 '전체'와 비교하면 항상 큰 감소처럼 왜곡되므로 같은 진행 기간만 비교)
    static func yearToDateTotal(
        _ expenses: [Expense], year: Int, asOf now: Date = Date(), calendar cal: Calendar = .current
    ) -> Int {
        let nowYear = cal.component(.year, from: now)
        guard let cutoff = cal.date(byAdding: .year, value: year - nowYear, to: now) else {
            return yearTotal(expenses, year: year, calendar: cal)   // 계산 불가 시 전체 합계로 폴백
        }
        return expenses
            .filter { cal.component(.year, from: $0.date) == year && $0.date <= cutoff }
            .reduce(0) { $0 + $1.amount }
    }

    /// 특정 연도의 1~12월 월별 추이 버킷(지출 0인 달도 포함).
    static func yearTrend(
        _ expenses: [Expense], year: Int, calendar cal: Calendar = .current
    ) -> [TrendBucket] {
        (1...12).compactMap { m -> TrendBucket? in
            guard let monthStart = cal.date(from: DateComponents(year: year, month: m, day: 1)) else { return nil }
            let amt = expenses
                .filter { cal.isDate($0.date, equalTo: monthStart, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            return TrendBucket(date: monthStart, amount: amt)
        }
    }

    /// 추이 차트용 버킷 배열(지출 0인 구간도 포함해 축이 전체 기간을 덮도록 함).
    static func trend(
        _ expenses: [Expense], _ period: BudgetPeriod,
        now: Date = Date(), calendar cal: Calendar = .current
    ) -> [TrendBucket] {
        var buckets: [TrendBucket] = []
        let n = period.bucketCount
        if period.isDaily {
            let today = cal.startOfDay(for: now)
            for i in stride(from: n - 1, through: 0, by: -1) {
                guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                let amt = expenses
                    .filter { cal.isDate($0.date, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.amount }
                buckets.append(.init(date: day, amount: amt))
            }
        } else {
            let m0 = startOfMonth(now, cal)
            for i in stride(from: n - 1, through: 0, by: -1) {
                guard let mon = cal.date(byAdding: .month, value: -i, to: m0) else { continue }
                let amt = expenses
                    .filter { cal.isDate($0.date, equalTo: mon, toGranularity: .month) }
                    .reduce(0) { $0 + $1.amount }
                buckets.append(.init(date: mon, amount: amt))
            }
        }
        return buckets
    }
}
