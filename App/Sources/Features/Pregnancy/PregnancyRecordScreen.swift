// Features/Pregnancy/PregnancyRecordScreen.swift
// BabyLog · 임신 모드 기록 탭 메인 스크린
// SwiftUI / Foundation only
// (세그먼트 본문·데이터 헬퍼는 PregnancyRecordSections.swift / PregnancyRecordData.swift로 분리)

import SwiftUI

// MARK: - 진입점

/// 임신 모드 기록 탭 스크린.
/// AppStore.activePregnancy 실데이터 우선, 없으면 목업 폴백.
struct PregnancyRecordScreen: View {

    @EnvironmentObject private var store: AppStore

    // ── 목업 폴백 ────────────────────────────────────────────────────
    private let mockLMP: Date = Calendar.current.date(
        byAdding: .day, value: -168,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    private let mockEDD: Date = Calendar.current.date(
        byAdding: .day, value: 112,
        to: Calendar.current.startOfDay(for: Date())
    ) ?? Date()

    private let mockNickname: String = "튼튼이"

    // ── 실데이터 vs 목업 ─────────────────────────────────────────────
    // 목업은 "진짜로 비어 있는(데모/온보딩 전)" 상황에서만 쓴다.
    // 등록된 임신이 있는데 활성만 아닐 때(출산 완료 등)는 가짜 24주 히어로를 띄우지 않는다.
    private var lmp: Date  { store.activePregnancy?.lmpDate ?? mockLMP }
    private var edd: Date  { store.activePregnancy?.eddDate ?? mockEDD }
    private var nickname: String {
        store.activePregnancy?.nickname?.isEmpty == false
            ? store.activePregnancy!.nickname!
            : mockNickname
    }

    // ── 주수·D-day 계산 ─────────────────────────────────────────────
    // 주수 계산 불가(데이터 부족)이면 nil — 가짜 24주를 만들지 않는다.
    private var pregnancyWeekOrNil: (weeks: Int, days: Int)? {
        AgeCalculator.pregnancyWeeks(lmp: lmp, edd: edd, asOf: Date())
    }

    private var pregnancyWeek: (weeks: Int, days: Int) {
        pregnancyWeekOrNil ?? (0, 0)
    }

    private var dDayToBirth: Int {
        AgeCalculator.dDayToBirth(edd: edd, asOf: Date())
    }

    // ── 상태 ────────────────────────────────────────────────────────
    @State private var selectedSegment: PregnancyRecordSegment = .fetus
    @State private var showBirthTransition: Bool = false
    @State private var showPauseConfirm: Bool = false
    @State private var showReg: Bool = false

    // ── 등록된 임신이 하나도 없는 상태 ────────────────────────────────
    private var hasNoPregnancy: Bool {
        store.pregnancies.isEmpty && store.activePregnancy == nil
    }

    // ── 활성 임신이 없고, 일시중단/상실도 아닌 임신만 있는 상태 ────────────
    // (예: 출산 완료 .delivered) — 가짜 24주 히어로 대신 차분한 안내를 보여준다.
    private var nonActivePregnancyToShow: Pregnancy? {
        guard store.activePregnancy == nil, !store.pregnancies.isEmpty else { return nil }
        let p = store.pregnancies.first
        // 일시중단/상실은 별도 카드에서 처리하므로 여기선 제외
        if let s = p?.status, s == .loss || s == .paused { return nil }
        return p
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColors.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // 등록된 임신이 없으면 빈 상태 (목업 대신)
                        if hasNoPregnancy {
                            emptyStateCard
                                .padding(.horizontal, Spacing.s5)
                                .padding(.top, Spacing.s4)
                        }
                        // 상실/일시중단 상태면 안내 카드
                        else if let preg = store.activePregnancy ?? store.pregnancies.first,
                           preg.status == .loss || preg.status == .paused {
                            pausedOrLossCard(pregnancy: preg)
                                .padding(.horizontal, Spacing.s5)
                                .padding(.top, Spacing.s4)
                        }
                        // 활성 임신이 없고 출산 완료 등 비활성 임신만 있는 경우 — 가짜 주차 대신 차분한 안내
                        else if store.activePregnancy == nil, nonActivePregnancyToShow != nil {
                            deliveredOrInactiveCard
                                .padding(.horizontal, Spacing.s5)
                                .padding(.top, Spacing.s4)
                        } else {
                            // ① 태아 히어로 카드
                            heroSection
                                .padding(.horizontal, Spacing.s5)
                                .padding(.top, Spacing.s4)
                                .padding(.bottom, Spacing.s4)

                            // ② 세그먼트 선택
                            segmentBar
                                .padding(.horizontal, Spacing.s5)
                                .padding(.bottom, Spacing.s4)

                            // ③ 세그먼트 본문
                            switch selectedSegment {
                            case .fetus:    PregnancyFetusGuideSection(week: pregnancyWeek)
                            case .mom:      PregnancyMomRecordSection()
                            case .checkup:  PregnancyCheckupSection(week: pregnancyWeek)
                            }

                            // ④ 기록 멈춤 진입점 (민감영역 — 아주 절제된 텍스트 버튼)
                            pauseEntryButton
                                .padding(.horizontal, Spacing.s5)
                                .padding(.top, Spacing.s2)
                                .padding(.bottom, Spacing.s7)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // 홈 '검진 일정 보기' 딥링크 — 진입 시 검진 세그먼트로 전환
            .onChange(of: store.openPregnancyCheckup) { _, open in
                if open { withAnimation { selectedSegment = .checkup }; store.openPregnancyCheckup = false }
            }
            .onAppear {
                if store.openPregnancyCheckup { selectedSegment = .checkup; store.openPregnancyCheckup = false }
            }
            .alert("잠시 멈춰도 괜찮아요", isPresented: $showPauseConfirm) {
                if let preg = pauseTargetPregnancy {
                    Button("잠시 멈출게요") {
                        store.updatePregnancyStatus(pregnancyId: preg.id, to: .paused)
                    }
                    Button("기록을 마칠게요", role: .destructive) {
                        store.updatePregnancyStatus(pregnancyId: preg.id, to: .loss)
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기록은 안전히 보관돼요. 언제든 다시 시작할 수 있어요.\n'기록을 마칠게요'를 선택하면 주차 알림이 자동으로 멈춰요.")
            }
        }
        .sheet(isPresented: $showBirthTransition) {
            BirthTransitionView {
                showBirthTransition = false
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showReg) {
            AddPregnancySheet()
                .environmentObject(store)
        }
    }

    // ── 멈춤 대상 임신 (active 우선, 없으면 첫 번째) ─────────────────
    private var pauseTargetPregnancy: Pregnancy? {
        store.activePregnancy ?? store.pregnancies.first
    }

    // MARK: - 기록 멈춤 진입점

    private var pauseEntryButton: some View {
        Button {
            showPauseConfirm = true
        } label: {
            Text("잠시 기록을 멈추고 싶어요")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("기록 멈춤 또는 종료")
        .accessibilityHint("탭하면 기록을 일시 중단하거나 마칠 수 있어요")
    }

    // MARK: - 빈 상태 (등록된 임신 없음)

    private var emptyStateCard: some View {
        BLCard(flat: true) {
            VStack(spacing: Spacing.s4) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFBEAF0))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(AppColors.pregnancyPink.opacity(0.12), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(AppColors.pregnancyPink.opacity(0.85))
                }
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.s3)

                VStack(spacing: Spacing.s2) {
                    Text("임신을 등록해보세요")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .multilineTextAlignment(.center)

                    Text("태명과 출산 예정일을 입력하면\n주차별 가이드와 체중·배 사진 기록이 시작돼요.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                // 임신 등록하기 버튼
                Button {
                    showReg = true
                } label: {
                    Text("임신 등록하기")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.pregnancyPink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Color(hex: 0xFBEAF0),
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
                .accessibilityLabel("임신 등록하기")
                .accessibilityHint("탭하면 태명과 출산 예정일을 입력하는 시트가 열려요")
                .padding(.bottom, Spacing.s2)
            }
            .padding(.vertical, Spacing.s2)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 상실/일시중단 안내 카드

    private func pausedOrLossCard(pregnancy: Pregnancy) -> some View {
        VStack(spacing: Spacing.s4) {
            BLCard(flat: true) {
                VStack(spacing: Spacing.s4) {
                    // 아이콘
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xFBEAF0))
                            .frame(width: 80, height: 80)
                        Circle()
                            .stroke(AppColors.pregnancyPink.opacity(0.12), lineWidth: 1)
                            .frame(width: 80, height: 80)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(AppColors.pregnancyPink.opacity(0.7))
                    }
                    .accessibilityHidden(true)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, Spacing.s3)

                    VStack(spacing: Spacing.s2) {
                        Text("언제든 돌아오세요")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                            .multilineTextAlignment(.center)

                        Text("기록은 안전히 보관돼요.\n준비가 될 때 언제든 다시 시작할 수 있어요.")
                            .font(AppFont.callout)
                            .foregroundStyle(AppColors.ink2)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // 다시 시작 버튼
                    Button {
                        store.updatePregnancyStatus(
                            pregnancyId: pregnancy.id,
                            to: .active
                        )
                    } label: {
                        Text("다시 시작하기")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.pregnancyPink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                Color(hex: 0xFBEAF0),
                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            )
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.97))
                    .accessibilityLabel("기록 다시 시작하기")
                    .accessibilityHint("탭하면 임신 기록이 다시 활성화돼요")

                    Text("기존에 남긴 기록은 모두 그대로 있어요.")
                        .font(AppFont.micro)
                        .foregroundStyle(AppColors.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, Spacing.s2)
                }
                .padding(.vertical, Spacing.s2)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - 출산 완료 등 비활성 임신 안내 카드 (가짜 주차 대신)

    private var deliveredOrInactiveCard: some View {
        BLCard(flat: true) {
            VStack(spacing: Spacing.s4) {
                // 아이콘 — 손을 맞잡은 부모·아이 (육아 모드 연속성)
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFBEAF0))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(AppColors.pregnancyPink.opacity(0.12), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(AppColors.pregnancyPink.opacity(0.85))
                }
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.s3)

                VStack(spacing: Spacing.s2) {
                    Text("육아 모드에서 이어가요")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .multilineTextAlignment(.center)

                    Text("임신 기록은 안전히 보관돼 있어요.\n이제 성장 기록 탭에서 아이의 하루를 담아보세요.")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.bottom, Spacing.s2)
            }
            .padding(.vertical, Spacing.s2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("육아 모드에서 이어가요. 임신 기록은 안전히 보관돼 있고, 성장 기록 탭에서 아이의 하루를 담을 수 있어요.")
    }

    // MARK: - 툴바

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("기록")
                .font(AppFont.h2)
                .foregroundStyle(AppColors.ink)
        }
        // .active 상태일 때만 "출산했어요" 버튼 표시 (민감영역)
        if store.activePregnancy != nil {
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
                }
                .tint(AppColors.pregnancyPink)
                .accessibilityLabel("출산 전환 시작")
                .accessibilityHint("탭하면 아이 프로필로 전환하는 시트가 열립니다")
            }
        }
    }

    // MARK: - ① 태아 히어로 카드

    private var heroSection: some View {
        let weekOpt = pregnancyWeekOrNil
        let week = weekOpt ?? (0, 0)
        let dday = dDayToBirth
        let fruit = FruitData.forWeek(week.weeks)
        let ddayLabel = dday >= 0 ? "D-\(dday)" : "D+\(-dday)"
        // 주차 계산 불가(데이터 부족)면 가짜 주차 대신 중립 라벨
        let weekBadgeText = weekOpt != nil
            ? "\(PregnancyData.trimesterLabel(week.weeks)) · \(week.weeks)주 \(week.days)일"
            : "주차 계산 불가"
        // 주차 진행감 — 40주 기준 진행률 (시각 보조용, 0~1 클램프)
        let progress = weekOpt != nil
            ? max(0, min(1, Double(week.weeks * 7 + week.days) / 280.0))
            : 0

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

                VStack(alignment: .leading, spacing: Spacing.s4) {
                    HStack(spacing: Spacing.s5) {
                        // 과일 원형
                        ZStack {
                            Circle()
                                .fill(AppColors.surface)
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                                }
                                .blShadow(.card)
                            Text(fruit.emoji)
                                .font(.system(size: 40))
                        }
                        .accessibilityHidden(true)

                        // 텍스트 정보
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            BLBadge(
                                tone: .pink,
                                text: weekBadgeText,
                                dot: true
                            )
                            Text(ddayLabel)
                                .font(AppFont.num(34, weight: .heavy))
                                .foregroundStyle(AppColors.pregnancyPink)
                            Text(weekOpt != nil ? "\(fruit.name)만 해요 · 출산까지" : "출산까지")
                                .font(AppFont.caption)
                                .foregroundStyle(Color(hex: 0xA8537E))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            weekOpt != nil
                            ? "\(PregnancyData.trimesterLabel(week.weeks)), \(week.weeks)주 \(week.days)일. 출산까지 \(ddayLabel). 태아 크기는 \(fruit.name) 정도예요."
                            : "주차 계산 불가. 출산까지 \(ddayLabel)."
                        )

                        Spacer(minLength: 0)
                    }

                    // 주차 진행 바 (40주 여정 시각화 — 안심 톤, 경쟁 아님)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .frame(height: 7)
                                Capsule()
                                    .fill(AppColors.pregnancyPink.opacity(0.85))
                                    .frame(width: max(8, geo.size.width * progress), height: 7)
                            }
                        }
                        .frame(height: 7)

                        HStack {
                            Text(weekOpt != nil ? "\(week.weeks)주" : "—주")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: 0xA8537E))
                            Spacer()
                            Text("출산 40주")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: 0xA8537E).opacity(0.7))
                        }
                    }
                    .accessibilityHidden(true)
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
        HStack(spacing: Spacing.s2) {
            ForEach(PregnancyRecordSegment.allCases) { seg in
                let isOn = selectedSegment == seg
                Button {
                    guard selectedSegment != seg else { return }
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedSegment = seg
                    }
                } label: {
                    Text(seg.label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(isOn ? Color.white : AppColors.ink2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            isOn ? AppColors.ink : AppColors.surface,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        )
                        .overlay {
                            if !isOn {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .stroke(AppColors.line, lineWidth: 1)
                            }
                        }
                        .blShadow(isOn ? .card : .chip)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .accessibilityLabel(seg.label)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

// MARK: - 미리보기

#if DEBUG
#Preview("임신 기록 스크린") {
    PregnancyRecordScreen()
        .environmentObject(SampleData.store())
}

#Preview("임신 기록 — 기록 멈춤 상태") {
    let store = SampleData.store()
    if let preg = store.pregnancies.first {
        store.updatePregnancyStatus(pregnancyId: preg.id, to: .paused)
    }
    return PregnancyRecordScreen()
        .environmentObject(store)
}
#endif
