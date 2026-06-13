// Features/Record/RecordGrowthChartSection.swift
// BabyLog · 성장 기록 탭 — 성장차트 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI
import Charts

// MARK: - 성장차트 섹션

struct GrowthChartSection: View {
    @EnvironmentObject private var store: AppStore
    let child: Child
    @Binding var metric: GrowthMetric
    @Binding var expandAssurance: Bool

    // 성장 링 호흡 모션 (REDUCE-MOTION aware)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringBreathe = false

    // store에서 실데이터 (date 오름차순)
    private var records: [GrowthRecord] {
        store.growthRecords
            .filter { $0.childId == child.id }
            .sorted { $0.date < $1.date }
    }

    // WHO 백분위 참조 데이터 (성별 구분, 월령별)
    private struct WHOBand: Identifiable {
        var id: Int { month }
        let month: Int
        let p15: Double
        let p50: Double
        let p85: Double
    }

    // 성별을 알 수 없을 때(미지정/미입력) 밴드 오버레이를 권위 있게 그리지 않도록 판단.
    // 남아/여아 표준이 서로 다르므로 잘못된 "정상범위"를 보여주는 것보다 생략이 안전·정직하다.
    private var hasKnownGender: Bool {
        switch child.gender {
        case .boy, .girl: return true
        default:          return false
        }
    }

    private var weightBandsBoy: [WHOBand] {
        // WHO 남아 몸무게 백분위 근사 (0–16개월)
        [
            WHOBand(month: 0,  p15: 2.9,  p50: 3.3,  p85: 3.9),
            WHOBand(month: 2,  p15: 4.9,  p50: 5.6,  p85: 6.4),
            WHOBand(month: 4,  p15: 6.2,  p50: 7.0,  p85: 7.9),
            WHOBand(month: 6,  p15: 7.1,  p50: 8.0,  p85: 9.0),
            WHOBand(month: 8,  p15: 7.7,  p50: 8.8,  p85: 9.9),
            WHOBand(month: 10, p15: 8.2,  p50: 9.4,  p85: 10.5),
            WHOBand(month: 12, p15: 8.6,  p50: 9.8,  p85: 11.0),
            WHOBand(month: 14, p15: 9.0,  p50: 10.3, p85: 11.5),
            WHOBand(month: 16, p15: 9.4,  p50: 10.8, p85: 12.0),
            // 16~60개월 확장(WHO 남아 몸무게 근사)
            WHOBand(month: 18, p15: 9.9,  p50: 11.3, p85: 12.7),
            WHOBand(month: 24, p15: 10.8, p50: 12.2, p85: 13.6),
            WHOBand(month: 30, p15: 11.8, p50: 13.3, p85: 14.9),
            WHOBand(month: 36, p15: 12.7, p50: 14.3, p85: 16.2),
            WHOBand(month: 42, p15: 13.5, p50: 15.3, p85: 17.3),
            WHOBand(month: 48, p15: 14.3, p50: 16.3, p85: 18.5),
            WHOBand(month: 54, p15: 15.2, p50: 17.3, p85: 19.7),
            WHOBand(month: 60, p15: 16.0, p50: 18.3, p85: 20.9),
        ]
    }

    private var weightBandsGirl: [WHOBand] {
        // WHO 여아 몸무게 백분위 근사 (0–16개월)
        [
            WHOBand(month: 0,  p15: 2.8,  p50: 3.2,  p85: 3.7),
            WHOBand(month: 2,  p15: 4.5,  p50: 5.1,  p85: 5.9),
            WHOBand(month: 4,  p15: 5.7,  p50: 6.4,  p85: 7.3),
            WHOBand(month: 6,  p15: 6.5,  p50: 7.3,  p85: 8.3),
            WHOBand(month: 8,  p15: 7.0,  p50: 7.9,  p85: 9.0),
            WHOBand(month: 10, p15: 7.5,  p50: 8.5,  p85: 9.6),
            WHOBand(month: 12, p15: 7.9,  p50: 8.9,  p85: 10.1),
            WHOBand(month: 14, p15: 8.2,  p50: 9.4,  p85: 10.6),
            WHOBand(month: 16, p15: 8.6,  p50: 9.8,  p85: 11.1),
            // 16~60개월 확장(WHO 여아 몸무게 근사)
            WHOBand(month: 18, p15: 8.8,  p50: 10.2, p85: 11.6),
            WHOBand(month: 24, p15: 10.0, p50: 11.5, p85: 13.0),
            WHOBand(month: 30, p15: 11.0, p50: 12.7, p85: 14.4),
            WHOBand(month: 36, p15: 12.0, p50: 13.9, p85: 15.8),
            WHOBand(month: 42, p15: 12.9, p50: 15.0, p85: 17.1),
            WHOBand(month: 48, p15: 13.8, p50: 16.1, p85: 18.5),
            WHOBand(month: 54, p15: 14.6, p50: 17.2, p85: 19.8),
            WHOBand(month: 60, p15: 15.4, p50: 18.2, p85: 21.0),
        ]
    }

    private var heightBandsBoy: [WHOBand] {
        // WHO 남아 키 백분위 근사 (0–16개월)
        [
            WHOBand(month: 0,  p15: 48.2, p50: 49.9, p85: 51.8),
            WHOBand(month: 2,  p15: 55.8, p50: 58.0, p85: 60.1),
            WHOBand(month: 4,  p15: 61.5, p50: 63.9, p85: 66.2),
            WHOBand(month: 6,  p15: 65.1, p50: 67.6, p85: 70.2),
            WHOBand(month: 8,  p15: 68.0, p50: 70.6, p85: 73.3),
            WHOBand(month: 10, p15: 70.5, p50: 73.3, p85: 76.0),
            WHOBand(month: 12, p15: 72.8, p50: 75.7, p85: 78.6),
            WHOBand(month: 14, p15: 75.0, p50: 78.0, p85: 81.1),
            WHOBand(month: 16, p15: 77.1, p50: 80.2, p85: 83.3),
            // 16~60개월 확장(WHO 남아 키 근사) — 큰 아이도 밴드 비교 가능하게
            WHOBand(month: 18, p15: 79.6, p50: 82.3, p85: 85.0),
            WHOBand(month: 24, p15: 84.1, p50: 87.1, p85: 90.0),
            WHOBand(month: 30, p15: 88.7, p50: 91.9, p85: 95.1),
            WHOBand(month: 36, p15: 92.7, p50: 96.1, p85: 99.5),
            WHOBand(month: 42, p15: 96.3, p50: 99.9, p85: 103.5),
            WHOBand(month: 48, p15: 99.5, p50: 103.3, p85: 107.1),
            WHOBand(month: 54, p15: 102.7, p50: 106.7, p85: 110.7),
            WHOBand(month: 60, p15: 105.8, p50: 110.0, p85: 114.2),
        ]
    }

    private var heightBandsGirl: [WHOBand] {
        // WHO 여아 키 백분위 근사 (0–16개월)
        [
            WHOBand(month: 0,  p15: 47.5, p50: 49.1, p85: 50.9),
            WHOBand(month: 2,  p15: 54.4, p50: 57.1, p85: 59.1),
            WHOBand(month: 4,  p15: 59.8, p50: 62.1, p85: 64.5),
            WHOBand(month: 6,  p15: 63.2, p50: 65.7, p85: 68.2),
            WHOBand(month: 8,  p15: 66.0, p50: 68.7, p85: 71.5),
            WHOBand(month: 10, p15: 68.5, p50: 71.5, p85: 74.5),
            WHOBand(month: 12, p15: 70.8, p50: 74.0, p85: 77.1),
            WHOBand(month: 14, p15: 73.0, p50: 76.4, p85: 79.7),
            WHOBand(month: 16, p15: 75.0, p50: 78.6, p85: 82.1),
            // 16~60개월 확장(WHO 여아 키 근사)
            WHOBand(month: 18, p15: 78.0, p50: 80.7, p85: 83.4),
            WHOBand(month: 24, p15: 82.5, p50: 85.7, p85: 88.9),
            WHOBand(month: 30, p15: 87.4, p50: 90.7, p85: 94.0),
            WHOBand(month: 36, p15: 91.5, p50: 95.1, p85: 98.7),
            WHOBand(month: 42, p15: 95.2, p50: 99.0, p85: 102.8),
            WHOBand(month: 48, p15: 98.7, p50: 102.7, p85: 106.7),
            WHOBand(month: 54, p15: 102.0, p50: 106.2, p85: 110.4),
            WHOBand(month: 60, p15: 105.0, p50: 109.4, p85: 113.8),
        ]
    }

    private var weightBands: [WHOBand] {
        child.gender == .girl ? weightBandsGirl : weightBandsBoy
    }

    private var heightBands: [WHOBand] {
        child.gender == .girl ? heightBandsGirl : heightBandsBoy
    }

    private var currentBands: [WHOBand] { metric == .weight ? weightBands : heightBands }

    // 차트용 포인트 (월령 Int, 측정값 Double)
    // id는 GrowthRecord의 UUID — 같은 달에 2회 이상 측정해도 ForEach id가 충돌하지 않는다.
    // (month를 id로 쓰면 동월 중복 측정 시 일부 포인트가 누락/오작동)
    private struct ChartPoint: Identifiable {
        let id: UUID
        let month: Int
        let value: Double
    }

    private var chartPoints: [ChartPoint] {
        records.compactMap { r -> ChartPoint? in
            let months = AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: r.date).months
            let val = metric == .weight ? r.weightKg : r.heightCm
            guard let v = val else { return nil }
            return ChartPoint(id: r.id, month: months, value: v)
        }
    }

    private var lastRecord: GrowthRecord? { records.last }

    /// 선택된 지표(키/몸무게) 값을 꺼내는 헬퍼
    private func value(of record: GrowthRecord) -> Double? {
        metric == .weight ? record.weightKg : record.heightCm
    }

    /// 해당 지표를 실제로 담고 있는 가장 최근 기록(뒤에서부터 탐색).
    /// 최신 기록에 몸무게만 있고 키가 없어도, 키가 있는 직전 기록을 찾아 "–"로 비지 않게 한다.
    private var latestRecordWithValue: GrowthRecord? {
        records.last(where: { value(of: $0) != nil })
    }

    private var currentValue: Double? {
        latestRecordWithValue.flatMap { value(of: $0) }
    }

    /// 직전 측정 대비 변화량 — 해당 지표를 담은 최근 두 기록을 뒤에서부터 찾아 비교.
    /// (시간 간격은 보장하지 않으므로 "직전 측정 대비"로 정직하게 라벨링)
    private var recentDelta: Double? {
        let valued = records.compactMap { r -> Double? in value(of: r) }
        guard valued.count >= 2 else { return nil }
        return valued[valued.count - 1] - valued[valued.count - 2]
    }

    // 성별 확인 시에만 권위 있게 밴드를 그린다(성별 미상이면 잘못된 표준 회피)
    private var showsBand: Bool { hasKnownGender }

    // MARK: 안심 헤드라인 (등수 비교 금지 · 의료조언 금지)

    /// 최신 측정값이 WHO 밴드 어디에 위치하는지 (성별 확인된 경우만 판정)
    private enum BandPosition { case withinRange, belowRange, aboveRange }

    /// 밴드 데이터의 마지막 월령(현재 0–16개월). 이 범위를 크게 벗어나면 판정하지 않는다.
    private let bandToleranceMonths = 1

    /// 월령에 해당하는 밴드를 선형 보간해 p15/p85 경계를 구하고, 측정값의 위치를 판정한다.
    /// 밴드 데이터 마지막 월령(+허용오차)을 넘어서면 nil(판정 보류) — 오래된 아이를
    /// 마지막 밴드에 억지로 끼워 "범위 밖"으로 잘못 단정하지 않는다.
    private func bandPosition(value: Double?, month: Int, bands: [WHOBand]) -> BandPosition? {
        guard let v = value else { return nil }
        let sorted = bands.sorted { $0.month < $1.month }
        guard let first = sorted.first, let lastB = sorted.last else { return nil }
        // 밴드 마지막 월령을 (허용오차 이상) 넘어선 경우 판정 보류
        guard month <= lastB.month + bandToleranceMonths else { return nil }
        let bound: (p15: Double, p85: Double)
        if month <= first.month {
            bound = (first.p15, first.p85)
        } else if month >= lastB.month {
            bound = (lastB.p15, lastB.p85)
        } else {
            var found: (Double, Double)? = nil
            for i in 0..<(sorted.count - 1) {
                let lo = sorted[i], hi = sorted[i + 1]
                if month >= lo.month && month <= hi.month {
                    let span = Double(hi.month - lo.month)
                    let t = span > 0 ? Double(month - lo.month) / span : 0
                    found = (lo.p15 + (hi.p15 - lo.p15) * t, lo.p85 + (hi.p85 - lo.p85) * t)
                    break
                }
            }
            guard let f = found else { return nil }
            bound = (f.0, f.1)
        }
        if v < bound.p15 { return .belowRange }
        if v > bound.p85 { return .aboveRange }
        return .withinRange
    }

    /// 최신 키·몸무게 측정 각각이 밴드 안/밖 어디인지. 성별 미상이면 nil(판정 보류).
    private var latestBandPosition: BandPosition? {
        guard hasKnownGender, let last = lastRecord else { return nil }
        let month = AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: last.date).months

        let wPos = bandPosition(value: last.weightKg, month: month, bands: weightBands)
        let hPos = bandPosition(value: last.heightCm, month: month, bands: heightBands)

        // 둘 중 하나라도 범위 밖이면 '범위 밖'으로 안내(부드럽게), 둘 다 범위 안이면 '범위 안'
        let positions = [wPos, hPos].compactMap { $0 }
        guard !positions.isEmpty else { return nil }
        if positions.contains(where: { $0 != .withinRange }) {
            // 위/아래 구분은 안심 헤드라인에선 불필요 — 범위 밖 한 가지로 통일
            return positions.first(where: { $0 == .belowRange }) ?? .aboveRange
        }
        return .withinRange
    }

    /// 실제 측정 위치를 반영한 헤드라인 (false reassurance 금지)
    private var assuranceHeadline: String {
        switch latestBandPosition {
        case .withinRange:
            return "또래 범위 안에서 잘 자라고 있어요"
        case .belowRange, .aboveRange:
            // 알람 톤 금지 · 의료조언 금지 · 거짓 안심 금지
            return "\(child.name)만의 속도로 자라고 있어요"
        case nil:
            // 성별 미상 등으로 판정 불가 — 중립 캡션(거짓 안심 회피)
            return "\(child.name)의 성장 추이를 기록하고 있어요"
        }
    }

    /// 헤드라인 아래 보조 문구 (위치에 맞춰 톤 조정)
    private var assuranceSubline: String {
        switch latestBandPosition {
        case .withinRange:
            return "정밀 수치는 아래 차트에서 확인할 수 있어요"
        case .belowRange, .aboveRange:
            return "성장 속도는 아이마다 달라요 — 정기 검진에서 함께 확인해보세요"
        case nil:
            return "정밀 수치는 아래 차트에서 확인할 수 있어요"
        }
    }

    var body: some View {
        if records.isEmpty {
            BLEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: "성장 기록을 추가해볼까요?",
                message: "\(child.name)의 키와 몸무게를 기록하면\nWHO 성장곡선과 함께 확인할 수 있어요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                // 정성적 안심 메시지 카드 (백분위 숫자 강조 금지)
                assuranceCard

                // 키/몸무게 토글 — 앱 표준 세그먼트로 통일
                BLSegmented(segments: GrowthMetric.allCases.map { ($0, $0.label) }, selection: $metric)

                // 1개 데이터 단일 포인트 안내
                if records.count == 1 {
                    BLCard(padding: Spacing.s4, flat: true) {
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppColors.primary)
                                .accessibilityHidden(true)
                            Text("측정이 2회 이상 쌓이면 추이 그래프가 그려져요")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink2)
                        }
                    }
                }

                // 차트 카드
                BLCard(padding: Spacing.s4) {
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        HStack {
                            Label(metric.label, systemImage: metric.icon)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text("월령(개월)")
                                .font(AppFont.micro)
                                .foregroundStyle(AppColors.ink3)
                        }

                        // Swift Charts — LineMark + WHO AreaMark 밴드
                        growthChart
                            .frame(height: 200)
                            .accessibilityLabel(chartAccessibilityDescription)

                        // 범례
                        chartLegend

                        Divider().background(AppColors.line)

                        // 요약 스탯 행
                        statsRow
                    }
                }
            }
        }
    }

    // MARK: 안심 메시지 카드

    private var assuranceCard: some View {
        BLCard(padding: Spacing.s4, flat: true) {
            HStack(alignment: .top, spacing: 12) {
                // 성장 링 (§8.4 기능 진입) — 차오름 + 잔잔한 호흡(상시)
                ZStack {
                    GrowthRingView(size: 44, lineWidth: 3, color: AppColors.primary)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .frame(width: 44, height: 44)
                .scaleEffect(ringBreathe ? 1.06 : 1.0)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        ringBreathe = true
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(assuranceHeadline)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(assuranceSubline)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)

                    if expandAssurance {
                        Text("성장 곡선은 참고 자료예요. 아이마다 성장 속도가 달라요. 정기 검진에서 소아과 선생님과 함께 확인해보세요.")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { expandAssurance.toggle() }
                    } label: {
                        Label(expandAssurance ? "접기" : "더 보기",
                              systemImage: expandAssurance ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.97))
                    .padding(.top, 2)
                    .frame(minHeight: 44, alignment: .top)
                    .accessibilityLabel(expandAssurance ? "안심 메시지 접기" : "안심 메시지 펼치기")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.primarySoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Swift Charts 본체

    /// X축 상한(개월) — 아이 데이터 범위에 맞춰 동적. 어린 아기는 ~18개월로 확대,
    /// 큰 아이는 측정 월령+6(최대 60)까지. 밴드(0~60)가 항상 60까지라 축이 눌리는 것 방지.
    private var chartMaxMonth: Int {
        let maxData = chartPoints.map(\.month).max() ?? 0
        return min(60, max(18, maxData + 6))
    }

    /// X축 눈금 — 상한에 맞춰 간격 조정.
    private var chartXTicks: [Int] {
        let m = chartMaxMonth
        if m <= 18 { return [0, 4, 8, 12, 16] }
        if m <= 36 { return [0, 6, 12, 18, 24, 30, 36].filter { $0 <= m } }
        return [0, 12, 24, 36, 48, 60].filter { $0 <= m }
    }

    private var growthChart: some View {
        let xMax = chartMaxMonth
        let bands = currentBands.filter { $0.month <= xMax }   // 보이는 범위만(축 눌림 방지)
        let points = chartPoints
        let lastPt = chartPoints.last
        let metricLabel = metric.label
        let metricUnit = metric.unit
        let drawBand = showsBand
        return Chart {
            // WHO 밴드 (p15–p85) — AreaMark · 성별 확인된 경우만 표시
            // (성별 미상이면 남/여 표준이 달라 잘못된 "정상범위"를 권위 있게 그리지 않음)
            if drawBand {
                ForEach(bands) { band in
                    AreaMark(
                        x: .value("월령", band.month),
                        yStart: .value("p15", band.p15),
                        yEnd: .value("p85", band.p85)
                    )
                    .foregroundStyle(AppColors.primary.opacity(0.10))
                    .interpolationMethod(.catmullRom)
                    .accessibilityHidden(true)
                }

                // WHO p50 중앙선 — LineMark (점선). 측정선(primary 실선)과 색약 구분을 위해
                // 같은 녹색 농담이 아닌 '다른 hue(중성 회색)'로 분리(색+패턴 이중 인코딩).
                ForEach(bands) { band in
                    LineMark(
                        x: .value("월령", band.month),
                        y: .value("p50", band.p50)
                    )
                    .foregroundStyle(AppColors.ink3)
                    .lineStyle(StrokeStyle(lineWidth: 1.3, dash: [4, 4]))
                    .interpolationMethod(.catmullRom)
                    .accessibilityHidden(true)
                }
            }

            // 실제 측정 데이터 — LineMark
            ForEach(points) { pt in
                LineMark(
                    x: .value("월령", pt.month),
                    y: .value(metricLabel, pt.value)
                )
                .foregroundStyle(AppColors.primary)
                .lineStyle(StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
                .symbol {
                    Circle()
                        .fill(AppColors.surface)
                        .frame(width: 9, height: 9)
                        .overlay { Circle().stroke(AppColors.primary, lineWidth: 2) }
                }
                .symbolSize(CGSize(width: 9, height: 9))
            }

            // 마지막 포인트 강조
            if let last = lastPt {
                PointMark(
                    x: .value("월령", last.month),
                    y: .value(metricLabel, last.value)
                )
                .foregroundStyle(AppColors.primary)
                .symbolSize(CGSize(width: 13, height: 13))
                .symbol {
                    Circle()
                        .fill(AppColors.primary)
                        .frame(width: 13, height: 13)
                        .overlay { Circle().stroke(AppColors.surface, lineWidth: 2.5) }
                }
                .annotation(position: .top, spacing: 4) {
                    Text("\(String(format: "%.1f", last.value))\(metricUnit)")
                        .font(AppFont.num(11, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                }
            }
        }
        .chartXScale(domain: 0...Double(xMax))   // 데이터 범위에 맞춰 X축 고정(밴드 60까지여도 안 눌림)
        .chartXAxis {
            AxisMarks(values: chartXTicks) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(AppColors.line)
                AxisValueLabel {
                    if let m = val.as(Int.self) {
                        Text("\(m)m")
                            .font(AppFont.num(10))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(AppColors.line)
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(AppFont.num(10))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(AppColors.canvas.opacity(0.5))
        }
    }

    // MARK: 범례

    private var chartLegend: some View {
        HStack(spacing: Spacing.s3) {
            legendItem(color: AppColors.primary, style: .solid, label: child.name)
            if showsBand {
                let genderLabel = child.gender == .girl ? "여아" : "남아"
                legendItem(color: AppColors.ink3, style: .dashed, label: "WHO \(genderLabel) 중앙(p50)")
                legendItem(color: AppColors.primary.opacity(0.10), style: .area, label: "WHO \(genderLabel) 정상범위")
            } else {
                // 성별 미상 — 권위 있는 정상범위 대신 안내
                Text("성별 입력 시 WHO 성장곡선이 함께 표시돼요")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
            }
        }
    }

    private enum LegendStyle { case solid, dashed, area }

    private func legendItem(color: Color, style: LegendStyle, label: String) -> some View {
        HStack(spacing: 5) {
            Group {
                switch style {
                case .solid:
                    Capsule().fill(color).frame(width: 16, height: 3)
                case .dashed:
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule().fill(color).frame(width: 4, height: 3)
                        }
                    }
                case .area:
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color).frame(width: 16, height: 8)
                }
            }
            .accessibilityHidden(true)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
        }
    }

    // MARK: 요약 스탯

    private var statsRow: some View {
        HStack {
            statCell(value: currentValue.map { String(format: "%.1f\(metric.unit)", $0) } ?? "–",
                     label: "현재 \(metric.label)")
            Divider().frame(height: 32).background(AppColors.line2)
            statCell(value: recentDelta.map { (d: Double) in
                let sign = d >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.1f", d))\(metric.unit)"
            } ?? "–", label: "직전 측정 대비")
            Divider().frame(height: 32).background(AppColors.line2)
            statCell(value: "\(records.count)회", label: "총 측정 횟수")
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.num(17, weight: .heavy))
                .foregroundStyle(AppColors.ink)
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var chartAccessibilityDescription: String {
        let genderLabel = child.gender == .girl ? "여아" : "남아"
        return "성장 차트. \(metric.label) 추이. "
        + (chartPoints.last.map { "현재 \($0.value)\(metric.unit)" } ?? "")
        + (showsBand ? ". WHO \(genderLabel) 정상 범위 밴드 표시됨." : ". 성별 미입력으로 WHO 정상 범위는 표시되지 않음.")
    }
}
