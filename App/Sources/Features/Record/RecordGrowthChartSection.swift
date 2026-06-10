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

    // store에서 실데이터 (date 오름차순)
    private var records: [GrowthRecord] {
        store.growthRecords
            .filter { $0.childId == child.id }
            .sorted { $0.date < $1.date }
    }

    // WHO 백분위 참조 데이터 (남아 기준 근사값, 월령별)
    private struct WHOBand: Identifiable {
        var id: Int { month }
        let month: Int
        let p15: Double
        let p50: Double
        let p85: Double
    }

    private var weightBands: [WHOBand] {
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
        ]
    }

    private var heightBands: [WHOBand] {
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
        ]
    }

    private var currentBands: [WHOBand] { metric == .weight ? weightBands : heightBands }

    // 차트용 포인트 (월령 Int, 측정값 Double)
    private struct ChartPoint: Identifiable {
        var id: Int { month }
        let month: Int
        let value: Double
    }

    private var chartPoints: [ChartPoint] {
        records.compactMap { r -> ChartPoint? in
            let months = AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: r.date).months
            let val = metric == .weight ? r.weightKg : r.heightCm
            guard let v = val else { return nil }
            return ChartPoint(month: months, value: v)
        }
    }

    private var lastRecord: GrowthRecord? { records.last }
    private var currentValue: Double? {
        metric == .weight ? lastRecord?.weightKg : lastRecord?.heightCm
    }
    private var recentDelta: Double? {
        guard records.count >= 2 else { return nil }
        let prev = metric == .weight ? records[records.count - 2].weightKg : records[records.count - 2].heightCm
        let curr = currentValue
        guard let p = prev, let c = curr else { return nil }
        return c - p
    }

    var body: some View {
        if records.isEmpty {
            BLEmptyState(
                icon: "chart.line.uptrend.xyaxis",
                title: "성장 기록을 추가해볼까요?",
                message: "\(child.name)의 키와 몸무게를 기록하면\nWHO 성장곡선과 함께 확인할 수 있어요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 정성적 안심 메시지 카드 (백분위 숫자 강조 금지)
                assuranceCard

                // 키/몸무게 토글
                HStack(spacing: Spacing.s2) {
                    ForEach(GrowthMetric.allCases) { m in
                        BLChip(text: m.label, on: metric == m) {
                            guard metric != m else { return }
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.18)) { metric = m }
                        }
                        .accessibilityAddTraits(metric == m ? .isSelected : [])
                    }
                    Spacer()
                }

                // 1개 데이터 단일 포인트 안내
                if records.count == 1 {
                    BLCard(padding: 14, flat: true) {
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(AppColors.primary)
                                .accessibilityHidden(true)
                            Text("측정이 2회 이상 쌓이면 추이 그래프가 그려져요")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink2)
                        }
                    }
                }

                // 차트 카드
                BLCard(padding: 16) {
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
        BLCard(padding: 16, flat: true) {
            HStack(alignment: .top, spacing: 12) {
                // 성장 링 (§8.4 기능 진입) — 차오름 + 호흡
                ZStack {
                    GrowthRingView(size: 44, lineWidth: 3, color: AppColors.primary)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("또래와 비슷하게 잘 크고 있어요")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text("걱정 마세요 — 정밀 수치는 아래 차트에서 확인할 수 있어요")
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

    private var growthChart: some View {
        let bands = currentBands
        let points = chartPoints
        let lastPt = chartPoints.last
        let metricLabel = metric.label
        let metricUnit = metric.unit
        return Chart {
            // WHO 밴드 (p15–p85) — AreaMark
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

            // WHO p50 중앙선 — LineMark (점선)
            ForEach(bands) { band in
                LineMark(
                    x: .value("월령", band.month),
                    y: .value("p50", band.p50)
                )
                .foregroundStyle(AppColors.primary.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1.3, dash: [4, 4]))
                .interpolationMethod(.catmullRom)
                .accessibilityHidden(true)
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
        .chartXAxis {
            AxisMarks(values: [0, 4, 8, 12, 16]) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(AppColors.line)
                AxisValueLabel {
                    if let m = val.as(Int.self) {
                        Text("\(m)m")
                            .font(AppFont.num(9))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(AppColors.line)
                AxisValueLabel {
                    if let v = val.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(AppFont.num(9))
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
        HStack(spacing: Spacing.s4) {
            legendItem(color: AppColors.primary, style: .solid, label: child.name)
            legendItem(color: AppColors.primary.opacity(0.45), style: .dashed, label: "WHO 중앙(p50)")
            legendItem(color: AppColors.primary.opacity(0.10), style: .area, label: "WHO 정상범위")
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
            Divider().frame(height: 36).background(AppColors.line)
            statCell(value: recentDelta.map { (d: Double) in
                let sign = d >= 0 ? "+" : ""
                return "\(sign)\(String(format: "%.1f", d))\(metric.unit)"
            } ?? "–", label: "최근 2개월")
            Divider().frame(height: 36).background(AppColors.line)
            statCell(value: "\(records.count)회", label: "총 측정 횟수")
        }
        .frame(maxWidth: .infinity)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.num(18, weight: .heavy))
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
        "성장 차트. \(metric.label) 추이. "
        + (chartPoints.last.map { "현재 \($0.value)\(metric.unit)" } ?? "")
        + ". WHO 정상 범위 밴드 표시됨."
    }
}
