// Features/Pregnancy/PregnancyRecordSections.swift
// BabyLog · 임신 모드 기록 탭 — 세그먼트 본문 섹션 뷰
// (PregnancyRecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)
// SwiftUI / Foundation only

import SwiftUI
import Charts
import UIKit

// MARK: - ③-A 태아 가이드

struct PregnancyFetusGuideSection: View {
    let week: (weeks: Int, days: Int)

    var body: some View {
        let guide = PregnancyData.weeklyGuide(week: week.weeks)
        let fruit = FruitData.forWeek(week.weeks)

        return LazyVStack(spacing: Spacing.s3, pinnedViews: []) {
            // 현재 주차 발달 카드
            BLCard(flat: true) {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .accessibilityHidden(true)
                        Text("\(week.weeks)주차 태아 발달")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.pregnancyPink)
                    .padding(.horizontal, 10)
                    .frame(height: 25)
                    .background(Color(hex: 0xFBEAF0), in: Capsule())

                    // 수치 타일
                    HStack(spacing: Spacing.s3) {
                        miniTile(value: guide.length, label: "태아 키")
                        miniTile(value: guide.weight, label: "몸무게")
                        miniTile(value: fruit.name, label: "크기 비유")
                    }

                    Text(guide.note)
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().overlay(AppColors.line)

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
                BLSectionHead(eyebrow: "타임라인", title: "지난 주차")
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s2)

                ForEach(PregnancyData.pastWeekTimeline(currentWeek: week.weeks), id: \.week) { entry in
                    pastWeekRow(entry: entry)
                        .padding(.horizontal, Spacing.s5)
                }
            }
            .padding(.bottom, Spacing.s4)
        }
    }

    private func miniTile(value: String, label: String) -> some View {
        VStack(spacing: Spacing.s1) {
            Text(value)
                .font(AppFont.num(16, weight: .heavy))
                .foregroundStyle(AppColors.ink)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s4)
        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func pastWeekRow(entry: PregnancyData.WeekEntry) -> some View {
        BLCard(padding: Spacing.s3, flat: true) {
            HStack(spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(Color(hex: 0xFBEAF0))
                        .frame(width: 46, height: 46)
                    Text(FruitData.forWeek(entry.week).emoji)
                        .font(.system(size: 22))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entry.week)주 · \(FruitData.forWeek(entry.week).name)만 해요")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(entry.summary)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.week)주차. \(entry.summary)")
    }
}

// MARK: - ③-B 산모 기록

struct PregnancyMomRecordSection: View {
    @EnvironmentObject private var store: AppStore
    @State private var showWeightEntry = false
    @State private var weightText = ""
    @State private var bellyPicked: UIImage? = nil

    private var pregnancyId: UUID? { store.activePregnancy?.id }

    /// 현재 임신 주차 (LMP 우선, 없으면 EDD 역산)
    private var currentWeek: Int {
        let cal = Calendar.current
        if let lmp = store.activePregnancy?.lmpDate {
            let days = cal.dateComponents([.day], from: lmp, to: Date()).day ?? 0
            return max(0, min(42, days / 7))
        }
        if let edd = store.activePregnancy?.eddDate {
            let daysToEdd = cal.dateComponents([.day], from: Date(), to: edd).day ?? 0
            return max(0, min(42, 40 - daysToEdd / 7))
        }
        return 0
    }

    /// 배 사진 (store 영속)
    private var bellyLogs: [PregnancyLog] {
        pregnancyId.map { store.bellyPhotos(pregnancyId: $0) } ?? []
    }

    /// 오늘 태동 횟수 (store 영속)
    private var movementCount: Int {
        pregnancyId.map { store.todayMovementCount(pregnancyId: $0) } ?? 0
    }
    private func setMovement(_ v: Int) {
        guard let pid = pregnancyId else { return }
        store.setMovementCount(pregnancyId: pid, count: max(0, min(10, v)))
    }

    /// 체중 기록 (store 영속, 날짜 오름차순)
    private var weights: [PregnancyLog] {
        pregnancyId.map { store.pregnancyWeights(pregnancyId: $0) } ?? []
    }

    var body: some View {
        LazyVStack(spacing: Spacing.s3, pinnedViews: []) {
            // 태동 카운터
            movementCounterCard
                .padding(.horizontal, Spacing.s5)

            // 체중 추이 차트
            weightChartCard
                .padding(.horizontal, Spacing.s5)

            // 배 사진 D라인 타임라인
            bellyPhotoTimeline
                .padding(.bottom, Spacing.s4)
        }
        .alert("체중 기록", isPresented: $showWeightEntry) {
            TextField("예: 58.4", text: $weightText)
                .keyboardType(.decimalPad)
            Button("저장") {
                if let pid = pregnancyId, let kg = Double(weightText), kg > 0 {
                    store.addPregnancyWeight(pregnancyId: pid, kg: kg)
                    Haptics.success()
                }
                weightText = ""
            }
            Button("취소", role: .cancel) { weightText = "" }
        } message: {
            Text("오늘 체중을 kg 단위로 입력하세요.")
        }
    }

    // 태동 카운터 ─────────────────────────────────────────────────────
    private var movementCounterCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 헤더
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            HeartbeatView(size: 13)
                            Text("오늘의 태동")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppColors.ink)
                        }
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
                                    setMovement(movementCount + 1)
                                } else if index == movementCount - 1 && movementCount > 0 {
                                    setMovement(movementCount - 1)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, Spacing.s1)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("태동 도트 그리드. \(movementCount)회 채워짐")

                // 태동 기록 버튼
                Button {
                    Haptics.soft()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if movementCount < 10 { setMovement(movementCount + 1) }
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
        let latest = weights.last?.value
        let first = weights.first?.value
        let delta = (latest != nil && first != nil) ? latest! - first! : nil

        return BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s2) {
                    Text("체중 변화")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    if let latest {
                        Text(weightSummary(latest: latest, delta: delta))
                            .font(AppFont.num(13))
                            .foregroundStyle(AppColors.ink2)
                            .padding(.horizontal, Spacing.s2)
                            .frame(height: 24)
                            .background(AppColors.surface2, in: Capsule())
                    }
                    Button { showWeightEntry = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppColors.pregnancyPink)
                    }
                    .accessibilityLabel("체중 기록 추가")
                }

                if weights.count >= 2 {
                    Chart(weights) { log in
                        LineMark(x: .value("날짜", log.date), y: .value("kg", log.value))
                            .foregroundStyle(AppColors.pregnancyPink)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("날짜", log.date), y: .value("kg", log.value))
                            .foregroundStyle(AppColors.pregnancyPink)
                    }
                    // 고정 폭 Y축 — 소폭 변화가 과장돼 보이지 않도록 위아래 여유를 둠
                    .chartYScale(domain: weightYDomain)
                    .frame(height: 120)
                    .accessibilityLabel("체중 추이 차트. 기록 \(weights.count)건, 현재 \(weightSummary(latest: latest ?? 0, delta: delta)).")

                    Text("꾸준히 기록하면 권장 증가 범위를 함께 살펴봐요")
                        .font(AppFont.micro)
                        .foregroundStyle(AppColors.ink3)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Button { showWeightEntry = true } label: {
                        VStack(spacing: Spacing.s2) {
                            Image(systemName: "scalemass")
                                .font(.system(size: 26, weight: .regular))
                                .foregroundStyle(AppColors.pregnancyPink.opacity(0.6))
                            Text(weights.isEmpty ? "체중을 기록하면 그래프가 그려져요"
                                                 : "한 번 더 기록하면 추이가 보여요")
                                .font(AppFont.caption)
                                .foregroundStyle(AppColors.ink3)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 104)
                        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(AppColors.pregnancyPink.opacity(0.3),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("체중 기록 추가하기")
                }

                Divider().overlay(AppColors.line)

                Text("※ 일반 정보이며 의료 상담을 대체하지 않아요")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// 체중 차트 Y축 도메인.
    /// 기록값을 모두 포함하되 최소 표시 폭(8kg)을 보장해, 0.2kg 같은 소폭 변화가
    /// 차트에서 과장돼 보이지 않도록 한다.
    private var weightYDomain: ClosedRange<Double> {
        let values = weights.map(\.value)
        guard let lo = values.min(), let hi = values.max() else { return 40...80 }
        let minSpan = 8.0
        let span = max(hi - lo, minSpan)
        let mid = (lo + hi) / 2
        let half = span / 2 + 1.5            // 위아래 여백
        return (mid - half)...(mid + half)
    }

    private func weightSummary(latest: Double, delta: Double?) -> String {
        let latestStr = latest == latest.rounded() ? "\(Int(latest))" : String(format: "%.1f", latest)
        guard let delta, abs(delta) >= 0.05 else { return "\(latestStr) kg" }
        let sign = delta > 0 ? "+" : "−"
        let deltaStr = String(format: "%.1f", abs(delta))
        return "\(latestStr) kg · \(sign)\(deltaStr) kg"
    }

    // 배 사진 D라인 타임라인 ─────────────────────────────────────────
    private var bellyPhotoTimeline: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: "타임라인", title: "배 사진 (D라인)")
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s3) {
                    // 사진 추가 셀 (로컬 저장)
                    PhotoPickerButton(image: $bellyPicked) {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.pregnancyPink)
                            Text("\(currentWeek)주차")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.ink3)
                        }
                        .frame(width: 96, height: 128)
                        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(AppColors.pregnancyPink.opacity(0.4),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        }
                    }
                    .accessibilityLabel("배 사진 추가, 현재 \(currentWeek)주차")

                    // 실제 배 사진들
                    ForEach(bellyLogs) { log in
                        bellyCell(log)
                    }

                    if !bellyLogs.isEmpty {
                        BellyPhotoContinuationCell()
                    }
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
        .padding(.bottom, Spacing.s4)
        .onChange(of: bellyPicked) { _, img in
            if let img, let pid = pregnancyId, let name = PhotoStore.save(img) {
                store.addBellyPhoto(pregnancyId: pid, week: currentWeek, photoRef: name)
                Haptics.success()
            }
            bellyPicked = nil
        }
    }

    @ViewBuilder
    private func bellyCell(_ log: PregnancyLog) -> some View {
        let loadedImage = PhotoStore.image(log.photoRef)
        ZStack(alignment: .bottomLeading) {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 96, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            } else {
                // 사진 파일을 불러오지 못한 경우 — 빈 박스 대신 부드러운 경고 표시
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .fill(AppColors.surface2)
                    .frame(width: 96, height: 128)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(AppColors.ink3)
                            Text("사진을\n불러올 수 없어요")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.ink3)
                                .multilineTextAlignment(.center)
                                .lineSpacing(1)
                        }
                        .accessibilityHidden(true)
                    }
            }
            Text("\(Int(log.value))주차")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(8)
        }
        .contextMenu {
            Button(role: .destructive) {
                store.deleteBellyPhoto(id: log.id)
            } label: {
                Label("사진 삭제", systemImage: "trash")
            }
        }
        .accessibilityLabel(
            loadedImage == nil
            ? "\(Int(log.value))주차 배 사진, 사진을 불러올 수 없어요"
            : "\(Int(log.value))주차 배 사진"
        )
    }
}

// MARK: - ③-C 산전 검사

struct PregnancyCheckupSection: View {
    @EnvironmentObject private var store: AppStore
    let week: (weeks: Int, days: Int)

    private var pregnancyId: UUID? { store.activePregnancy?.id }

    /// 사용자가 직접 토글한 완료 여부 (주차 기반 힌트와 별개로 사용자 입력 우선)
    private func userDone(_ checkup: PregnancyData.CheckupItem) -> Bool {
        guard let pid = pregnancyId else { return false }
        return store.isCheckupDone(pregnancyId: pid, checkupId: checkup.name)
    }

    /// 화면에 표시할 최종 완료 상태 (주차 힌트 + 사용자 토글 합성)
    private func effectiveDone(_ checkup: PregnancyData.CheckupItem) -> Bool {
        checkup.isDone || userDone(checkup)
    }

    private func toggle(_ checkup: PregnancyData.CheckupItem) {
        guard let pid = pregnancyId else { return }
        Haptics.soft()
        store.toggleCheckupDone(pregnancyId: pid, checkupId: checkup.name)
    }

    /// 현재 주차에 맞는 이 시기 권장 검사. 실제 예약일이 없으므로 D-day는 만들어내지 않는다.
    private var suggestedCheckup: (title: String, detail: String) {
        switch week.weeks {
        case 0..<11:   return ("초기 산전 검사", "10주 전후 · 첫 진료 권장")
        case 11..<14:  return ("초기 정밀 초음파·기형아 1차 검사", "11~13주 권장")
        case 14..<20:  return ("기형아 2차 검사", "16~20주 권장")
        case 20..<24:  return ("정밀 초음파", "20~24주 권장")
        case 24..<28:  return ("임신성 당뇨 검사", "24~28주 · 공복 검사 권장")
        case 28..<35:  return ("빈혈·소변 검사", "28주 전후 권장")
        default:       return ("GBS 검사", "35~37주 권장")
        }
    }

    var body: some View {
        LazyVStack(spacing: Spacing.s3, pinnedViews: []) {
            // 이 시기 권장 검사 하이라이트 (실 주차 기반, 만들어낸 D-day 없음)
            suggestedCheckupCard(
                title: suggestedCheckup.title,
                detail: suggestedCheckup.detail
            )
            .padding(.horizontal, Spacing.s5)

            // 전체 검사 목록
            BLSectionHead(eyebrow: "산전 검사", title: "검사 일정")
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s2)

            VStack(spacing: Spacing.s2) {
                ForEach(PregnancyData.checkupSchedule(currentWeek: week.weeks), id: \.id) { checkup in
                    checkupRow(checkup: checkup)
                }
            }
            .padding(.horizontal, Spacing.s5)

            Text("※ 실제 검사 시기는 담당 의료진과 상담하세요")
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s2)
                .padding(.bottom, Spacing.s4)
        }
    }

    private func suggestedCheckupCard(title: String, detail: String) -> some View {
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

            HStack(spacing: Spacing.s4) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.surface)
                        .frame(width: 52, height: 52)
                        .blShadow(.chip)
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppColors.pregnancyPink)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("이 시기 권장 검사")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(Color(hex: 0xA8537E).opacity(0.85))
                    Text(title)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text(detail)
                        .font(AppFont.caption)
                        .foregroundStyle(Color(hex: 0xA8537E))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.s5)
        }
        .blShadow(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("이 시기 권장 검사: \(title). \(detail).")
        .accessibilityHint("현재 주차 기준 권장 산전 검사")
    }

    private func checkupRow(checkup: PregnancyData.CheckupItem) -> some View {
        let done = effectiveDone(checkup)
        let canToggle = pregnancyId != nil
        return Button {
            toggle(checkup)
        } label: {
            BLCard(padding: Spacing.s4, flat: true) {
                HStack(spacing: Spacing.s3) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                            .fill(done ? Color(hex: 0xFBEAF0) : AppColors.surface3)
                            .frame(width: 42, height: 42)
                        Image(systemName: done ? "checkmark.circle.fill" : "calendar")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(done ? AppColors.pregnancyPink : AppColors.ink3)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(checkup.name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(done ? AppColors.ink2 : AppColors.ink)
                        Text(checkup.weekRange)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if done {
                        BLBadge(tone: .pink, text: "완료")
                    } else {
                        Text(checkup.dueLabel)
                            .font(AppFont.num(13, weight: .bold))
                            .foregroundStyle(checkup.isUrgent ? AppColors.pregnancyPink : AppColors.ink3)
                            .padding(.horizontal, Spacing.s2)
                            .frame(height: 25)
                            .background(
                                (checkup.isUrgent ? Color(hex: 0xFBEAF0) : AppColors.surface2),
                                in: Capsule()
                            )
                    }

                    // 완료 토글 체크 버튼
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(done ? AppColors.pregnancyPink : AppColors.ink3.opacity(0.5))
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .disabled(!canToggle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(checkup.name). \(checkup.weekRange). "
            + (done ? "완료됨" : checkup.dueLabel)
        )
        .accessibilityHint(canToggle ? (done ? "탭하면 완료 해제" : "탭하면 완료로 표시") : "")
        .accessibilityAddTraits(done ? .isSelected : [])
    }
}
