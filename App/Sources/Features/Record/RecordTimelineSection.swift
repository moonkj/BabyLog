// Features/Record/RecordTimelineSection.swift
// BabyLog · 성장 기록 탭 — 타임라인 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI

// MARK: - 타임라인 섹션

struct TimelineSection: View {
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

enum TimelineItem {
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
        let photo = PhotoStore.image(entry.photoRef)
        let photoHeight: CGFloat = isMilestone ? 200 : 160

        return BLCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 사진 영역 — 실제 로컬 사진 우선, 없으면 이정표일 때만 플레이스홀더
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: photoHeight)
                        .clipped()
                        .overlay(alignment: .topLeading) { milestoneBadge }
                } else if isMilestone {
                    PhotoPlaceholder(seed: 2, cornerRadius: 0)
                        .frame(height: 180)
                        .clipped()
                        .overlay(alignment: .topLeading) { milestoneBadge }
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

    @ViewBuilder
    private var milestoneBadge: some View {
        if let milestone = entry.milestone {
            BLBadge(tone: .amber, text: milestone, systemIcon: "star.fill")
                .padding(12)
                .accessibilityLabel("이정표: \(milestone)")
        }
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
