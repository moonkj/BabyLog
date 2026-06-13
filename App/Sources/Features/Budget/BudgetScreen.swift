// BudgetScreen.swift
// BabyLog — Features/Budget
//
// 가계부 탭 메인 화면.
// 구성(위→아래): 지출 추이(기간 세그먼트 7일/30일/6개월/1년 + 막대 차트) →
//                 카테고리별 지출 → 최근 지출 → 월령 가이드 → 정부지원금(받음 체크).
// 모든 수치는 실데이터(store.expenses)만 사용 — 추측/가공 데이터 없음(정직 원칙).

import SwiftUI
import Charts
import Foundation

// MARK: - Mock Data (월령별 가이드 — 콘텐츠성 안내)

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
    @State private var period: BudgetPeriod = .month
    @State private var showAddExpense = false
    @State private var showAllExpenses = false
    /// '1년' 모드에서 보는 연도(연도별 탐색). 기본 = 올해.
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    // MARK: Computed

    /// selectedChild가 있으면 실제 월령, 없으면 0
    private var childAgeMonths: Int {
        guard let child = store.selectedChild else { return 0 }
        return AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: Date()).months
    }

    /// 실데이터 — store에 영속된 지출 전체
    private var allExpenses: [Expense] { store.expenses }

    /// '1년' 세그먼트에서 특정 연도(1~12월)를 보는 모드.
    private var isYearMode: Bool { period == .year }

    /// 총액·차트 헤더 레이블 ('1년' 모드면 "2026년").
    private var rangeLabel: String {
        isYearMode ? "\(selectedYear)년" : period.rangeLabel
    }

    /// 선택 기간에 속하는 지출
    private var periodExpenses: [Expense] {
        if isYearMode {
            return allExpenses.filter { Calendar.current.component(.year, from: $0.date) == selectedYear }
        }
        return BudgetSummary.inPeriod(allExpenses, period)
    }

    private var hasPeriodExpenses: Bool { !periodExpenses.isEmpty }

    private var periodTotal: Int {
        periodExpenses.reduce(0) { $0 + $1.amount }
    }

    private var previousPeriodTotal: Int {
        if isYearMode {
            // 올해(진행 중)를 보는 경우 — 작년 '전체'가 아니라 작년 같은 진행 기간(1/1~같은 날짜)과 비교.
            // (부분합 vs 전체 비교로 항상 큰 감소처럼 보이던 왜곡 수정. 과거 연도는 전년 전체와 비교 유지.)
            if selectedYear == currentYear {
                return BudgetSummary.yearToDateTotal(allExpenses, year: selectedYear - 1)
            }
            return BudgetSummary.yearTotal(allExpenses, year: selectedYear - 1)
        }
        return BudgetSummary.previousTotal(allExpenses, period)
    }

    /// 전기 대비 증감 % (직전 동일 길이 구간 지출 0이면 nil)
    private var periodOverPeriodPct: Int? {
        guard previousPeriodTotal > 0 else { return nil }
        return Int((Double(periodTotal - previousPeriodTotal) / Double(previousPeriodTotal) * 100).rounded())
    }

    private var trendBuckets: [TrendBucket] {
        if isYearMode { return BudgetSummary.yearTrend(allExpenses, year: selectedYear) }
        return BudgetSummary.trend(allExpenses, period)
    }

    /// 연도별 탐색 범위 — 과거는 데이터가 없어도 둘러볼 수 있게(빈 상태로 표시) 넉넉히 허용,
    /// 미래로는 이동 불가. 하한은 가장 오래된 지출 연도와 (올해-10) 중 더 이른 해.
    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var earliestYear: Int {
        let dataMin = allExpenses.map { Calendar.current.component(.year, from: $0.date) }.min() ?? currentYear
        return min(dataMin, currentYear - 10)
    }
    private var canGoPrevYear: Bool { selectedYear > earliestYear }
    private var canGoNextYear: Bool { selectedYear < currentYear }

    private var categoryBreakdown: [(category: ExpenseCategory, amount: Int)] {
        let dict = BudgetSummary.byCategory(periodExpenses)
        return ExpenseCategory.allCases
            .compactMap { cat -> (ExpenseCategory, Int)? in
                guard let amount = dict[cat], amount > 0 else { return nil }
                return (cat, amount)
            }
            .sorted { $0.1 > $1.1 }
    }

    /// 전체 지출(최신순). 최근 지출 리스트는 기본 5개만, 더보기 시 전체.
    private var sortedExpenses: [Expense] {
        allExpenses.sorted { $0.date > $1.date }
    }

    private static let recentCollapsedCount = 5

    private var displayedRecentExpenses: [Expense] {
        showAllExpenses ? sortedExpenses : Array(sortedExpenses.prefix(Self.recentCollapsedCount))
    }

    private var guide: (title: String, body: String) {
        BudgetMockData.guideMessage(ageMonths: childAgeMonths)
    }

    /// 받지 않은 지원금 먼저, 받은(완료) 지원금은 아래로.
    private var sortedSubsidies: [SubsidyInfo] {
        subsidies.sorted { a, b in
            let ca = store.isSubsidyClaimed(id: a.id), cb = store.isSubsidyClaimed(id: b.id)
            if ca != cb { return !ca }   // 미수령 먼저
            return false
        }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    BLScreenHeader(title: "가계부", eyebrow: "지출 추이와 받을 지원금")
                    VStack(alignment: .leading, spacing: Spacing.s6) {

                        // 1. 지출 추이 (기간 세그먼트 + 막대 차트 + 총액)
                        trendSection

                        // 2~3. 카테고리별 지출 (선택 기간에 지출 있을 때만)
                        if hasPeriodExpenses {
                            categoryTreemapSection
                        }

                        // 4. 최근 지출 거래 리스트 (전체 지출 있을 때만)
                        if !allExpenses.isEmpty {
                            recentExpensesSection
                        }

                        // 5. 월령별 예상 지출 가이드
                        guideCard

                        // 6. 정부지원금 — 가계부이므로 지출 아래에 배치
                        subsidySection

                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s2)
                }
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationBarHidden(true)
            .task(id: store.selectedChild?.id) {
                await loadSubsidies()
            }
        }
        .appFAB { Haptics.light(); showAddExpense = true }
        .sheet(isPresented: $showAddExpense) {
            AddExpenseSheet().environmentObject(store)
        }
    }

    // MARK: 1. 지출 추이 (세그먼트 + 차트)

    private var trendSection: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                periodSegment

                // '1년' 모드: 연도별 탐색 스텝퍼
                if isYearMode { yearStepper }

                // 총액 + 전기 대비
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(rangeLabel) 총 지출")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                        Text(amountFull(periodTotal))
                            .font(AppFont.num(26, weight: .heavy))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .contentTransition(.numericText())
                        if let pct = periodOverPeriodPct {
                            deltaBadge(pct)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(rangeLabel) 총 지출 \(amountFull(periodTotal))"
                    + (periodOverPeriodPct.map { ", 직전 대비 \($0)퍼센트" } ?? ""))

                // 막대 차트 (실데이터)
                if periodTotal > 0 {
                    trendChart
                } else {
                    trendEmpty
                }
            }
        }
    }

    private var periodSegment: some View {
        HStack(spacing: 4) {
            ForEach(BudgetPeriod.allCases) { p in
                let selected = p == period
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.2)) { period = p }
                } label: {
                    Text(p.label)
                        .font(.system(size: 13, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? AppColors.ink : AppColors.ink3)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            selected ? AppColors.surface : Color.clear,
                            in: Capsule()
                        )
                        .shadow(color: selected ? Color(hex: 0x282118).opacity(0.08) : .clear,
                                radius: 2, x: 0, y: 1)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.95))
                .accessibilityLabel("\(p.label) 보기")
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(AppColors.surface2, in: Capsule())
    }

    /// 연도별 탐색 — ◀ 2026년 ▶ (미래·데이터 없는 과거로는 이동 제한)
    private var yearStepper: some View {
        HStack(spacing: Spacing.s2) {
            Button {
                guard canGoPrevYear else { return }
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) { selectedYear -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canGoPrevYear ? AppColors.ink2 : AppColors.ink3.opacity(0.3))
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LiquidPressStyle(scale: 0.9))
            .disabled(!canGoPrevYear)
            .accessibilityLabel("이전 연도 보기")

            Text("\(String(selectedYear))년")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .accessibilityLabel("선택한 연도 \(selectedYear)년")
                .accessibilityAddTraits(.isHeader)

            Button {
                guard canGoNextYear else { return }
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) { selectedYear += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(canGoNextYear ? AppColors.ink2 : AppColors.ink3.opacity(0.3))
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LiquidPressStyle(scale: 0.9))
            .disabled(!canGoNextYear)
            .accessibilityLabel("다음 연도 보기")
            .accessibilityHint(canGoNextYear ? "" : "올해 이후로는 이동할 수 없어요")
        }
        .padding(.horizontal, Spacing.s2)
        .frame(height: 40)
        .background(AppColors.surface2, in: Capsule())
    }

    @ViewBuilder
    private var trendChart: some View {
        let unit: Calendar.Component = period.isDaily ? .day : .month
        Chart(trendBuckets) { bucket in
            BarMark(
                x: .value("기간", bucket.date, unit: unit),
                y: .value("지출", bucket.amount)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .cornerRadius(3)
        }
        .frame(height: 150)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(AppColors.line.opacity(0.6))
                AxisValueLabel {
                    if let amount = value.as(Int.self) {
                        Text(axisAmount(amount))
                            .font(.system(size: 10))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
        }
        .chartXAxis {
            switch period {
            case .week:
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .font(.system(size: 10))
                }
            case .month:
                AxisMarks(values: .stride(by: .day, count: 6)) { _ in
                    AxisValueLabel(format: .dateTime.day())
                        .font(.system(size: 10))
                }
            case .sixMonths:
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits))
                        .font(.system(size: 10))
                }
            case .year:
                AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits))
                        .font(.system(size: 10))
                }
            }
        }
        .accessibilityLabel("\(rangeLabel) 지출 추이 막대 차트. 총 \(amountFull(periodTotal))")
    }

    private var trendEmpty: some View {
        VStack(spacing: Spacing.s2) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(AppColors.ink3.opacity(0.6))
            Text("\(rangeLabel) 지출 기록이 없어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text("오른쪽 아래 + 버튼으로 지출을 추가해 보세요.")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3.opacity(0.85))
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rangeLabel) 지출 기록이 없어요. 오른쪽 아래 더하기 버튼으로 지출을 추가하세요.")
    }

    /// 전기 대비 증감 배지 (색+부호+레이블)
    private func deltaBadge(_ pct: Int) -> some View {
        let down = pct <= 0
        return HStack(spacing: 2) {
            Image(systemName: down ? "arrow.down.right" : "arrow.up.right")
                .font(.system(size: 9, weight: .heavy))
            Text("\(abs(pct))%")
                .font(AppFont.num(11.5, weight: .heavy))
        }
        .foregroundStyle(down ? AppColors.primary : AppColors.danger)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background((down ? AppColors.primaryTint : AppColors.dangerTint), in: Capsule())
        .accessibilityLabel("직전 \(period.label) 대비 \(down ? "감소" : "증가") \(abs(pct))퍼센트")
    }

    // MARK: 2. 도넛 차트 대시보드 (카테고리 비중)

    // MARK: 카테고리 트리맵 (도넛+리스트 통합 — 면적 ∝ 지출 비중)

    private var categoryTreemapSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: rangeLabel, title: "카테고리별 지출")
                .accessibilityAddTraits(.isHeader)
            BLCard {
                categoryTreemap.frame(height: 176)
            }
        }
    }

    /// slice-and-dice 3열 트리맵 — 1열=최대 카테고리, 2열=다음 2개, 3열=나머지. 면적이 금액 비중에 비례.
    private var categoryTreemap: some View {
        let cats = categoryBreakdown
        let cols = treemapColumns(cats)
        let colSums = cols.map { col in col.reduce(0) { $0 + $1.amount } }
        let grand = max(1, colSums.reduce(0, +))
        let topCat = cats.first?.category
        return GeometryReader { geo in
            let gap: CGFloat = 6
            let availW = geo.size.width - gap * CGFloat(max(0, cols.count - 1))
            HStack(spacing: gap) {
                ForEach(cols.indices, id: \.self) { ci in
                    treemapColumn(cols[ci],
                                  width: availW * CGFloat(colSums[ci]) / CGFloat(grand),
                                  height: geo.size.height,
                                  topCat: topCat)
                }
            }
        }
    }

    private func treemapColumns(_ cats: [(category: ExpenseCategory, amount: Int)])
        -> [[(category: ExpenseCategory, amount: Int)]] {
        guard !cats.isEmpty else { return [] }
        var cols: [[(category: ExpenseCategory, amount: Int)]] = [[cats[0]]]
        let mid = Array(cats.dropFirst().prefix(2))
        if !mid.isEmpty { cols.append(mid) }
        let small = Array(cats.dropFirst(3))
        if !small.isEmpty { cols.append(small) }
        return cols
    }

    @ViewBuilder
    private func treemapColumn(_ col: [(category: ExpenseCategory, amount: Int)],
                               width: CGFloat, height: CGFloat, topCat: ExpenseCategory?) -> some View {
        let sum = max(1, col.reduce(0) { $0 + $1.amount })
        let gap: CGFloat = 6
        let availH = height - gap * CGFloat(max(0, col.count - 1))
        VStack(spacing: gap) {
            ForEach(col, id: \.category) { item in
                treemapCell(item, isBig: item.category == topCat)
                    .frame(height: max(28, availH * CGFloat(item.amount) / CGFloat(sum)))
            }
        }
        .frame(width: max(0, width))
    }

    private func treemapCell(_ item: (category: ExpenseCategory, amount: Int), isBig: Bool) -> some View {
        let pct = periodTotal > 0 ? Int((Double(item.amount) / Double(periodTotal) * 100).rounded()) : 0
        return ZStack(alignment: .topTrailing) {
            // 큰 셀에만 카테고리 아이콘(은은하게)
            if isBig {
                Image(systemName: item.category.systemIcon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(item.category.badgeTone.ink.opacity(0.45))
                    .padding(11)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.displayName)
                    .font(.system(size: isBig ? 13.5 : 12, weight: .bold))
                    .foregroundStyle(item.category.badgeTone.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text(amountShort(item.amount))
                    .font(AppFont.num(isBig ? 16 : 13.5, weight: .heavy))
                    .foregroundStyle(item.category.badgeTone.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(isBig ? 13 : 10)
        }
        .background(item.category.badgeTone.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.category.accessibilityLabel) \(amountFull(item.amount)), \(pct)퍼센트")
    }

    // MARK: 4. 최근 지출 거래 리스트

    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: nil, title: "최근 지출")
                .accessibilityAddTraits(.isHeader)

            BLCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(displayedRecentExpenses.enumerated()), id: \.element.id) { index, expense in
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

            // 더보기/접기 — 5개 초과일 때만
            if sortedExpenses.count > Self.recentCollapsedCount {
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.22)) { showAllExpenses.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Text(showAllExpenses
                             ? "접기"
                             : "더보기 \(sortedExpenses.count - Self.recentCollapsedCount)건")
                            .font(.system(size: 13.5, weight: .bold))
                        Image(systemName: showAllExpenses ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(AppColors.ink2)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColors.surface, in: Capsule())
                    .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
                .padding(.top, Spacing.s1)
                .accessibilityLabel(showAllExpenses
                                    ? "최근 지출 접기"
                                    : "지출 \(sortedExpenses.count - Self.recentCollapsedCount)건 더보기")
                .accessibilityHint(showAllExpenses
                                   ? "최근 5건만 표시합니다"
                                   : "전체 지출 \(sortedExpenses.count)건을 모두 표시합니다")
            }
        }
    }

    // MARK: 5. 월령별 예상 지출 가이드 카드

    private var guideCard: some View {
        BLCard(flat: true) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.surface)
                        .frame(width: 44, height: 44)
                        .blShadow(.chip)
                    CoinFlipView(size: 22, tint: AppColors.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(guide.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(guide.body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: 6. 정부지원금 섹션 (지출 아래)

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

            if store.selectedChild == nil {
                BLEmptyState(
                    icon: "banknote",
                    title: "아이 등록 후 안내해드려요",
                    message: "아이를 등록하면 월령에 맞는 지원금을\n자동으로 안내해드려요."
                )
            } else if isLoadingSubsidies {
                subsidySkeletonView
            } else if subsidies.isEmpty {
                BLEmptyState(
                    icon: "banknote",
                    title: "해당 월령에 지원금이 없어요",
                    message: "아이 등록 후 월령에 맞는 지원금을\n자동으로 안내해드려요."
                )
            } else {
                ForEach(sortedSubsidies) { subsidy in
                    SubsidyCard(
                        info: subsidy,
                        claimed: store.isSubsidyClaimed(id: subsidy.id),
                        onToggleClaim: {
                            Haptics.light()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.toggleSubsidyClaimed(id: subsidy.id)
                            }
                        }
                    )
                }

                Text("받았다고 체크하면 완료로 표시돼요. 금액·조건은 복지로에서 최종 확인하세요.")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s1)
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
                        BLSkeleton(width: 52, height: 36, cornerRadius: Radius.sm)
                    }
                }
            }
        }
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

    /// 차트 Y축용 짧은 금액(만 단위). 0은 빈 문자열.
    private func axisAmount(_ amount: Int) -> String {
        if amount == 0 { return "0" }
        if amount >= 10_000 {
            let man = Double(amount) / 10_000
            return man == man.rounded() ? "\(Int(man))만" : String(format: "%.0f만", man)
        }
        // 1만 미만 — 1000 미만은 원 단위 그대로("0천" 방지), 1000~9999는 소수 한 자리 '천'(.0이면 정수).
        if amount < 1000 { return "\(amount)" }
        let chon = Double(amount) / 1000
        return chon == chon.rounded() ? "\(Int(chon))천" : String(format: "%.1f천", chon)
    }

    private func amountFull(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        return "\(formatted)원"
    }

    // MARK: - Async

    private func loadSubsidies() async {
        guard store.selectedChild != nil else {
            subsidies = []
            isLoadingSubsidies = false
            return
        }
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

/// 정부지원금 카드. 받음 체크 시 완료 상태로 전환되고, 신청 버튼은 복지로로 연결한다.
/// NOTE: 실 마감일(D-day) 데이터가 없으므로 가짜 카운트다운/긴급 연출은 표시하지 않는다.
private struct SubsidyCard: View {

    let info: SubsidyInfo
    let claimed: Bool
    let onToggleClaim: () -> Void

    var body: some View {
        BLCard(padding: Spacing.s4, flat: true) {
            HStack(spacing: Spacing.s3) {
                // 받음 체크 토글 (44pt 터치 타깃)
                Button(action: onToggleClaim) {
                    Image(systemName: claimed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(claimed ? AppColors.primary : AppColors.ink3.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.9))
                .accessibilityLabel(claimed ? "\(info.name) 받음 해제" : "\(info.name) 받았다고 체크")
                .accessibilityAddTraits(claimed ? [.isSelected, .isButton] : .isButton)

                iconBox

                VStack(alignment: .leading, spacing: 4) {
                    Text(info.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(claimed ? AppColors.ink3 : AppColors.ink)
                        .strikethrough(claimed, color: AppColors.ink3)
                        .lineLimit(1)

                    HStack(spacing: Spacing.s2) {
                        Text(amountStr(info.amountKRW))
                            .font(AppFont.num(14, weight: .heavy))
                            .foregroundStyle(claimed ? AppColors.ink3 : AppColors.primary)
                            .lineLimit(1)
                        Text(info.eligibility)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailingAction
            }
        }
        .opacity(claimed ? 0.7 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(info.name), \(amountStr(info.amountKRW)). \(info.eligibility)"
            + (claimed ? ", 받음 완료" : ""))
    }

    @ViewBuilder
    private var trailingAction: some View {
        if claimed {
            HStack(spacing: 3) {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .heavy))
                Text("받음").font(.system(size: 12.5, weight: .heavy))
            }
            .foregroundStyle(AppColors.primary)
            .padding(.horizontal, Spacing.s3)
            .frame(height: 38)
            .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .accessibilityHidden(true)
        } else {
            Button {
                openApplyInfo()
            } label: {
                Text("신청")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(AppColors.onPrimary)
                    .padding(.horizontal, Spacing.s4)
                    .frame(height: 38)
                    .background(AppColors.ink, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }
            .buttonStyle(LiquidPressStyle())
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("\(info.name) 신청하기")
            .accessibilityHint("복지로 신청 페이지로 이동합니다.")
        }
    }

    // 복지로 신청 페이지(있으면 해당 지원금 안내, 없으면 메인)로 이동.
    private func openApplyInfo() {
        let url = info.applyURL ?? URL(string: "https://www.bokjiro.go.kr")
        if let url { UIApplication.shared.open(url) }
    }

    private var iconBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(claimed ? AppColors.surface2 : AppColors.primaryTint)
                .frame(width: 46, height: 46)

            Image(systemName: claimed ? "checkmark.seal.fill" : "gift.fill")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(claimed ? AppColors.ink3 : AppColors.primary)
        }
        .accessibilityHidden(true)
    }

    private func amountStr(_ amount: Int) -> String {
        // 일시금(첫만남이용권 등)은 "총 N만원", 매월 지급은 "월 N만원" — '월 200만원' 오표기 수정.
        let prefix = info.isLumpSum ? "총" : "월"
        if amount >= 10_000 {
            let man = amount / 10_000
            let rem = amount % 10_000
            if rem == 0 {
                return "\(prefix) \(man)만원"
            } else {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                return "\(prefix) \(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)")원"
            }
        }
        return "\(prefix) \(amount)원"
    }
}

// MARK: - ExpenseRow

/// 개별 지출 행. 자동 수집 항목에는 BLBadge "자동" (blue tone) 표시.
private struct ExpenseRow: View {

    let expense: Expense

    var body: some View {
        HStack(spacing: Spacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(expense.category.badgeTone.bg)
                    .frame(width: 40, height: 40)
                Image(systemName: expense.category.systemIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(expense.category.badgeTone.ink)
            }
            .accessibilityHidden(true)

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

            Text(amountFull(expense.amount))
                .font(AppFont.num(14.5, weight: .heavy))
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
        let label = formatter.string(from: date)
        return Calendar.current.isDateInToday(date) ? "오늘 · \(label)" : label
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
