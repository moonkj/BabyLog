import SwiftUI

// MARK: - RecordScreen
// (세그먼트 본문 섹션은 RecordTimelineSection / RecordGrowthChartSection / RecordVaccineSection.swift로 분리)

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
                    guard segment != seg else { return }
                    Haptics.selection()
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

enum GrowthMetric: String, CaseIterable, Identifiable {
    case weight, height
    var id: String { rawValue }
    var label: String { self == .weight ? "몸무게" : "키" }
    var unit: String  { self == .weight ? "kg" : "cm" }
    var icon: String  { self == .weight ? "scalemass.fill" : "ruler.fill" }
}

// MARK: - Preview

#Preview {
    RecordScreen()
        .environmentObject(SampleData.store())
}
