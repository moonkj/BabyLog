import SwiftUI
import Charts

// MARK: - RecordScreen

struct RecordScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var segment: RecordSegment = .timeline
    @State private var growthMetric: GrowthMetric = .weight
    @State private var expandAssurance = false
    @State private var showShareCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 상단 큰 타이틀
                screenHeader
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s4)
                    .padding(.bottom, Spacing.s3)

                // 세그먼트 셀렉터
                segmentPicker
                    .padding(.horizontal, Spacing.s5)
                    .padding(.bottom, Spacing.s4)

                // 세그먼트 본문
                Group {
                    if let child = store.selectedChild {
                        switch segment {
                        case .timeline:
                            TimelineSection(child: child)
                        case .chart:
                            GrowthChartSection(child: child, metric: $growthMetric, expandAssurance: $expandAssurance)
                        case .vaccine:
                            VaccineSection()
                        }
                    } else {
                        BLEmptyState(
                            icon: "person.crop.circle.badge.plus",
                            title: "아이를 먼저 등록해주세요",
                            message: "아이 정보를 등록하면\n성장 기록과 추억을 함께 모아볼 수 있어요."
                        )
                    }
                }
                .padding(.horizontal, Spacing.s5)

                Color.clear.frame(height: 96)
            }
        }
        .background(AppColors.canvas)
        .sheet(isPresented: $showShareCard) {
            if let child = store.selectedChild {
                ShareCardView(child: child)
            }
        }
    }

    // MARK: 상단 헤더

    private var screenHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text((store.selectedChild?.name.uppercased() ?? "아이 성장") + " 기록".uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(AppColors.ink3)
                Text(store.selectedChild?.name ?? "기록")
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Button {
                showShareCard = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface, in: Circle())
                    .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
            }
            .buttonStyle(LiquidPressStyle())
            .accessibilityLabel("기록 공유")
        }
    }

    // MARK: 세그먼트 피커

    private var segmentPicker: some View {
        HStack(spacing: Spacing.s1) {
            ForEach(RecordSegment.allCases) { seg in
                BLChip(text: seg.label, on: segment == seg) {
                    withAnimation(.easeOut(duration: 0.18)) { segment = seg }
                }
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(segment == seg ? .isSelected : [])
            }
        }
    }
}

// MARK: - 세그먼트 열거형

private enum RecordSegment: String, CaseIterable, Identifiable {
    case timeline, chart, vaccine
    var id: String { rawValue }
    var label: String {
        switch self {
        case .timeline: return "타임라인"
        case .chart:    return "성장차트"
        case .vaccine:  return "예방접종"
        }
    }
}

private enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight, height
    var id: String { rawValue }
    var label: String { self == .weight ? "몸무게" : "키" }
    var unit: String  { self == .weight ? "kg" : "cm" }
    var icon: String  { self == .weight ? "scalemass.fill" : "ruler.fill" }
}

// MARK: - 타임라인 섹션

private struct TimelineSection: View {
    @EnvironmentObject private var store: AppStore
    let child: Child

    // store에서 실데이터 (date 내림차순)
    private var diaryEntries: [DiaryEntry] {
        store.diaryEntries
            .filter { $0.childId == child.id }
            .sorted { $0.date > $1.date }
    }

    // 날짜별 그룹
    private var groupedItems: [(String, [TimelineItem])] {
        var map: [String: [TimelineItem]] = [:]
        let df = DateFormatter(); df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "yyyy년 M월 d일 EEEE"
        for e in diaryEntries {
            let key = df.string(from: e.date)
            map[key, default: []].append(.diary(e))
        }
        return map.sorted { $0.key > $1.key }
    }

    var body: some View {
        if diaryEntries.isEmpty {
            BLEmptyState(
                icon: "book.closed.fill",
                title: "첫 기록을 남겨볼까요?",
                message: "\(child.name)의 소중한 순간을\n하나씩 담아보세요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                ForEach(groupedItems, id: \.0) { (day, items) in
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        // 날짜 그룹 헤더
                        DateGroupHeader(label: day)
                        // 카드 목록
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            switch item {
                            case .growth(let r):
                                GrowthTimelineCard(record: r)
                            case .diary(let e):
                                DiaryTimelineCard(entry: e)
                            }
                        }
                    }
                }
                // 하단 안내
                Text("\(child.name)의 \(diaryEntries.count)개 순간이 기록되었어요 💛")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s2)
            }
        }
    }
}

private enum TimelineItem {
    case growth(GrowthRecord)
    case diary(DiaryEntry)
}

// 날짜 구분선 헤더
private struct DateGroupHeader: View {
    var label: String
    var body: some View {
        HStack(spacing: Spacing.s2) {
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppColors.ink2)
            Rectangle()
                .fill(AppColors.line)
                .frame(height: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

// 성장 측정 카드
private struct GrowthTimelineCard: View {
    var record: GrowthRecord
    var body: some View {
        BLCard(padding: 14) {
            HStack(spacing: 12) {
                // 색+아이콘 인코딩
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color(hex: 0xE6F1FB))
                        .frame(width: 46, height: 46)
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x3B6FA8))
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("성장 측정")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    HStack(spacing: 4) {
                        if let h = record.heightCm {
                            Text("키 \(String(format: "%.1f", h))cm")
                        }
                        if record.heightCm != nil && record.weightKg != nil {
                            Text("·").foregroundStyle(AppColors.ink3)
                        }
                        if let w = record.weightKg {
                            Text("몸무게 \(String(format: "%.1f", w))kg")
                        }
                    }
                    .font(AppFont.num(13))
                    .foregroundStyle(AppColors.ink2)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(growthAccessibilityLabel)
    }

    private var growthAccessibilityLabel: String {
        var parts = ["성장 측정"]
        if let h = record.heightCm { parts.append("키 \(String(format: "%.1f", h))센티미터") }
        if let w = record.weightKg { parts.append("몸무게 \(String(format: "%.1f", w))킬로그램") }
        return parts.joined(separator: ", ")
    }
}

// 일기/이정표 카드
private struct DiaryTimelineCard: View {
    var entry: DiaryEntry
    private var isMilestone: Bool { entry.milestone != nil }

    var body: some View {
        BLCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 사진 플레이스홀더
                PhotoPlaceholder(seed: entry.recordType == "photo" ? 2 : 3,
                                 cornerRadius: 0)
                    .frame(height: isMilestone ? 180 : 0)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if let milestone = entry.milestone {
                            // 이정표: amber BLBadge(아이콘+레이블)
                            BLBadge(tone: .amber, text: milestone, systemIcon: "star.fill")
                                .padding(12)
                                .accessibilityLabel("이정표: \(milestone)")
                        }
                    }
                    .frame(height: isMilestone ? 180 : 0)
                    .opacity(isMilestone ? 1 : 0)

                // 사진 카드는 항상 placeholder 노출 (photo type)
                if entry.recordType == "photo" && !isMilestone {
                    PhotoPlaceholder(seed: 4, cornerRadius: 0)
                        .frame(height: 160)
                }

                VStack(alignment: .leading, spacing: Spacing.s2) {
                    if let content = entry.content {
                        Text(content)
                            .font(.system(size: 14.5))
                            .foregroundStyle(AppColors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: Spacing.s2) {
                        // 타입 아이콘+레이블 인코딩
                        Label(recordTypeLabel, systemImage: recordTypeIcon)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .padding(14)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var recordTypeLabel: String {
        switch entry.recordType {
        case "milestone": return "이정표"
        case "photo":     return "사진"
        default:          return "메모"
        }
    }
    private var recordTypeIcon: String {
        switch entry.recordType {
        case "milestone": return "star.fill"
        case "photo":     return "camera.fill"
        default:          return "pencil"
        }
    }
}

// MARK: - 성장차트 섹션

private struct GrowthChartSection: View {
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
                Image(systemName: "heart.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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

// MARK: - 예방접종 섹션

private struct VaccineSection: View {
    @State private var completedSet: Set<UUID> = []

    private struct MockVaccine: Identifiable {
        let id: UUID
        let vaccineId: String
        let displayName: String
        let ageLabel: String
        let scheduledDate: Date?
        let completedDate: Date?
        let hospital: String?
    }

    private var vaccines: [MockVaccine] {
        let cal = Calendar.current
        let now = Date()
        func rel(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: now)! }
        return [
            MockVaccine(id: UUID(), vaccineId: "hepb1",   displayName: "HepB 1차",    ageLabel: "출생 시",    scheduledDate: rel(-365), completedDate: rel(-365), hospital: "행복소아과"),
            MockVaccine(id: UUID(), vaccineId: "bcg",     displayName: "BCG",          ageLabel: "생후 4주",   scheduledDate: rel(-340), completedDate: rel(-340), hospital: "행복소아과"),
            MockVaccine(id: UUID(), vaccineId: "dtap1",   displayName: "DTaP 1차",     ageLabel: "생후 2개월", scheduledDate: rel(-300), completedDate: rel(-300), hospital: "행복소아과"),
            MockVaccine(id: UUID(), vaccineId: "dtap2",   displayName: "DTaP 2차",     ageLabel: "생후 4개월", scheduledDate: rel(-240), completedDate: rel(-240), hospital: "행복소아과"),
            MockVaccine(id: UUID(), vaccineId: "dtap3",   displayName: "DTaP 3차",     ageLabel: "생후 6개월", scheduledDate: rel(-180), completedDate: rel(-180), hospital: "행복소아과"),
            MockVaccine(id: UUID(), vaccineId: "dtap4",   displayName: "DTaP 4차",     ageLabel: "생후 15개월",scheduledDate: rel(4),    completedDate: nil,       hospital: nil),
            MockVaccine(id: UUID(), vaccineId: "mmr1",    displayName: "MMR 1차",      ageLabel: "생후 12개월",scheduledDate: rel(30),   completedDate: nil,       hospital: nil),
            MockVaccine(id: UUID(), vaccineId: "varicella",displayName: "수두",         ageLabel: "생후 12개월",scheduledDate: rel(60),   completedDate: nil,       hospital: nil),
        ]
    }

    private func dDay(for vaccine: MockVaccine) -> String? {
        guard let scheduled = vaccine.scheduledDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Date(), to: scheduled).day ?? 0
        if diff > 0 { return "D-\(diff)" }
        if diff == 0 { return "D-Day" }
        return nil
    }

    private func isDone(_ vaccine: MockVaccine) -> Bool {
        completedSet.contains(vaccine.id) || vaccine.completedDate != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            // 임박 접종 배너
            upcomingBanner

            // 전체 리스트
            ForEach(vaccines) { v in
                VaccineRow(
                    vaccineId: v.vaccineId,
                    displayName: v.displayName,
                    ageLabel: v.ageLabel,
                    hospital: v.hospital,
                    done: isDone(v),
                    dDay: dDay(for: v),
                    onToggle: {
                        withAnimation(.easeOut(duration: 0.18)) {
                            if isDone(v) {
                                completedSet.remove(v.id)
                            } else {
                                completedSet.insert(v.id)
                            }
                        }
                    }
                )
            }
        }
    }

    private var upcomingBanner: some View {
        BLCard(padding: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.surface)
                        .frame(width: 46, height: 46)
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("DTaP 4차가 다가와요")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text("질병관리청 스케줄 기준 · D-7 알림 설정됨")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                }
                Spacer()
                Text("D-4")
                    .font(AppFont.num(22, weight: .heavy))
                    .foregroundStyle(AppColors.gold)
                    .accessibilityLabel("4일 후")
            }
        }
        .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("DTaP 4차 접종 4일 후 예정. 알림 설정됨.")
    }
}

private struct VaccineRow: View {
    // VaccineSection.MockVaccine은 private이므로 필요한 필드만 받는다
    let vaccineId: String
    let displayName: String
    let ageLabel: String
    let hospital: String?
    let done: Bool
    let dDay: String?
    let onToggle: () -> Void

    var body: some View {
        BLCard(padding: 14, flat: true) {
            HStack(spacing: 12) {
                // 색+아이콘 3중 인코딩
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(done ? AppColors.primarySoft : AppColors.surface3)
                        .frame(width: 38, height: 38)
                    Image(systemName: done ? "checkmark.circle.fill" : "syringe")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(done ? AppColors.primary : AppColors.ink3)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    HStack(spacing: 4) {
                        Text(ageLabel)
                        if let hosp = hospital, done {
                            Text("·").foregroundStyle(AppColors.ink3)
                            Text(hosp)
                        }
                    }
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                }

                Spacer()

                // 상태 배지
                if done {
                    BLBadge(tone: .mint, text: "완료", systemIcon: "checkmark")
                        .accessibilityLabel("접종 완료")
                } else if let d = dDay {
                    BLBadge(tone: d == "D-Day" ? .coral : .amber,
                            text: d,
                            systemIcon: "calendar")
                    .accessibilityLabel("접종 예정 \(d)")
                } else {
                    BLBadge(tone: .grey, text: "예정", systemIcon: "clock")
                        .accessibilityLabel("접종 예정")
                }

                // 체크 버튼 (44pt 터치타깃)
                Button(action: onToggle) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(done ? AppColors.primary : AppColors.line2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.93))
                .accessibilityLabel(done ? "접종 완료 취소" : "\(displayName) 접종 완료로 표시")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    RecordScreen()
        .environmentObject(SampleData.store())
}
