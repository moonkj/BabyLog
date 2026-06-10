// Features/Pregnancy/PregnancyRecordScreen.swift
// BabyLog · 임신 모드 기록 탭 메인 스크린
// SwiftUI / Swift Charts / Foundation only
// 팀장 통합 시: AppStore / Pregnancy 모델 주입, showBirthTransition 시트 연결 확인

import SwiftUI
import Charts

// MARK: - 진입점

/// 임신 모드 기록 탭 스크린.
/// 목업 LMP/EDD 기반으로 단독 실행 가능.
/// 팀장 통합 시 `pregnancy: Pregnancy`를 외부에서 주입.
struct PregnancyRecordScreen: View {

    // ── 목업 임신 데이터 ──────────────────────────────────────────────
    private let mockLMP: Date = Calendar.current.date(
        byAdding: .day, value: -168,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    private let mockEDD: Date = Calendar.current.date(
        byAdding: .day, value: 112,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    private let mockNickname: String = "튼튼이"

    // ── 주수·D-day 계산 ─────────────────────────────────────────────
    private var pregnancyWeek: (weeks: Int, days: Int) {
        AgeCalculator.pregnancyWeeks(lmp: mockLMP, edd: mockEDD, asOf: Date()) ?? (24, 0)
    }

    private var dDayToBirth: Int {
        AgeCalculator.dDayToBirth(edd: mockEDD, asOf: Date())
    }

    // ── 상태 ────────────────────────────────────────────────────────
    @State private var selectedSegment: RecordSegment = .fetus
    @State private var movementCount: Int = 3
    @State private var showBirthTransition: Bool = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // ① 태아 히어로 카드
                        heroSection
                            .padding(.horizontal, Spacing.s5)
                            .padding(.top, Spacing.s3)
                            .padding(.bottom, Spacing.s3)

                        // ② 세그먼트 선택
                        segmentBar
                            .padding(.horizontal, Spacing.s5)
                            .padding(.bottom, Spacing.s3)

                        // ③ 세그먼트 본문
                        switch selectedSegment {
                        case .fetus:    fetusGuideSection
                        case .mom:      momRecordSection
                        case .checkup:  prenatalCheckupSection
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .sheet(isPresented: $showBirthTransition) {
            BirthTransitionView {
                // 팀장 통합 시: AppStore.commitBirthTransition 호출 후 모드 전환
                showBirthTransition = false
            }
        }
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("기록")
                .font(AppFont.h2)
                .foregroundStyle(AppColors.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showBirthTransition = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 14, weight: .bold))
                    Text("출산했어요")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(AppColors.pregnancyPink)
                .padding(.horizontal, 13)
                .frame(height: 36)
                .background(Color(hex: 0xFBEAF0), in: Capsule())
            }
            .accessibilityLabel("출산 전환 시작")
            .accessibilityHint("탭하면 아이 프로필로 전환하는 시트가 열립니다")
        }
    }

    // MARK: - ① 태아 히어로 카드

    private var heroSection: some View {
        let week = pregnancyWeek
        let dday = dDayToBirth
        let fruit = FruitData.forWeek(week.weeks)
        let ddayLabel = dday >= 0 ? "D-\(dday)" : "D+\(-dday)"

        return BLCard(padding: 0) {
            ZStack(alignment: .topTrailing) {
                // 배경
                LinearGradient(
                    colors: [Color(hex: 0xFBE6EE), Color(hex: 0xF6D6E4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // 장식 원
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 110, height: 110)
                    .offset(x: 28, y: -28)
                    .accessibilityHidden(true)

                HStack(spacing: Spacing.s4) {
                    // 과일 원형
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 88, height: 88)
                            .blShadow(.card)
                        Text(fruit.emoji)
                            .font(.system(size: 44))
                    }
                    .accessibilityHidden(true)

                    // 텍스트 정보
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        BLBadge(
                            tone: .pink,
                            text: "\(PregnancyData.trimesterLabel(week.weeks)) · \(week.weeks)주 \(week.days)일",
                            dot: true
                        )
                        Text(ddayLabel)
                            .font(AppFont.num(30, weight: .heavy))
                            .foregroundStyle(AppColors.pregnancyPink)
                        Text("\(fruit.name)만 해요 · 출산까지")
                            .font(AppFont.caption)
                            .foregroundStyle(Color(hex: 0xA8537E))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(PregnancyData.trimesterLabel(week.weeks)), \(week.weeks)주 \(week.days)일. "
                        + "출산까지 \(ddayLabel). 태아 크기는 \(fruit.name) 정도예요."
                    )
                }
                .padding(Spacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: - ② 세그먼트 바

    private var segmentBar: some View {
        HStack(spacing: Spacing.s1) {
            ForEach(RecordSegment.allCases) { seg in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedSegment = seg
                    }
                } label: {
                    Text(seg.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(selectedSegment == seg ? Color.white : AppColors.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selectedSegment == seg ? AppColors.ink : AppColors.surface,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .accessibilityLabel(seg.label)
                .accessibilityAddTraits(selectedSegment == seg ? .isSelected : [])
            }
        }
    }

    // MARK: - ③-A 태아 가이드

    private var fetusGuideSection: some View {
        let week = pregnancyWeek
        let guide = PregnancyData.weeklyGuide(week: week.weeks)
        let fruit = FruitData.forWeek(week.weeks)

        return LazyVStack(spacing: Spacing.s3, pinnedViews: []) {
            // 현재 주차 발달 카드
            BLCard(flat: true) {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.pregnancyPink)
                            .accessibilityHidden(true)
                        Text("\(week.weeks)주차 태아 발달")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(AppColors.pregnancyPink)
                    }

                    // 수치 타일
                    HStack(spacing: Spacing.s2) {
                        miniTile(value: guide.length, label: "태아 키")
                        miniTile(value: guide.weight, label: "몸무게")
                        miniTile(value: fruit.name, label: "크기 비유")
                    }

                    Text(guide.note)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("※ 일반 정보이며 의료 상담을 대체하지 않아요")
                        .font(AppFont.micro)
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(week.weeks)주차 태아 발달. 키 \(guide.length), 몸무게 \(guide.weight). \(guide.note)"
            )
            .padding(.horizontal, Spacing.s5)

            // 지난 주차 타임라인
            VStack(alignment: .leading, spacing: Spacing.s3) {
                BLSectionHead(title: "지난 주차")
                    .padding(.horizontal, Spacing.s5)

                ForEach(PregnancyData.pastWeekTimeline(currentWeek: week.weeks), id: \.week) { entry in
                    pastWeekRow(entry: entry)
                        .padding(.horizontal, Spacing.s5)
                }
            }
            .padding(.bottom, Spacing.s7)
        }
    }

    private func miniTile(value: String, label: String) -> some View {
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

    private func pastWeekRow(entry: PregnancyData.WeekEntry) -> some View {
        BLCard(padding: Spacing.s3, flat: true) {
            HStack(spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0xFBEAF0))
                        .frame(width: 44, height: 44)
                    Text(FruitData.forWeek(entry.week).emoji)
                        .font(.system(size: 22))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.week)주 · \(FruitData.forWeek(entry.week).name)만 해요")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(entry.summary)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.week)주차. \(entry.summary)")
    }

    // MARK: - ③-B 산모 기록

    private var momRecordSection: some View {
        LazyVStack(spacing: Spacing.s3, pinnedViews: []) {
            // 태동 카운터
            movementCounterCard
                .padding(.horizontal, Spacing.s5)

            // 체중 추이 차트
            weightChartCard
                .padding(.horizontal, Spacing.s5)

            // 배 사진 D라인 타임라인
            bellyPhotoTimeline
                .padding(.bottom, Spacing.s7)
        }
    }

    // 태동 카운터 ─────────────────────────────────────────────────────
    private var movementCounterCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 헤더
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("오늘의 태동")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text("10회 목표 · 말기 건강 체크")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(movementCount)")
                            .font(AppFont.num(28, weight: .heavy))
                            .foregroundStyle(AppColors.pregnancyPink)
                            .contentTransition(.numericText())
                        Text("/10")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .accessibilityLabel("태동 \(movementCount)회 / 10회 목표")
                }

                // 도트 그리드 (10개)
                HStack(spacing: Spacing.s2) {
                    ForEach(0..<10, id: \.self) { index in
                        MovementDot(filled: index < movementCount, index: index) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if index == movementCount && movementCount < 10 {
                                    movementCount += 1
                                } else if index == movementCount - 1 && movementCount > 0 {
                                    movementCount -= 1
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("태동 도트 그리드. \(movementCount)회 채워짐")

                // 태동 기록 버튼
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if movementCount < 10 { movementCount += 1 }
                    }
                } label: {
                    Label("태동 기록", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.pregnancyPink, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
                .disabled(movementCount >= 10)
                .accessibilityLabel(movementCount >= 10 ? "목표 달성! 10회 완료" : "태동 기록하기. 현재 \(movementCount)회")
                .accessibilityHint(movementCount < 10 ? "탭하면 태동 1회 추가" : "")

                if movementCount >= 10 {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColors.primary)
                            .accessibilityHidden(true)
                        Text("오늘 태동 목표를 달성했어요")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.primary)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("태동 카운터 카드")
    }

    // 체중 추이 차트 ───────────────────────────────────────────────────
    private var weightChartCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("체중 변화")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Text("58.4 kg · +6.4 kg")
                        .font(AppFont.num(13))
                        .foregroundStyle(AppColors.ink2)
                }

                WeightChart()
                    .frame(height: 120)
                    .accessibilityLabel("체중 추이 차트. 임신 전 52kg에서 현재 58.4kg. 권장 증가 범위 내에 있어요.")

                Text("권장 증가 범위 안에서 건강하게 늘고 있어요")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("※ 일반 정보이며 의료 상담을 대체하지 않아요")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // 배 사진 D라인 타임라인 ─────────────────────────────────────────
    private var bellyPhotoTimeline: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(title: "배 사진 (D라인)", action: "추가") {
                // 팀장 통합 시: 사진 추가 액션
            }
            .padding(.horizontal, Spacing.s5)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s3) {
                    // 목업 배 사진 데이터
                    ForEach(PregnancyData.bellyPhotos, id: \.week) { photo in
                        BellyPhotoCell(week: photo.week, seed: photo.seed)
                    }
                    // 성장사진 연속 암시 셀
                    BellyPhotoContinuationCell()
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, 4)
            }
            .accessibilityElement(children: .contain)

            Text("출산 후 아이 성장 사진으로 끊김 없이 이어져요")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
                .padding(.horizontal, Spacing.s5)
        }
        .padding(.bottom, Spacing.s7)
    }

    // MARK: - ③-C 산전 검사

    private var prenatalCheckupSection: some View {
        let week = pregnancyWeek

        return LazyVStack(spacing: Spacing.s2, pinnedViews: []) {
            // 가장 가까운 검사 하이라이트
            urgentCheckupCard(
                title: "임신성 당뇨 검사",
                detail: "24~28주 · 공복 검사 권장",
                dday: "D-3"
            )
            .padding(.horizontal, Spacing.s5)

            // 전체 검사 목록
            ForEach(PregnancyData.checkupSchedule(currentWeek: week.weeks), id: \.id) { checkup in
                checkupRow(checkup: checkup)
                    .padding(.horizontal, Spacing.s5)
            }

            Text("※ 실제 검사 시기는 담당 의료진과 상담하세요")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s7)
        }
    }

    private func urgentCheckupCard(title: String, detail: String, dday: String) -> some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFBE6EE), Color(hex: 0xF6D6E4)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 90, height: 90)
                .offset(x: 20, y: -20)
                .accessibilityHidden(true)

            HStack(spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 48, height: 48)
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.pregnancyPink)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color(hex: 0xA8537E))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(dday)
                    .font(AppFont.num(22, weight: .heavy))
                    .foregroundStyle(AppColors.pregnancyPink)
            }
            .padding(Spacing.s4)
        }
        .blShadow(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail). \(dday)")
        .accessibilityHint("가장 가까운 산전 검사")
    }

    private func checkupRow(checkup: PregnancyData.CheckupItem) -> some View {
        BLCard(padding: Spacing.s4, flat: true) {
            HStack(spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(checkup.isDone ? Color(hex: 0xFBEAF0) : AppColors.surface3)
                        .frame(width: 40, height: 40)
                    Image(systemName: checkup.isDone ? "checkmark.circle.fill" : "calendar")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(checkup.isDone ? AppColors.pregnancyPink : AppColors.ink3)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(checkup.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(checkup.weekRange)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if checkup.isDone {
                    BLBadge(tone: .pink, text: "완료")
                } else {
                    Text(checkup.dueLabel)
                        .font(AppFont.num(13, weight: .bold))
                        .foregroundStyle(checkup.isUrgent ? AppColors.pregnancyPink : AppColors.ink3)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(checkup.name). \(checkup.weekRange). "
            + (checkup.isDone ? "완료됨" : checkup.dueLabel)
        )
    }
}

// MARK: - 태동 도트

private struct MovementDot: View {
    var filled: Bool
    var index: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(filled ? Color(hex: 0xD96BA0) : AppColors.surface3)
                .frame(height: 10)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: filled)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.88))
        .accessibilityHidden(true) // 부모 combine이 대표 레이블 제공
    }
}

// MARK: - 체중 차트 (Swift Charts)

private struct WeightPoint: Identifiable {
    let id = UUID()
    let week: Int
    let weight: Double
}

private struct WeightChart: View {
    private let points: [WeightPoint] = [
        .init(week: 0,  weight: 52.0),
        .init(week: 8,  weight: 53.0),
        .init(week: 14, weight: 55.0),
        .init(week: 18, weight: 56.5),
        .init(week: 24, weight: 58.4),
    ]
    // 권장 범위 밴드 (저체중 BMI 기준: +12.5~18kg)
    private let bandLow:  [(Int, Double)] = [(0, 51.0), (40, 63.0)]
    private let bandHigh: [(Int, Double)] = [(0, 52.0), (40, 64.5)]

    var body: some View {
        Chart {
            // 권장 증가 밴드
            ForEach(0..<bandLow.count, id: \.self) { i in
                AreaMark(
                    x: .value("주수", bandLow[i].0),
                    yStart: .value("하한", bandLow[i].1),
                    yEnd: .value("상한", bandHigh[i].1)
                )
                .foregroundStyle(AppColors.pregnancyPink.opacity(0.10))
                .interpolationMethod(.linear)
            }
            // 실제 체중 선
            ForEach(points) { pt in
                LineMark(
                    x: .value("주수", pt.week),
                    y: .value("체중(kg)", pt.weight)
                )
                .foregroundStyle(AppColors.pregnancyPink)
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("주수", pt.week),
                    y: .value("체중(kg)", pt.weight)
                )
                .foregroundStyle(AppColors.pregnancyPink)
                .symbolSize(20)
            }
        }
        .chartXAxis {
            AxisMarks(values: [0, 10, 20, 30, 40]) { val in
                AxisValueLabel {
                    if let w = val.as(Int.self) {
                        Text("\(w)주")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(AppColors.line)
            }
        }
        .chartYAxis {
            AxisMarks(values: [50, 55, 60, 65]) { val in
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text("\(Int(v))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(AppColors.line)
            }
        }
        .chartYScale(domain: 49...67)
        .chartXScale(domain: -1...41)
    }
}

// MARK: - 배 사진 셀

private struct BellyPhotoCell: View {
    let week: Int
    let seed: Int

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ZStack {
                PhotoPlaceholder(seed: seed, cornerRadius: 14)
                    .frame(width: 104, height: 132)
                // D라인 아이콘 힌트
                Image(systemName: "figure.stand")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .accessibilityHidden(true)
            }
            Text("\(week)주")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink2)
        }
        .accessibilityLabel("배 사진 \(week)주차")
    }
}

private struct BellyPhotoContinuationCell: View {
    var body: some View {
        VStack(spacing: Spacing.s2) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.primaryTint)
                    .frame(width: 104, height: 132)
                VStack(spacing: Spacing.s2) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 26, weight: .light))
                        .foregroundStyle(AppColors.primary)
                    Text("성장 사진\n으로 이어요")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            Text("출산 후")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
        }
        .accessibilityLabel("출산 후 성장 사진으로 이어집니다")
    }
}

// MARK: - 세그먼트 타입

private enum RecordSegment: String, CaseIterable, Identifiable {
    case fetus, mom, checkup
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fetus:   return "태아 가이드"
        case .mom:     return "산모 기록"
        case .checkup: return "산전 검사"
        }
    }
}

// MARK: - 공유 데이터 헬퍼 (내부 정적 데이터)

private enum FruitData {
    struct Info { let emoji: String; let name: String }
    static func forWeek(_ w: Int) -> Info {
        switch w {
        case 0..<5:   return .init(emoji: "🫘", name: "참깨")
        case 5:       return .init(emoji: "🍋", name: "레몬씨")
        case 6:       return .init(emoji: "🫐", name: "블루베리")
        case 7:       return .init(emoji: "🍇", name: "포도")
        case 8:       return .init(emoji: "🫒", name: "올리브")
        case 9:       return .init(emoji: "🍒", name: "체리")
        case 10:      return .init(emoji: "🍓", name: "딸기")
        case 11:      return .init(emoji: "🍋", name: "라임")
        case 12:      return .init(emoji: "🍋", name: "레몬")
        case 13:      return .init(emoji: "🍊", name: "귤")
        case 14:      return .init(emoji: "🍑", name: "복숭아")
        case 15:      return .init(emoji: "🍎", name: "사과")
        case 16:      return .init(emoji: "🥑", name: "아보카도")
        case 17:      return .init(emoji: "🥔", name: "고구마")
        case 18:      return .init(emoji: "🫑", name: "피망")
        case 19:      return .init(emoji: "🥭", name: "망고")
        case 20:      return .init(emoji: "🍌", name: "바나나")
        case 21:      return .init(emoji: "🥕", name: "당근")
        case 22:      return .init(emoji: "🌽", name: "옥수수")
        case 23:      return .init(emoji: "🍆", name: "가지")
        case 24:      return .init(emoji: "🌽", name: "옥수수")
        case 25:      return .init(emoji: "🥦", name: "브로콜리")
        case 26:      return .init(emoji: "🥒", name: "오이")
        case 27:      return .init(emoji: "🍅", name: "토마토")
        case 28:      return .init(emoji: "🍆", name: "가지")
        case 29:      return .init(emoji: "🥬", name: "배추")
        case 30:      return .init(emoji: "🎃", name: "애호박")
        case 31:      return .init(emoji: "🥥", name: "코코넛")
        case 32:      return .init(emoji: "🍈", name: "멜론")
        case 33:      return .init(emoji: "🍍", name: "파인애플")
        case 34:      return .init(emoji: "🍈", name: "멜론")
        case 35:      return .init(emoji: "🍉", name: "수박")
        case 36:      return .init(emoji: "🍉", name: "수박")
        case 37:      return .init(emoji: "🎃", name: "호박")
        case 38:      return .init(emoji: "🎃", name: "호박")
        case 39:      return .init(emoji: "🎃", name: "호박")
        default:      return .init(emoji: "👶", name: "신생아 크기")
        }
    }
}

private enum PregnancyData {

    static func trimesterLabel(_ weeks: Int) -> String {
        switch weeks {
        case 0..<14:  return "초기"
        case 14..<28: return "중기"
        default:      return "말기"
        }
    }

    struct WeekGuide { let length: String; let weight: String; let note: String }
    static func weeklyGuide(week: Int) -> WeekGuide {
        switch week {
        case 0..<12:
            return .init(length: "~6cm", weight: "~14g",
                note: "주요 장기가 형성되는 중요한 시기예요. 심장이 뛰기 시작하고 손가락·발가락이 분리되고 있어요.")
        case 12..<16:
            return .init(length: "~10cm", weight: "~43g",
                note: "얼굴이 더 뚜렷해지고, 손가락 지문이 생기기 시작해요. 배가 조금씩 불러오는 시기예요.")
        case 16..<20:
            return .init(length: "~16cm", weight: "~150g",
                note: "태아가 하품하고, 삼키고, 딸꾹질을 해요. 이 시기부터 태동을 느끼기 시작하는 양육자도 많아요.")
        case 20..<24:
            return .init(length: "~25cm", weight: "~350g",
                note: "눈썹·속눈썹이 자라고, 청각이 발달해 바깥 소리를 들을 수 있어요. 태동이 점점 강해질 거예요.")
        case 24..<28:
            return .init(length: "~30cm", weight: "~660g",
                note: "폐가 발달해 서퍼탄트를 생성하기 시작해요. 눈이 열리고, 빛에 반응할 수 있어요.")
        case 28..<32:
            return .init(length: "~38cm", weight: "~1.1kg",
                note: "뇌가 빠르게 성장하며 주름이 생겨요. 태아가 REM 수면을 취하고, 꿈을 꿀 수도 있어요.")
        case 32..<36:
            return .init(length: "~43cm", weight: "~1.8kg",
                note: "지방이 쌓이며 몸이 통통해지고 있어요. 대부분의 주요 발달이 완성 단계에 있어요.")
        default:
            return .init(length: "~47cm", weight: "~2.7kg",
                note: "완전히 성숙한 태아로 언제든 세상에 나올 준비가 되어 있어요. 함께하는 날이 곧 올 거예요.")
        }
    }

    struct WeekEntry { let week: Int; let summary: String }
    static func pastWeekTimeline(currentWeek: Int) -> [WeekEntry] {
        let summaries: [Int: String] = [
            10: "손가락 지문 형성 중. 크기는 딸기만 해요.",
            12: "얼굴 윤곽이 또렷해지는 시기. 레몬만 해요.",
            14: "태아가 빛에 반응하기 시작해요.",
            16: "성별 초음파 가능 시기. 엄지손가락 빠는 중!",
            18: "청각 발달로 소리에 반응해요.",
            20: "눈을 뜨고 감기 시작. 바나나만 해졌어요.",
            22: "피부에 솜털(태지)이 자라요.",
            24: "폐 발달 시작. 빛에 눈을 찡그려요.",
        ]
        let past = Array(summaries.keys.sorted().filter { $0 < currentWeek }.suffix(4))
        return past.map { w in WeekEntry(week: w, summary: summaries[w] ?? "") }
    }

    struct BellyPhoto { let week: Int; let seed: Int }
    static let bellyPhotos: [BellyPhoto] = [
        .init(week: 12, seed: 3),
        .init(week: 16, seed: 0),
        .init(week: 20, seed: 4),
        .init(week: 24, seed: 1),
    ]

    struct CheckupItem: Identifiable {
        let id = UUID()
        let name: String
        let weekRange: String
        let dueLabel: String
        let isDone: Bool
        let isUrgent: Bool
    }
    static func checkupSchedule(currentWeek: Int) -> [CheckupItem] {
        [
            .init(name: "초기 정밀 초음파",      weekRange: "11~13주",  dueLabel: "완료", isDone: true,  isUrgent: false),
            .init(name: "기형아 1차 검사",        weekRange: "11~13주",  dueLabel: "완료", isDone: true,  isUrgent: false),
            .init(name: "기형아 2차 검사",        weekRange: "16~20주",  dueLabel: "완료", isDone: true,  isUrgent: false),
            .init(name: "정밀 초음파",            weekRange: "20~24주",  dueLabel: "D-14", isDone: false, isUrgent: false),
            .init(name: "임신성 당뇨 검사",       weekRange: "24~28주",  dueLabel: "D-3",  isDone: false, isUrgent: true),
            .init(name: "빈혈·소변 검사",         weekRange: "28주",     dueLabel: "D+11", isDone: false, isUrgent: false),
            .init(name: "GBS 검사",               weekRange: "35~37주",  dueLabel: "예정", isDone: false, isUrgent: false),
        ]
    }
}

// MARK: - 미리보기

#if DEBUG
#Preview("임신 기록 스크린") {
    PregnancyRecordScreen()
}
#endif
