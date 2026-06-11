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
                pregnancyEmptyState
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
                        .padding(.bottom, Spacing.s3)

                    // 본문 모듈 스택
                    VStack(spacing: Spacing.s3) {
                        checkupPriorityCard
                        weeklyDevelopmentCard
                        neighborhoodCard
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
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.s5)
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
                            .font(AppFont.num(28))
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

    private var checkupPriorityCard: some View {
        Button {
            onNavigate(.record)
        } label: {
            ZStack(alignment: .topTrailing) {
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
                    BLBadge(tone: .pink, text: "지금 가장 중요해요", systemIcon: "cross.case.fill")

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text("임신성 당뇨 검사")
                                .font(.system(size: 21, weight: .heavy))
                                .foregroundStyle(AppColors.ink)

                            Text("24~28주 · 공복 검사 권장")
                                .font(AppFont.callout)
                                .foregroundStyle(Color(hex: 0xA8537E))
                        }

                        Spacer()

                        // D-day 숫자
                        Text("D-3")
                            .font(AppFont.num(30, weight: .heavy))
                            .foregroundStyle(AppColors.pregnancyPink)
                            .accessibilityHidden(true)
                    }
                    .padding(.top, Spacing.s3)

                    // 예약 버튼 + 알림 버튼
                    HStack(spacing: Spacing.s2) {
                        LiquidButton(
                            fill: AppColors.pregnancyPink,
                            cornerRadius: Radius.sm
                        ) {
                            onNavigate(.record)
                        } label: {
                            Text("검진 일정 보기")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Button {
                            onNavigate(.record)
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppColors.pregnancyPink)
                            }
                        }
                        .accessibilityLabel("검진 알림 설정")
                        .frame(width: 44, height: 44)
                    }
                    .padding(.top, Spacing.s4)
                }
                .padding(Spacing.s5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .blShadow(.card)
            .frame(minHeight: 44)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .accessibilityLabel("검진 우선 카드: 임신성 당뇨 검사, D-3, 24~28주 공복 검사 권장")
        .accessibilityHint("탭하면 검진 상세로 이동")
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
                HStack(spacing: Spacing.s2) {
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

    // MARK: - 동네 소식 요약

    private var neighborhoodCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                BLSectionHead(
                    eyebrow: "지역",
                    title: "우리 동네 소식",
                    action: "더보기",
                    onAction: { onNavigate(.dongne) }
                )

                VStack(spacing: Spacing.s3) {
                    neighborhoodRow(
                        emoji: "🍼",
                        emojiAccessibility: "아기 용품",
                        title: "뉴본 스와들 3종 나눔",
                        subtitle: "120m · 나눔 · 0~3개월",
                        seed: 0
                    )
                    neighborhoodRow(
                        emoji: "🧸",
                        emojiAccessibility: "장난감",
                        title: "에르고 힙시트 카리어",
                        subtitle: "350m · 5만원 · 6~36개월",
                        seed: 2
                    )
                }
            }
        }
    }

    private func neighborhoodRow(emoji: String, emojiAccessibility: String, title: String, subtitle: String, seed: Int) -> some View {
        Button {
            onNavigate(.dongne)
        } label: {
            HStack(spacing: Spacing.s3) {
                ZStack {
                    PhotoPlaceholder(seed: seed, cornerRadius: 12)
                        .frame(width: 50, height: 50)
                    Text(emoji)
                        .font(.system(size: 22))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(AppFont.micro)
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(title), \(subtitle), \(emojiAccessibility)")
        .accessibilityHint("탭하면 상세 정보 보기")
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

                            // 금액 (모노스페이스 숫자)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("320,000")
                                    .font(AppFont.num(24, weight: .heavy))
                                    .foregroundStyle(AppColors.ink)
                                Text("원")
                                    .font(AppFont.callout)
                                    .foregroundStyle(AppColors.ink2)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: Spacing.s1) {
                            BLBadge(tone: .mint, text: "전월 -12%", systemIcon: "arrow.down")
                            Text("아동수당 D-12 미신청")
                                .font(AppFont.micro)
                                .foregroundStyle(AppColors.ink3)
                        }
                    }

                    // 카테고리 바 (색+레이블 2중 인코딩)
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            budgetBarSegment(color: BadgeTone.blue.ink, width: geo.size.width * 0.45 - 2)
                            budgetBarSegment(color: BadgeTone.mint.ink, width: geo.size.width * 0.25 - 2)
                            budgetBarSegment(color: BadgeTone.amber.ink, width: geo.size.width * 0.20 - 2)
                            budgetBarSegment(color: AppColors.ink3, width: geo.size.width * 0.10)
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())

                    // 범례
                    HStack(spacing: Spacing.s3) {
                        budgetLegend(color: BadgeTone.blue.ink, label: "의료 45%")
                        budgetLegend(color: BadgeTone.mint.ink, label: "식품 25%")
                        budgetLegend(color: BadgeTone.amber.ink, label: "용품 20%")
                    }
                }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .accessibilityLabel("이번 달 육아비 320,000원. 전월 대비 -12%. 아동수당 신청 D-12")
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
