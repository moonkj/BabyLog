// Features/Pregnancy/PregnancyRecordData.swift
// BabyLog · 임신 모드 기록 탭 — 정적 데이터 헬퍼 및 재사용 컴포넌트
// (PregnancyRecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)
// SwiftUI / Swift Charts / Foundation only

import SwiftUI
import Charts

// MARK: - 태동 도트

struct MovementDot: View {
    var filled: Bool
    var index: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(filled ? Color(hex: 0xD96BA0) : AppColors.ink3.opacity(0.18))
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

struct WeightChart: View {
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

struct BellyPhotoCell: View {
    let week: Int
    let seed: Int

    var body: some View {
        VStack(spacing: Spacing.s2) {
            ZStack {
                PhotoPlaceholder(seed: seed, cornerRadius: 14)
                    .frame(width: 104, height: 132)
                // D라인 아이콘 힌트
                Image(systemName: "figure.stand")
                    .font(.system(size: 32, weight: .light))
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

struct BellyPhotoContinuationCell: View {
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

enum PregnancyRecordSegment: String, CaseIterable, Identifiable {
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

enum FruitData {
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

enum PregnancyData {

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
            .init(name: "초기 정밀 초음파",      weekRange: "11~13주",  dueLabel: "권장", isDone: false, isUrgent: false),
            .init(name: "기형아 1차 검사",        weekRange: "11~13주",  dueLabel: "권장", isDone: false, isUrgent: false),
            .init(name: "기형아 2차 검사",        weekRange: "16~20주",  dueLabel: "권장", isDone: false, isUrgent: false),
            .init(name: "정밀 초음파",            weekRange: "20~24주",  dueLabel: "D-14", isDone: false, isUrgent: false),
            .init(name: "임신성 당뇨 검사",       weekRange: "24~28주",  dueLabel: "D-3",  isDone: false, isUrgent: true),
            .init(name: "빈혈·소변 검사",         weekRange: "28주",     dueLabel: "D+11", isDone: false, isUrgent: false),
            .init(name: "GBS 검사",               weekRange: "35~37주",  dueLabel: "예정", isDone: false, isUrgent: false),
        ]
    }
}
