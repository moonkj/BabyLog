// BudgetScreen.swift
// BabyLog — Features/Budget
//
// 가계부 탭 메인 화면.
// 팀장이 BudgetTab에서 BudgetScreen()으로 호출.
// 기존 파일 수정 없음 — Features/Budget/ 내부에서만 완결.

import SwiftUI
import Charts
import Foundation

// MARK: - Mock Data

private enum BudgetMockData {

    /// 월령별 예상 지출 가이드 (개월 수 → 메시지). 콘텐츠성 안내 — 실 월령으로 호출됨.
    static func guideMessage(ageMonths: Int) -> (title: String, body: String) {
        switch ageMonths {
        case 0..<3:
            return ("신생아 시기 예상 지출 가이드",
                    "기저귀·분유 소모품 비중이 가장 높아요. 첫만남이용권으로 초기 용품 구매를 줄일 수 있어요.")
        case 3..<6:
            return ("3~5개월 예상 지출 가이드",
                    "목 가누기 시작! 바운서·터미타임 매트 수요가 생겨요. 중고 육아용품 앱 활용을 추천해요.")
        case 6..<9:
            return ("6~8개월 예상 지출 가이드",
                    "이유식 재료비가 본격적으로 발생해요. 월 평균 4~6만원 예산을 잡아두세요.")
        case 9..<12:
            return ("9~11개월 예상 지출 가이드",
                    "손잡고 서기 준비! 보행기·안전문 설치 비용이 발생할 수 있어요.")
        case 12..<18:
            return ("\(ageMonths)개월 예상 지출 가이드",
                    "이유식 재료비가 평균 8만원 추가돼요. 슬슬 유아식 준비도 시작될 시기예요.")
        case 18..<24:
            return ("\(ageMonths)개월 예상 지출 가이드",
                    "걷기 시작으로 신발 소모가 빨라져요. 3개월마다 사이즈를 체크하세요.")
        default:
            return ("\(ageMonths)개월 예상 지출 가이드",
                    "어린이집 보육료 지원을 꼭 신청하세요. 연령별로 월 28~51만원을 지원받을 수 있어요.")
        }
    }
}

// MARK: - BudgetScreen

/// 가계부 탭 메인 화면.
///
/// 접근성: 색+아이콘+레이블 3중 인코딩, 44pt 탭 영역, VoiceOver accessibilityLabel 전면 적용.
struct BudgetScreen: View {

    // MARK: Environment

    @EnvironmentObject private var store: AppStore

    // MARK: State

    @State private var subsidies: [SubsidyInfo] = []
    @State private var isLoadingSubsidies = true
    @State private var selectedMonth: Date = Date()
    @State private var showAddExpense = false

    // MARK: Computed

    /// selectedChild가 있으면 실제 월령, 없으면 0
    private var childAgeMonths: Int {
        guard let child = store.selectedChild else { return 0 }
        return AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: Date()).months
    }

    /// 실데이터 — store에 영속된 지출 전체
    private var allExpenses: [Expense] { store.expenses }

    private var currentMonthExpenses: [Expense] {
        allExpenses.filter { expense in
            Calendar.current.isDate(expense.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var hasMonthExpenses: Bool { !currentMonthExpenses.isEmpty }

    private var monthlyTotal: Int {
        BudgetSummary.monthlyTotal(allExpenses, in: selectedMonth)
    }

    private var previousMonthTotal: Int {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) else { return 0 }
        return BudgetSummary.monthlyTotal(allExpenses, in: prev)
    }

    /// 전월 대비 증감 % (이전 달 지출 0이면 nil)
    private var monthOverMonthPct: Int? {
        guard previousMonthTotal > 0 else { return nil }
        return Int((Double(monthlyTotal - previousMonthTotal) / Double(previousMonthTotal) * 100).rounded())
    }

    private var categoryBreakdown: [(category: ExpenseCategory, amount: Int)] {
        let dict = BudgetSummary.byCategory(currentMonthExpenses)
        return ExpenseCategory.allCases
            .compactMap { cat -> (ExpenseCategory, Int)? in
                guard let amount = dict[cat], amount > 0 else { return nil }
                return (cat, amount)
            }
            .sorted { $0.1 > $1.1 }
    }

    private var recentExpenses: [Expense] {
        Array(allExpenses.sorted { $0.date > $1.date }.prefix(6))
    }

    private var guide: (title: String, body: String) {
        BudgetMockData.guideMessage(ageMonths: childAgeMonths)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {

                    // 1. 정부지원금 전면 배치
                    subsidySection

                    // 2~3. 지출 대시보드 (이번 달 지출 있을 때만)
                    if hasMonthExpenses {
                        donutDashboard
                        categoryListSection
                    } else {
                        budgetEmptyCard
                    }

                    // 4. 최근 지출 거래 리스트 (전체 지출 있을 때만)
                    if !allExpenses.isEmpty {
                        recentExpensesSection
                    }

                    // 5. 월령별 예상 지출 가이드
                    guideCard

                    // 하단 FAB 여백
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s3)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("가계부")
            .navigationBarTitleDisplayMode(.large)
            .task(id: store.selectedChild?.id) {
                await loadSubsidies()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            addExpenseFAB
        }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet().environmentObject(store)
        }
    }

    // MARK: 지출 없음 빈 상태

    private var budgetEmptyCard: some View {
        BLEmptyState(
            icon: "wonsign.circle",
            title: "이번 달 지출 기록이 없어요",
            message: "오른쪽 아래 + 버튼으로 큰 지출을 추가해보세요.\n마켓 거래·구독은 자동으로 기록돼요."
        )
    }

    // MARK: - Subviews

    // MARK: 1. 정부지원금 섹션

    @ViewBuilder
    private var subsidySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(
                eyebrow: "복지로",
                title: "정부지원금 놓치지 마세요",
                action: nil,
                onAction: nil
            )
            .accessibilityAddTraits(.isHeader)

            if isLoadingSubsidies {
                subsidySkeletonView
            } else if subsidies.isEmpty {
                BLEmptyState(
                    icon: "banknote",
                    title: "해당 월령에 지원금이 없어요",
                    message: "아이 등록 후 월령에 맞는 지원금을\n자동으로 안내해드려요."
                )
            } else {
                ForEach(subsidies) { subsidy in
                    SubsidyCard(info: subsidy)
                }
            }
        }
    }

    private var subsidySkeletonView: some View {
        VStack(spacing: Spacing.s3) {
            ForEach(0..<2, id: \.self) { _ in
                BLCard(padding: Spacing.s4) {
                    HStack(spacing: Spacing.s3) {
                        BLSkeleton(width: 46, height: 46, cornerRadius: Radius.sm)
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            BLSkeleton(height: 14, cornerRadius: Radius.xs)
                                .frame(maxWidth: .infinity)
                            BLSkeleton(height: 12, cornerRadius: Radius.xs)
                                .frame(maxWidth: 200)
                        }
                        .frame(maxWidth: .infinity)
                        BLSkeleton(width: 52, height: 36, cornerRadius: 11)
                    }
                }
            }
        }
    }

    // MARK: 2. 도넛 차트 대시보드

    private var donutDashboard: some View {
        BLCard {
            VStack(spacing: Spacing.s4) {
                HStack(alignment: .center, spacing: Spacing.s4) {
                    // 도넛 차트 (SectorMark)
                    donutChart

                    // 카테고리 범례
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        ForEach(categoryBreakdown, id: \.category) { item in
                            HStack(spacing: Spacing.s2) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(item.category.badgeTone.ink)
                                    .frame(width: 9, height: 9)
                                    .accessibilityHidden(true)

                                Text(item.category.displayName)
                                    .font(AppFont.caption)
                                    .foregroundStyle(AppColors.ink2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(amountShort(item.amount))
                                    .font(.system(size: 12.5, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppColors.ink)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(item.category.accessibilityLabel) \(amountFull(item.amount))")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // 구분선 + 요약 통계
                Divider().background(AppColors.line)

                HStack(spacing: 0) {
                    miniStat(value: amountFull(monthlyTotal), label: "이번 달 총 지출")
                    Divider().frame(height: 32)
                    if let pct = monthOverMonthPct {
                        miniStat(value: "\(pct > 0 ? "+" : "")\(pct)%",
                                 label: "전월 대비",
                                 valueTone: pct <= 0 ? AppColors.primary : AppColors.danger)
                    } else {
                        miniStat(value: "—", label: "전월 대비")
                    }
                    Divider().frame(height: 32)
                    miniStat(value: "\(currentMonthExpenses.count)건", label: "이번 달 기록")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("이번 달 총 지출 \(amountFull(monthlyTotal))"
                    + (monthOverMonthPct.map { ", 전월 대비 \($0)%" } ?? "")
                    + ", \(currentMonthExpenses.count)건 기록")
            }
        }
    }

    @ViewBuilder
    private var donutChart: some View {
        let total = Double(monthlyTotal == 0 ? 1 : monthlyTotal)
        ZStack {
            // SectorMark 도넛
            Chart(categoryBreakdown, id: \.category) { item in
                SectorMark(
                    angle: .value("금액", item.amount),
                    innerRadius: .ratio(0.58),
                    angularInset: 1.5
                )
                .foregroundStyle(item.category.badgeTone.ink)
                .cornerRadius(3)
                .accessibilityLabel("\(item.category.accessibilityLabel) \(Int(Double(item.amount) / total * 100))%")
            }
            .frame(width: 130, height: 130)

            // 중앙 텍스트
            VStack(spacing: 2) {
                Text("이번 달")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
                Text(amountShort(monthlyTotal))
                    .font(.system(size: 17, weight: .heavy).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
            .accessibilityHidden(true)
        }
        .accessibilityLabel("카테고리별 지출 비중 도넛 차트. 이번 달 총 \(amountFull(monthlyTotal))")
    }

    private func miniStat(value: String, label: String, valueTone: Color? = nil) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14.5, weight: .heavy).monospacedDigit())
                .foregroundStyle(valueTone ?? AppColors.ink)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: 3. 카테고리 분해 리스트

    private var categoryListSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: "이번 달", title: "카테고리별 지출")
                .accessibilityAddTraits(.isHeader)

            BLCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(categoryBreakdown.enumerated()), id: \.element.category) { index, item in
                        if index > 0 {
                            Divider()
                                .background(AppColors.line)
                                .padding(.horizontal, Spacing.s4)
                        }

                        HStack(spacing: Spacing.s3) {
                            // 아이콘 뱃지 (색+아이콘 2중)
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(item.category.badgeTone.bg)
                                    .frame(width: 40, height: 40)
                                Image(systemName: item.category.systemIcon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(item.category.badgeTone.ink)
                            }
                            .accessibilityHidden(true)

                            // 레이블 (3중 인코딩 중 텍스트)
                            Text(item.category.displayName)
                                .font(AppFont.subhead)
                                .foregroundStyle(AppColors.ink)

                            Spacer()

                            // 금액 + 비율
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(amountFull(item.amount))
                                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppColors.ink)

                                let pct = monthlyTotal > 0
                                    ? Int(Double(item.amount) / Double(monthlyTotal) * 100)
                                    : 0
                                Text("\(pct)%")
                                    .font(AppFont.micro)
                                    .foregroundStyle(AppColors.ink3)
                            }
                        }
                        .padding(.horizontal, Spacing.s4)
                        .padding(.vertical, Spacing.s3)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.category.accessibilityLabel) \(amountFull(item.amount))")
                    }
                }
            }
        }
    }

    // MARK: 4. 최근 지출 거래 리스트

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: nil, title: "최근 지출")
                .accessibilityAddTraits(.isHeader)

            BLCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(recentExpenses.enumerated()), id: \.element.id) { index, expense in
                        if index > 0 {
                            Divider()
                                .background(AppColors.line)
                                .padding(.horizontal, Spacing.s4)
                        }

                        ExpenseRow(expense: expense)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteExpense(id: expense.id)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            // 자동 수집 안내 문구
            Text("마켓 거래·구독은 자동으로 기록돼요.\n큰 지출만 가끔 직접 추가하면 충분해요.")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("자동 수집 안내: 마켓 거래와 구독은 자동으로 기록되며 큰 지출만 직접 추가하세요.")
        }
    }

    // MARK: 5. 월령별 예상 지출 가이드 카드

    private var guideCard: some View {
        BLCard(flat: true) {
            HStack(spacing: Spacing.s3) {
                // 아이콘 박스
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppColors.surface)
                        .frame(width: 44, height: 44)
                        .blShadow(.chip)
                    // 동전 플립 (§8.4 가계부)
                    CoinFlipView(size: 22, tint: AppColors.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.title)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)

                    Text(guide.body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: 0xEDEBFB), Color(hex: 0xF3E9F6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.title). \(guide.body)")
    }

    // MARK: FAB

    private var addExpenseFAB: some View {
        Button {
            Haptics.light()
            showAddExpense = true
        } label: {
            ZStack {
                Circle()
                    .fill(AppColors.primary)
                    .frame(width: 56, height: 56)
                    .blShadow(.fab)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.onPrimary)
            }
        }
        .padding(.trailing, Spacing.s4)
        .padding(.bottom, 30)
        .accessibilityLabel("지출 추가")
        .accessibilityHint("탭하면 새 지출 항목을 추가할 수 있어요.")
    }

    // MARK: - Helpers

    private func amountShort(_ amount: Int) -> String {
        if amount >= 10_000 {
            let man = Double(amount) / 10_000
            if man == man.rounded() {
                return "\(Int(man))만원"
            } else {
                return String(format: "%.1f만원", man)
            }
        }
        return "\(amount)원"
    }

    private func amountFull(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(formatted)원"
    }

    // MARK: - Async

    private func loadSubsidies() async {
        isLoadingSubsidies = true
        do {
            let result = try await ProviderFactory.subsidy().subsidies(childAgeMonths: childAgeMonths)
            subsidies = result
        } catch {
            subsidies = []
        }
        isLoadingSubsidies = false
    }
}

// MARK: - SubsidyCard

/// 정부지원금 카드.
/// urgent(D-day ≤7) 상태는 골드 배경 + 신청 방법 빠른 액션 노출.
private struct SubsidyCard: View {

    let info: SubsidyInfo

    // D-day 계산 (목업: 첫만남이용권은 D-12, 나머지는 상시)
    private var dDay: Int? {
        switch info.id {
        case "subsidy-001": return 12   // 첫만남이용권 — 곧 마감 (목업)
        default:            return nil  // 상시 신청
        }
    }

    private var isUrgent: Bool {
        guard let d = dDay else { return false }
        return d <= 30
    }

    private var dDayLabel: String? {
        guard let d = dDay else { return nil }
        return d == 0 ? "D-Day" : "D-\(d)"
    }

    var body: some View {
        BLCard(padding: Spacing.s4, flat: !isUrgent) {
            VStack(spacing: 0) {
                // 상단: 아이콘 + 정보 + 신청 버튼
                HStack(spacing: Spacing.s3) {
                    iconBox

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Spacing.s2) {
                            Text(info.name)
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundStyle(AppColors.ink)
                                .lineLimit(1)

                            if let label = dDayLabel {
                                BLBadge(tone: .amber, text: label, systemIcon: "clock.fill", dot: false)
                                    .accessibilityLabel("마감 \(label)")
                            }
                        }

                        HStack(spacing: 4) {
                            Text(amountStr(info.amountKRW))
                                .font(.system(size: 13, weight: .bold).monospacedDigit())
                                .foregroundStyle(isUrgent ? AppColors.gold : AppColors.primary)
                            Text("·")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink3)
                            Text(info.eligibility)
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink2)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    applyButton
                }

                // urgent 카드 — "신청 방법 보기" LiquidButton + 복지로 링크
                if isUrgent {
                    Divider()
                        .background(AppColors.gold.opacity(0.25))
                        .padding(.vertical, Spacing.s3)

                    LiquidButton(fill: AppColors.gold, cornerRadius: Radius.sm) {
                        if let url = info.applyURL {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: Spacing.s2) {
                            Image(systemName: "arrow.up.right.square.fill")
                                .accessibilityHidden(true)
                            Text("신청 방법 보기 — 복지로")
                        }
                    }
                    .accessibilityLabel("\(info.name) 신청 방법 보기. 복지로 페이지로 이동합니다.")
                    .accessibilityHint("복지로 웹사이트가 열립니다.")
                }
            }
        }
        // urgent 카드는 BLCard 위에 골드 그라데이션 오버레이로 색조 강화
        .overlay(alignment: .topLeading) {
            if isUrgent {
                LinearGradient(
                    colors: [Color(hex: 0xFBF1DC).opacity(0.55), Color(hex: 0xF7E7C4).opacity(0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(info.name), \(amountStr(info.amountKRW)). \(info.eligibility)\(dDayLabel.map { ". 마감 \($0)" } ?? "")")
    }

    private var iconBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isUrgent ? AppColors.goldTint : AppColors.primaryTint)
                .frame(width: 46, height: 46)

            Image(systemName: "gift.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(isUrgent ? AppColors.gold : AppColors.primary)
        }
        .accessibilityHidden(true)
    }

    private var applyButton: some View {
        Button {
            if let url = info.applyURL {
                UIApplication.shared.open(url)
            }
        } label: {
            Text("신청")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(AppColors.onPrimary)
                .padding(.horizontal, Spacing.s4)
                .frame(height: 38)
                .background(isUrgent ? AppColors.gold : AppColors.ink, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle())
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("\(info.name) 신청하기")
        .accessibilityHint("복지로 신청 페이지로 이동합니다.")
    }

    private func amountStr(_ amount: Int) -> String {
        if amount >= 10_000 {
            let man = amount / 10_000
            let rem = amount % 10_000
            if rem == 0 {
                return "월 \(man)만원"
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                return "월 \(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")원"
            }
        }
        return "월 \(amount)원"
    }
}

// MARK: - ExpenseRow

/// 개별 지출 행.
/// 자동 수집 항목에는 BLBadge "자동" (blue tone) 표시.
private struct ExpenseRow: View {

    let expense: Expense

    var body: some View {
        HStack(spacing: Spacing.s3) {
            // 카테고리 아이콘 (색+아이콘 2중)
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(expense.category.badgeTone.bg)
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.systemIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(expense.category.badgeTone.ink)
            }
            .accessibilityHidden(true)

            // 레이블 + 자동 뱃지
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.s2) {
                    Text(expense.memo ?? expense.category.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)

                    if expense.autoCollected {
                        BLBadge(tone: .blue, text: "자동", systemIcon: "bolt.fill", dot: false)
                            .accessibilityLabel("자동 수집")
                    }
                }

                HStack(spacing: 4) {
                    // 레이블 텍스트 (3중 인코딩 중 텍스트)
                    Text(expense.category.displayName)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                    Text("·")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                    Text(dateStr(expense.date))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 금액
            Text(amountFull(expense.amount))
                .font(.system(size: 14.5, weight: .heavy).monospacedDigit())
                .foregroundStyle(AppColors.ink)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(expense.category.accessibilityLabel), \(expense.memo ?? ""), \(amountFull(expense.amount))\(expense.autoCollected ? ", 자동 수집" : "")"
        )
    }

    private func amountFull(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(formatted)원"
    }

    private func dateStr(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("가계부 — 라이트") {
    BudgetScreen()
        .environmentObject(SampleData.store())
        .preferredColorScheme(.light)
}

#Preview("가계부 — 아이 없음") {
    BudgetScreen()
        .environmentObject(AppStore())
        .preferredColorScheme(.light)
}
#endif
