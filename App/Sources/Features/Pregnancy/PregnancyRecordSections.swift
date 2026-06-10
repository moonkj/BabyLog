// Features/Pregnancy/PregnancyRecordSections.swift
// BabyLog · 임신 모드 기록 탭 — 세그먼트 본문 섹션 뷰
// (PregnancyRecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)
// SwiftUI / Foundation only

import SwiftUI

// MARK: - ③-A 태아 가이드

struct PregnancyFetusGuideSection: View {
    let week: (weeks: Int, days: Int)

    var body: some View {
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
            .padding(.bottom, Spacing.s4)
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
}

// MARK: - ③-B 산모 기록

struct PregnancyMomRecordSection: View {
    @Binding var movementCount: Int

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
        .padding(.bottom, Spacing.s4)
    }
}

// MARK: - ③-C 산전 검사

struct PregnancyCheckupSection: View {
    let week: (weeks: Int, days: Int)

    var body: some View {
        LazyVStack(spacing: Spacing.s2, pinnedViews: []) {
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
                .padding(.bottom, Spacing.s4)
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
