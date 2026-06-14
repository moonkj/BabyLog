// Features/Home/PregnancyHomeView.swift
// BabyLog · 임신 모드 홈 (자기완결형 목업)
// Swift 5 / iOS 17 / SwiftUI + Foundation only
// 팀장 통합 시: MainTabView 혹은 HomeScreen 에서 pregnancyData 주입

import SwiftUI
import Foundation

// MARK: - 진입점

/// 임신 모드 홈 뷰.
/// `AppStore` EnvironmentObject에서 activePregnancy를 읽는다.
/// store가 없거나 activePregnancy가 nil일 경우 목업 폴백으로 동작한다.
struct PregnancyHomeView: View {

    // MARK: AppStore — 실데이터
    @EnvironmentObject private var store: AppStore

    /// 홈 카드(요약·진입점) 탭 시 해당 탭으로 이동. MainTabView가 주입.
    var onNavigate: (AppTab) -> Void = { _ in }

    @State private var showPregReg = false
    @State private var editingPregnancy: Pregnancy? = nil
    @State private var checkupAlert: String? = nil   // 검진 알림 켜기/끄기 안내

    // MARK: 가계부 실데이터
    private var monthTotal: Int { BudgetSummary.monthlyTotal(store.expenses, in: Date()) }
    private var prevMonthTotal: Int {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: Date()) else { return 0 }
        return BudgetSummary.monthlyTotal(store.expenses, in: prev)
    }
    private var monthOverMonthPct: Int? {
        guard prevMonthTotal > 0 else { return nil }
        return Int((Double(monthTotal - prevMonthTotal) / Double(prevMonthTotal) * 100).rounded())
    }
    private var monthCategoryBreakdown: [(category: ExpenseCategory, amount: Int)] {
        let monthEx = store.expenses.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }
        let dict = BudgetSummary.byCategory(monthEx)
        return ExpenseCategory.allCases.compactMap { c -> (ExpenseCategory, Int)? in
            guard let a = dict[c], a > 0 else { return nil }
            return (c, a)
        }.sorted { $0.1 > $1.1 }
    }
    private func wonFull(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return (f.string(from: NSNumber(value: n)) ?? "\(n)")
    }

    // MARK: 목업 폴백 (store 없거나 activePregnancy nil 시)
    private let mockLMP: Date = Calendar.current.date(
        byAdding: .day,
        value: -168,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    private let mockEDD: Date = Calendar.current.date(
        byAdding: .day,
        value: 112,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    // MARK: 실데이터 — activePregnancy
    private var activePregnancy: Pregnancy? {
        store.pregnancies.first(where: { $0.status == .active })
    }

    // 일시중단/상실 상태의 임신 (민감영역 — 등록 권유 대신 따뜻한 안내)
    private var pausedOrLossPregnancy: Pregnancy? {
        store.pregnancies.first(where: { $0.status == .paused || $0.status == .loss })
    }

    // 계산된 주수: activePregnancy 우선, 없으면 목업 폴백
    private var pregnancyWeek: (weeks: Int, days: Int) {
        if let p = activePregnancy {
            return AgeCalculator.pregnancyWeeks(lmp: p.lmpDate, edd: p.eddDate, asOf: Date()) ?? (24, 0)
        }
        return AgeCalculator.pregnancyWeeks(lmp: mockLMP, edd: mockEDD, asOf: Date()) ?? (24, 0)
    }

    // D-day: activePregnancy.eddDate 우선, 없으면 목업 폴백
    private var dDayToBirth: Int {
        let edd = activePregnancy?.eddDate ?? mockEDD
        return AgeCalculator.dDayToBirth(edd: edd, asOf: Date())
    }

    // 태명: activePregnancy.nickname 우선, 없으면 "튼튼이"
    private var fetusNickname: String {
        activePregnancy?.nickname ?? "튼튼이"
    }

    var body: some View {
        ScrollView {
            if activePregnancy == nil {
                // 민감영역: 일시중단/상실 임신이 있으면 등록 권유 대신 따뜻한 안내
                if pausedOrLossPregnancy != nil {
                    pregnancyPausedCard
                } else {
                    pregnancyEmptyState
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // 상단 헤더 (태명 탭 → 수정)
                    headerSection
                        .padding(.horizontal, Spacing.s5)
                        .padding(.bottom, Spacing.s4)
                        .contentShape(Rectangle())
                        .onTapGesture { editingPregnancy = activePregnancy }

                    // 태아 히어로 카드
                    heroCard
                        .padding(.horizontal, Spacing.s5)
                        .padding(.bottom, Spacing.s4)

                    // 본문 모듈 스택
                    VStack(spacing: Spacing.s4) {
                        checkupPriorityCard
                        weeklyDevelopmentCard
                        budgetCard
                    }
                    .padding(.horizontal, Spacing.s5)
                    .padding(.bottom, Spacing.s7)
                }
            }
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showPregReg) {
            AddPregnancySheet().environmentObject(store)
        }
        .sheet(item: $editingPregnancy) { preg in
            AddPregnancySheet(editing: preg).environmentObject(store)
        }
        .alert("검진 알림", isPresented: Binding(get: { checkupAlert != nil }, set: { if !$0 { checkupAlert = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(checkupAlert ?? "") }
    }

    // 임신 미등록 상태 — 등록 CTA
    private var pregnancyEmptyState: some View {
        VStack(spacing: Spacing.s5) {
            ZStack {
                Circle().fill(AppColors.pregnancyPink.opacity(0.12)).frame(width: 96, height: 96)
                Text("🤍").font(.system(size: 44))
            }
            .padding(.top, Spacing.s9)
            VStack(spacing: Spacing.s2) {
                Text("임신을 등록해보세요")
                    .font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                Text("태명과 출산 예정일을 입력하면\n주차별 가이드와 태동·체중 기록이 시작돼요.")
                    .font(AppFont.callout).foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center).lineSpacing(3)
            }
            LiquidButton(fill: AppColors.pregnancyPink, cornerRadius: Radius.md) {
                showPregReg = true
            } label: {
                Text("임신 등록하기").frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, Spacing.s9)
    }

    // 일시중단/상실 상태 — 등록 권유 없이 따뜻한 안내 (민감영역)
    // PregnancyRecordScreen.pausedOrLossCard의 컴팩트 버전. 등록 CTA 없음.
    private var pregnancyPausedCard: some View {
        VStack(spacing: Spacing.s5) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xFBEAF0))
                    .frame(width: 96, height: 96)
                Circle()
                    .stroke(AppColors.pregnancyPink.opacity(0.12), lineWidth: 1)
                    .frame(width: 96, height: 96)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(AppColors.pregnancyPink.opacity(0.7))
            }
            .padding(.top, Spacing.s9)
            .accessibilityHidden(true)

            VStack(spacing: Spacing.s2) {
                Text("언제든 돌아오세요")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                Text("기록은 안전히 보관돼요.\n준비가 될 때 언제든 다시 시작할 수 있어요.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Text("기존에 남긴 기록은 모두 그대로 있어요.")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, Spacing.s9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("언제든 돌아오세요. 기록은 안전히 보관돼요. 준비가 될 때 언제든 다시 시작할 수 있어요.")
    }

    // MARK: - 헤더

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s1) {
            // 인사 (성별중립 카피)
            Text("좋은 하루예요 🌸")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.ink3)

            // 제목 — 태명 반영 (탭하면 수정)
            HStack(spacing: 6) {
                Text("\(fetusNickname)를 기다리며")
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AppColors.pregnancyPink.opacity(0.8))
            }
        }
        .padding(.top, Spacing.s5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(fetusNickname)를 기다리며. 탭하면 임신 정보 수정")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - 태아 히어로 카드

    private var heroCard: some View {
        let week = pregnancyWeek
        let dday = dDayToBirth
        let fruit = fruitForWeek(week.weeks)

        return BLCard(padding: 0) {
            ZStack(alignment: .topTrailing) {
                // 배경 그라데이션 (임신 핑크)
                LinearGradient(
                    colors: [
                        Color(hex: 0xFBE6EE),
                        Color(hex: 0xF6D6E4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 장식 원
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 120, height: 120)
                    .offset(x: 30, y: -30)
                    .accessibilityHidden(true)

                // 본문 행
                HStack(spacing: Spacing.s4) {
                    // 과일 이모지 원형
                    ZStack {
                        Circle()
                            .fill(AppColors.surface)
                            .frame(width: 84, height: 84)
                            .blShadow(.card)
                        Text(fruit.emoji)
                            .font(.system(size: 42))
                    }
                    .accessibilityHidden(true)

                    // 텍스트 정보
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        // 삼분기 + 주수 뱃지
                        BLBadge(
                            tone: .pink,
                            text: "\(trimesterLabel(week.weeks)) · \(week.weeks)주 \(week.days)일",
                            dot: true
                        )

                        // D-day (모노스페이스 숫자)
                        Text(dday >= 0 ? "D-\(dday)" : "D+\(-dday)")
                            .font(AppFont.num(28, weight: .heavy))
                            .foregroundStyle(AppColors.pregnancyPink)

                        // 과일 비유 + 안내
                        Text("\(fruit.name)만 해요 · 출산까지")
                            .font(AppFont.caption)
                            .foregroundStyle(Color(hex: 0xA8537E))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel({
                        let ddayStr = dday >= 0 ? "D-\(dday)" : "D+\(-dday)"
                        return "\(trimesterLabel(week.weeks)), \(week.weeks)주 \(week.days)일. 출산까지 \(ddayStr). 태아 크기는 \(fruit.name) 정도예요."
                    }())
                }
                .padding(Spacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: - 검진 우선순위 카드

    // 현재 주차에 맞는 권장 검사 (실 주차 기반). 만들어낸 D-day는 쓰지 않는다.
    private struct CheckupSuggestion {
        let title: String
        let detail: String
    }

    private func suggestedCheckup(week: Int) -> CheckupSuggestion {
        switch week {
        case 0..<11:
            return CheckupSuggestion(title: "초기 산전 검사", detail: "10주 전후 · 첫 진료 권장")
        case 11..<14:
            return CheckupSuggestion(title: "초기 정밀 초음파·기형아 1차 검사", detail: "11~13주 권장")
        case 14..<20:
            return CheckupSuggestion(title: "기형아 2차 검사", detail: "16~20주 권장")
        case 20..<24:
            return CheckupSuggestion(title: "정밀 초음파", detail: "20~24주 권장")
        case 24..<28:
            return CheckupSuggestion(title: "임신성 당뇨 검사", detail: "24~28주 · 공복 검사 권장")
        case 28..<35:
            return CheckupSuggestion(title: "빈혈·소변 검사", detail: "28주 전후 권장")
        default:
            return CheckupSuggestion(title: "GBS 검사", detail: "35~37주 권장")
        }
    }

    /// 검진 일정 보기 — 기록 탭의 검진 세그먼트로 딥링크.
    private func openCheckupSchedule() {
        store.openPregnancyCheckup = true
        onNavigate(.record)
    }
    /// 검진 알림 켜기/끄기 — 권장 시기 전 로컬 알림 예약/취소.
    private func toggleCheckupReminders() {
        guard let p = activePregnancy else { return }
        if store.checkupRemindersOn {
            CheckupReminderService.cancel(pregnancyId: p.id)
            store.checkupRemindersOn = false
            Haptics.light(); checkupAlert = "검진 알림을 껐어요."
        } else {
            let ref = CheckupReminderService.referenceLMP(lmpDate: p.lmpDate, eddDate: p.eddDate)
            Task { @MainActor in
                let ok = await CheckupReminderService.enable(pregnancyId: p.id, lmp: ref)
                store.checkupRemindersOn = ok
                Haptics.success()
                checkupAlert = ok ? "검진 알림을 켰어요. 권장 시기 며칠 전에 알려드릴게요." : "알림 권한이 꺼져 있어요. 설정에서 허용해 주세요."
            }
        }
    }

    private var checkupPriorityCard: some View {
        let suggestion = suggestedCheckup(week: pregnancyWeek.weeks)
        // 카드 자체는 onTapGesture(검진 일정), 내부 버튼(일정 보기/알림)은 독립 동작 — 중첩 버튼 충돌 방지.
        return ZStack(alignment: .topTrailing) {
                // 배경
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFBE6EE), Color(hex: 0xF6D6E4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 장식
                Circle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 120, height: 120)
                    .offset(x: 30, y: -30)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 0) {
                    // 뱃지
                    BLBadge(tone: .pink, text: "이 시기 권장 검사", systemIcon: "cross.case.fill")

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text(suggestion.title)
                                .font(.system(size: 21, weight: .heavy))
                                .foregroundStyle(AppColors.ink)

                            Text(suggestion.detail)
                                .font(AppFont.callout)
                                .foregroundStyle(Color(hex: 0xA8537E))
                        }

                        Spacer()
                    }
                    .padding(.top, Spacing.s3)

                    // 검진 일정 보기 + 알림 켜기/끄기
                    HStack(spacing: Spacing.s2) {
                        LiquidButton(
                            fill: AppColors.pregnancyPink,
                            cornerRadius: Radius.sm
                        ) {
                            openCheckupSchedule()
                        } label: {
                            Text("검진 일정 보기")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Button {
                            toggleCheckupReminders()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(store.checkupRemindersOn ? AppColors.pregnancyPink : Color.white.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                Image(systemName: store.checkupRemindersOn ? "bell.fill" : "bell")
                                    .font(.system(size: 18))
                                    .foregroundStyle(store.checkupRemindersOn ? .white : AppColors.pregnancyPink)
                            }
                        }
                        .accessibilityLabel(store.checkupRemindersOn ? "검진 알림 끄기" : "검진 알림 켜기")
                        .frame(width: 44, height: 44)
                    }
                    .padding(.top, Spacing.s4)
                }
                .padding(Spacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        .blShadow(.card)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { openCheckupSchedule() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("이 시기 권장 검사: \(suggestion.title), \(suggestion.detail)")
        .accessibilityHint("탭하면 검진 일정으로 이동")
    }

    // MARK: - 주차별 발달 가이드 카드

    private var weeklyDevelopmentCard: some View {
        let week = pregnancyWeek
        let guide = weeklyGuide(week: week.weeks)

        return BLCard(flat: true) {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 섹션 헤더
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.pregnancyPink)
                        .accessibilityHidden(true)
                    Text("\(week.weeks)주차 태아 이야기")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(AppColors.pregnancyPink)
                        .tracking(0.3)
                }

                // 측정 수치 행
                HStack(spacing: Spacing.s3) {
                    devMiniTile(value: guide.length, label: "태아 키")
                    devMiniTile(value: guide.weight, label: "태아 몸무게")
                    devMiniTile(value: fruitForWeek(week.weeks).name, label: "크기 비유")
                }

                // 발달 설명
                Text(guide.note)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                // 의료 면책
                Text("※ 일반 정보이며 의료 상담을 대체하지 않아요")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(week.weeks)주차 태아 발달. " +
            "키 \(guide.length), 몸무게 \(guide.weight). \(guide.note)"
        )
    }

    private func devMiniTile(value: String, label: String) -> some View {
        VStack(spacing: Spacing.s1) {
            Text(value)
                .font(AppFont.num(16, weight: .heavy))
                .foregroundStyle(AppColors.ink)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s3)
        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - 가계부 요약

    private var budgetCard: some View {
        Button {
            onNavigate(.budget)
        } label: {
            BLCard {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text("이번 달 육아비")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink3)
                                .fontWeight(.semibold)

                            // 금액 (실 지출)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(wonFull(monthTotal))
                                    .font(AppFont.num(24, weight: .heavy))
                                    .foregroundStyle(AppColors.ink)
                                Text("원")
                                    .font(AppFont.callout)
                                    .foregroundStyle(AppColors.ink2)
                            }
                        }

                        Spacer()

                        if let pct = monthOverMonthPct {
                            BLBadge(tone: pct <= 0 ? .mint : .coral,
                                    text: "전월 \(pct > 0 ? "+" : "")\(pct)%",
                                    systemIcon: pct <= 0 ? "arrow.down" : "arrow.up")
                        }
                    }

                    if monthTotal > 0 {
                        // 실 카테고리 바
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(Array(monthCategoryBreakdown.prefix(4).enumerated()), id: \.element.category) { _, item in
                                    budgetBarSegment(
                                        color: item.category.badgeTone.ink,
                                        width: geo.size.width * CGFloat(item.amount) / CGFloat(max(1, monthTotal)) - 2
                                    )
                                }
                            }
                        }
                        .frame(height: 8)
                        .clipShape(Capsule())

                        // 실 범례 (상위 3)
                        HStack(spacing: Spacing.s3) {
                            ForEach(Array(monthCategoryBreakdown.prefix(3).enumerated()), id: \.element.category) { _, item in
                                let pct = Int(Double(item.amount) / Double(max(1, monthTotal)) * 100)
                                budgetLegend(color: item.category.badgeTone.ink,
                                             label: "\(item.category.displayName) \(pct)%")
                            }
                        }
                    } else {
                        Text("이번 달 지출 기록이 없어요 · 탭해서 추가")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .accessibilityLabel("이번 달 육아비 \(wonFull(monthTotal))원")
        .accessibilityHint("탭하면 가계부 상세 보기")
    }

    private func budgetBarSegment(color: Color, width: CGFloat) -> some View {
        color
            .frame(width: max(0, width), height: 8)
            .accessibilityHidden(true)
    }

    private func budgetLegend(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.s1) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
        }
        .accessibilityLabel(label)
    }

    // MARK: - 주차별 과일 비유

    private struct FruitInfo {
        let emoji: String
        let name: String
    }

    private func fruitForWeek(_ weeks: Int) -> FruitInfo {
        switch weeks {
        case 0..<5:   return FruitInfo(emoji: "🫘", name: "참깨")
        case 5:       return FruitInfo(emoji: "🍋", name: "레몬씨")
        case 6:       return FruitInfo(emoji: "🫐", name: "블루베리")
        case 7:       return FruitInfo(emoji: "🍇", name: "포도")
        case 8:       return FruitInfo(emoji: "🫒", name: "올리브")
        case 9:       return FruitInfo(emoji: "🍒", name: "체리")
        case 10:      return FruitInfo(emoji: "🍓", name: "딸기")
        case 11:      return FruitInfo(emoji: "🍋", name: "라임")
        case 12:      return FruitInfo(emoji: "🍋", name: "레몬")
        case 13:      return FruitInfo(emoji: "🍊", name: "귤")
        case 14:      return FruitInfo(emoji: "🍑", name: "복숭아")
        case 15:      return FruitInfo(emoji: "🍎", name: "사과")
        case 16:      return FruitInfo(emoji: "🥑", name: "아보카도")
        case 17:      return FruitInfo(emoji: "🥔", name: "고구마")
        case 18:      return FruitInfo(emoji: "🫑", name: "피망")
        case 19:      return FruitInfo(emoji: "🥭", name: "망고")
        case 20:      return FruitInfo(emoji: "🍌", name: "바나나")
        case 21:      return FruitInfo(emoji: "🥕", name: "당근")
        case 22:      return FruitInfo(emoji: "🌽", name: "옥수수")
        case 23:      return FruitInfo(emoji: "🍆", name: "가지")
        case 24:      return FruitInfo(emoji: "🌽", name: "옥수수")
        case 25:      return FruitInfo(emoji: "🥦", name: "브로콜리")
        case 26:      return FruitInfo(emoji: "🥒", name: "오이")
        case 27:      return FruitInfo(emoji: "🍅", name: "토마토")
        case 28:      return FruitInfo(emoji: "🍆", name: "가지")
        case 29:      return FruitInfo(emoji: "🥬", name: "배추")
        case 30:      return FruitInfo(emoji: "🎃", name: "애호박")
        case 31:      return FruitInfo(emoji: "🥥", name: "코코넛")
        case 32:      return FruitInfo(emoji: "🍈", name: "멜론")
        case 33:      return FruitInfo(emoji: "🍍", name: "파인애플")
        case 34:      return FruitInfo(emoji: "🍈", name: "멜론")
        case 35:      return FruitInfo(emoji: "🍉", name: "수박")
        case 36:      return FruitInfo(emoji: "🍉", name: "수박")
        case 37:      return FruitInfo(emoji: "🎃", name: "호박")
        case 38:      return FruitInfo(emoji: "🎃", name: "호박")
        case 39:      return FruitInfo(emoji: "🎃", name: "호박")
        default:      return FruitInfo(emoji: "👶", name: "신생아 크기")
        }
    }

    // MARK: - 삼분기 레이블

    private func trimesterLabel(_ weeks: Int) -> String {
        switch weeks {
        case 0..<14:  return "초기"
        case 14..<28: return "중기"
        default:      return "말기"
        }
    }

    // MARK: - 주차별 발달 가이드 데이터

    private struct WeekGuide {
        let length: String
        let weight: String
        let note: String
    }

    private func weeklyGuide(week: Int) -> WeekGuide {
        switch week {
        case 0..<12:
            return WeekGuide(
                length: "~6cm",
                weight: "~14g",
                note: "주요 장기가 형성되는 중요한 시기예요. 태아의 심장이 뛰기 시작하고, 손가락·발가락이 분리되고 있어요."
            )
        case 12..<16:
            return WeekGuide(
                length: "~10cm",
                weight: "~43g",
                note: "태아의 얼굴이 더 뚜렷해지고, 손가락 지문이 생기기 시작해요. 양육자님의 배가 조금씩 불러오는 시기예요."
            )
        case 16..<20:
            return WeekGuide(
                length: "~16cm",
                weight: "~150g",
                note: "태아가 하품하고, 삼키고, 딸꾹질을 해요. 이 시기부터 태동을 느끼기 시작하는 양육자도 많아요."
            )
        case 20..<24:
            return WeekGuide(
                length: "~25cm",
                weight: "~350g",
                note: "눈썹·속눈썹이 자라고, 청각이 발달해 바깥 소리를 들을 수 있어요. 태동이 점점 강해질 거예요."
            )
        case 24..<28:
            return WeekGuide(
                length: "~30cm",
                weight: "~660g",
                note: "폐가 발달해 서퍼탄트를 생성하기 시작해요. 눈이 열리고, 빛에 반응할 수 있어요. 임신성 당뇨 검사 시기예요."
            )
        case 28..<32:
            return WeekGuide(
                length: "~38cm",
                weight: "~1.1kg",
                note: "뇌가 빠르게 성장하며 주름이 생겨요. 태아가 REM 수면을 취하고, 꿈을 꿀 수도 있어요."
            )
        case 32..<36:
            return WeekGuide(
                length: "~43cm",
                weight: "~1.8kg",
                note: "지방이 쌓이며 몸이 통통해지고 있어요. 대부분의 주요 발달이 완성 단계에 있어요."
            )
        default:
            return WeekGuide(
                length: "~47cm",
                weight: "~2.7kg",
                note: "완전히 성숙한 태아로 언제든 세상에 나올 준비가 되어 있어요. 양육자님과 함께하는 날이 곧 올 거예요."
            )
        }
    }
}

// MARK: - 미리보기

#if DEBUG
#Preview("임신 홈") {
    PregnancyHomeView()
        .environmentObject(SampleData.store())
}
#endif
