// BabyLogWidget.swift — BabyLog Widget Extension
// WidgetKit + SwiftUI 자기완결형 구현 (앱 모듈 import 없음)
// 지원 크기: .systemSmall / .systemMedium
// 갱신 주기: 1시간 (배터리 고려 — 야간 2시간으로 확장)

import WidgetKit
import SwiftUI

// MARK: - Widget Color 토큰 (앱 DesignSystem 미사용 — 자기완결)

private enum WColor {
    // 세이지 / 크림 브랜드 톤
    static let sage         = Color(red: 0x4E/255, green: 0x82/255, blue: 0x68/255) // #4E8268
    static let sageSoft     = Color(red: 0xDC/255, green: 0xEF/255, blue: 0xE6/255) // #DСEFE6
    static let cream        = Color(red: 0xFB/255, green: 0xF7/255, blue: 0xF0/255) // #FBF7F0
    static let canvas       = Color.white
    // Ink
    static let ink          = Color(red: 0x21/255, green: 0x1D/255, blue: 0x17/255) // #211D17
    static let ink2         = Color(red: 0x6B/255, green: 0x62/255, blue: 0x56/255) // #6B6256
    static let ink3         = Color(red: 0xA8/255, green: 0x9D/255, blue: 0x8C/255) // #A89D8C
    // Danger
    static let danger       = Color(red: 0xBE/255, green: 0x4D/255, blue: 0x38/255) // #BE4D38
    static let dangerTint   = Color(red: 0xFA/255, green: 0xE2/255, blue: 0xDB/255) // #FAE2DB
    // Gold
    static let gold         = Color(red: 0xB0/255, green: 0x83/255, blue: 0x2E/255) // #B0832E
    static let goldTint     = Color(red: 0xFA/255, green: 0xEE/255, blue: 0xDA/255) // #FAEEDA
}

// MARK: - Timeline Entry

struct BabyLogEntry: TimelineEntry {
    let date: Date
    let data: BabyLogWidgetData
    let isPlaceholder: Bool
}

// MARK: - Timeline Provider

struct BabyLogTimelineProvider: TimelineProvider {

    // placeholder: 즉시 렌더 (갤러리/편집 미리보기용)
    func placeholder(in context: Context) -> BabyLogEntry {
        BabyLogEntry(date: Date(), data: WidgetSnapshotProvider.placeholder(), isPlaceholder: true)
    }

    // snapshot: 위젯 갤러리 실제 데이터 미리보기
    func getSnapshot(in context: Context, completion: @escaping (BabyLogEntry) -> Void) {
        let data = context.isPreview
            ? WidgetSnapshotProvider.placeholder()
            : WidgetSnapshotProvider.load()
        completion(BabyLogEntry(date: Date(), data: data, isPlaceholder: false))
    }

    // timeline: 실제 갱신 스케줄
    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyLogEntry>) -> Void) {
        let now  = Date()
        let data = WidgetSnapshotProvider.load()
        let entry = BabyLogEntry(date: now, data: data, isPlaceholder: false)

        // 배터리 고려:
        //  - 주간(6~22시): 1시간 갱신
        //  - 야간(22~6시): 2시간 갱신 (불필요한 wake 방지)
        let hour = Calendar.current.component(.hour, from: now)
        let intervalHours: Int = (hour >= 22 || hour < 6) ? 2 : 1
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: intervalHours, to: now) ?? now

        // .atEnd: 다음 entry 시각까지 캐시 유지 후 재요청
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Small Widget View (시스템 Small)
// 아이 요약 + 긴급 할 일 1개

private struct SmallWidgetView: View {
    let entry: BabyLogEntry

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        ZStack(alignment: .topLeading) {
            WColor.canvas
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 6) {
                // 상단: 아이 이름 + D+일
                if let child = entry.data.child {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(child.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(WColor.ink)
                            .lineLimit(1)
                        Spacer()
                        Text("D+\(child.dPlusDays)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(WColor.sage)
                    }

                    // 월령 뱃지
                    Text(child.ageLabel)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(WColor.ink3)

                    // 최근 사진 자리 (App Group 연동 전 → 크림 플레이스홀더)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(WColor.cream)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundStyle(WColor.ink3)
                        )
                }

                Spacer(minLength: 2)

                // 하단: 첫 번째 긴급 할 일
                if let task = entry.data.tasks.first {
                    taskBadge(task)
                } else {
                    Text("오늘 할 일 없음")
                        .font(.system(size: 10))
                        .foregroundStyle(WColor.ink3)
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func taskBadge(_ task: TodayTask) -> some View {
        HStack(spacing: 5) {
            Image(systemName: task.kind == .vaccine ? "syringe.fill" : "wonsign.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(task.isUrgent ? WColor.danger : WColor.gold)
            Text(task.title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(task.isUrgent ? WColor.danger : WColor.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(task.isUrgent ? WColor.dangerTint : WColor.goldTint)
        )
    }
}

// MARK: - Medium Widget View (시스템 Medium)
// 전체: 아이 요약 + 오늘 할 일 목록 + 주변 소아과

private struct MediumWidgetView: View {
    let entry: BabyLogEntry

    var body: some View {
        ZStack {
            WColor.canvas.ignoresSafeArea()

            HStack(alignment: .top, spacing: 12) {

                // 왼쪽: 아이 요약
                childSummaryColumn

                Divider()
                    .frame(maxHeight: .infinity)
                    .background(WColor.cream)

                // 오른쪽: 할 일 + 소아과
                VStack(alignment: .leading, spacing: 8) {
                    tasksSection
                    if !entry.data.clinics.isEmpty {
                        Divider()
                        clinicSection
                    }
                }
            }
            .padding(14)
        }
    }

    // 아이 요약 컬럼
    private var childSummaryColumn: some View {
        VStack(alignment: .center, spacing: 6) {
            // 사진 자리 (App Group 연동 전 플레이스홀더)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WColor.cream)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(WColor.ink3)
                )

            if let child = entry.data.child {
                Text(child.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(WColor.ink)

                Text("D+\(child.dPlusDays)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(WColor.sage)

                Text(child.ageLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(WColor.ink3)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 72)
    }

    // 오늘 할 일 섹션
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("오늘 할 일", systemImage: "checklist")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WColor.ink2)

            if entry.data.tasks.isEmpty {
                Text("예정된 항목이 없어요")
                    .font(.system(size: 10))
                    .foregroundStyle(WColor.ink3)
            } else {
                ForEach(entry.data.tasks.prefix(3)) { task in
                    taskRow(task)
                }
            }
        }
    }

    @ViewBuilder
    private func taskRow(_ task: TodayTask) -> some View {
        HStack(spacing: 5) {
            Image(systemName: task.kind == .vaccine ? "syringe.fill" : "wonsign.circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(task.isUrgent ? WColor.danger : WColor.gold)
                .frame(width: 12)

            Text(task.title)
                .font(.system(size: 11, weight: task.isUrgent ? .medium : .regular))
                .foregroundStyle(task.isUrgent ? WColor.danger : WColor.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if task.isUrgent {
                Text("오늘")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(WColor.danger)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(WColor.dangerTint)
                    )
            }
        }
    }

    // 소아과 섹션
    private var clinicSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("주변 소아과", systemImage: "cross.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WColor.ink2)

            ForEach(entry.data.clinics.prefix(2)) { clinic in
                clinicRow(clinic)
            }
        }
    }

    @ViewBuilder
    private func clinicRow(_ clinic: NearbyClinic) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(clinic.isOpenNow ? WColor.sage : WColor.ink3)
                .frame(width: 6, height: 6)

            Text(clinic.name)
                .font(.system(size: 11))
                .foregroundStyle(WColor.ink)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let dist = clinic.distanceMeter {
                Text(dist >= 1000
                     ? String(format: "%.1fkm", Double(dist) / 1000)
                     : "\(dist)m")
                    .font(.system(size: 9))
                    .foregroundStyle(WColor.ink3)
            }

            Text(clinic.isOpenNow ? "영업중" : "마감")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(clinic.isOpenNow ? WColor.sage : WColor.ink3)
        }
    }
}

// MARK: - Accessibility-aware Entry View Router

struct BabyLogEntryView: View {
    let entry: BabyLogEntry

    @Environment(\.widgetFamily) private var family
    // Reduce Transparency / Reduce Motion 고려 — WidgetKit은 직접 env 제공 안 함
    // SwiftUI accessibilityReduceTransparency로 불투명 처리
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry) // fallback
            }
        }
        // Reduce Transparency 시 배경 불투명 고정
        .background(reduceTransparency ? WColor.canvas : WColor.canvas)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Widget Configuration

struct BabyLogWidget: Widget {
    let kind: String = "BabyLogWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyLogTimelineProvider()) { entry in
            BabyLogEntryView(entry: entry)
        }
        .configurationDisplayName("BabyLog")
        .description("오늘 할 일, 아이 요약, 주변 소아과를 한눈에 확인하세요.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // iOS 17+ 배터리 최적화: 시스템이 추가로 갱신 주기 조율 허용
        .contentMarginsDisabled() // 커스텀 패딩 제어
    }
}
