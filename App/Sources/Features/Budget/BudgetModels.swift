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
