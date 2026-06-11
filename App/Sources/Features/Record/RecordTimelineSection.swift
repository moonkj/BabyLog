// Features/Record/RecordTimelineSection.swift
// BabyLog · 성장 기록 탭 — 타임라인 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI
import UIKit

// MARK: - 타임라인 섹션

struct TimelineSection: View {
    @EnvironmentObject private var store: AppStore
    let child: Child

    // store에서 실데이터 (일기 + 성장, date 내림차순 통합)
    private var allItems: [(date: Date, item: TimelineItem)] {
        let diaries = store.diaryEntries
            .filter { $0.childId == child.id }
            .map { (date: $0.date, item: TimelineItem.diary($0)) }
        let growth = store.growthRecords
            .filter { $0.childId == child.id }
            .map { (date: $0.date, item: TimelineItem.growth($0)) }
        return (diaries + growth).sorted { $0.date > $1.date }
    }

    private var totalCount: Int { allItems.count }

    // 날짜별 그룹 (최신일 우선, 일자 내 최신순)
    private var groupedItems: [(String, [TimelineItem])] {
        let df = DateFormatter(); df.locale = Locale(identifier: "ko_KR")
        df.dateFormat = "yyyy년 M월 d일 EEEE"
        var order: [String] = []
        var map: [String: [TimelineItem]] = [:]
        for entry in allItems {   // 이미 내림차순
            let key = df.string(from: entry.date)
            if map[key] == nil { order.append(key) }
            map[key, default: []].append(entry.item)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        if allItems.isEmpty {
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
                                DiaryTimelineCard(entry: e, child: child)
                            }
                        }
                    }
                }
                // 하단 안내
                Text("\(child.name)의 \(totalCount)개 순간이 기록되었어요 💛")
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
// 인스타그램 스타일 기록 카드 (가족·조부모 모드 대비: 하트·댓글·공유)
private struct DiaryTimelineCard: View {
    @EnvironmentObject private var store: AppStore
    var entry: DiaryEntry
    var child: Child
    @State private var showFullPhoto = false
    @State private var showComments = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heartPop = false

    private var isMilestone: Bool { entry.milestone != nil }
    private var liked: Bool { store.isDiaryLiked(entry.id) }
    private var commentCount: Int { store.comments(for: entry.id).count }

    var body: some View {
        let photo = PhotoStore.image(entry.photoRef)
        return BLCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header

                // 사진 — 더블탭 좋아요 / 탭 전체화면
                if let photo {
                    Image(uiImage: photo)
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipped()
                        .overlay(alignment: .topLeading) { milestoneBadge }
                        .overlay { heartPopOverlay }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { likeWithPop() }
                        .onTapGesture { showFullPhoto = true }
                } else if isMilestone {
                    PhotoPlaceholder(seed: 2, cornerRadius: 0)
                        .frame(height: 200)
                        .clipped()
                        .overlay(alignment: .topLeading) { milestoneBadge }
                }

                actionBar(photo: photo)
                captionBlock
            }
        }
        .contextMenu {
            Button(role: .destructive) { store.deleteDiaryEntry(id: entry.id) } label: {
                Label("기록 삭제", systemImage: "trash")
            }
        }
        .fullScreenCover(isPresented: $showFullPhoto) {
            if let photo { FullScreenPhotoView(image: photo, onClose: { showFullPhoto = false }) }
        }
        .sheet(isPresented: $showComments) {
            DiaryCommentSheet(entryId: entry.id, authorName: child.name)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
    }

    // 헤더: 아바타 + 이름 + 시각 + 메뉴
    private var header: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                Text(child.name).font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.ink)
                Text(timeText).font(.system(size: 11.5, weight: .medium)).foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Menu {
                Button(role: .destructive) { store.deleteDiaryEntry(id: entry.id) } label: {
                    Label("기록 삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.ink3)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("더보기")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var avatar: some View {
        Group {
            if let p = PhotoStore.image(child.profileImageRef) {
                Image(uiImage: p).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(AppColors.primaryTint)
                    Text(String(child.name.prefix(1)))
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.primary)
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    // 액션 바: 하트 · 댓글 · 공유
    @ViewBuilder
    private func actionBar(photo: UIImage?) -> some View {
        HStack(spacing: 18) {
            Button { likeWithPop() } label: {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(liked ? Color(hex: 0xE8607A) : AppColors.ink)
                    .scaleEffect(heartPop ? 1.25 : 1.0)
            }
            .accessibilityLabel(liked ? "좋아요 취소" : "좋아요")

            Button { showComments = true } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(AppColors.ink)
            }
            .accessibilityLabel("댓글")

            if let photo {
                ShareLink(item: Image(uiImage: photo),
                          preview: SharePreview("\(child.name) 기록", image: Image(uiImage: photo))) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AppColors.ink)
                }
                .accessibilityLabel("공유")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // 좋아요 수 + 캡션 + 댓글
    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if liked {
                Text("좋아요 표시함")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.ink)
            }
            if let content = entry.content, !content.isEmpty {
                (Text(child.name).font(.system(size: 14, weight: .bold))
                 + Text("  ") + Text(content).font(.system(size: 14)))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if commentCount > 0 {
                Button { showComments = true } label: {
                    Text("댓글 \(commentCount)개 모두 보기")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private var milestoneBadge: some View {
        if let milestone = entry.milestone {
            BLBadge(tone: .amber, text: milestone, systemIcon: "star.fill")
                .padding(12)
                .accessibilityLabel("이정표: \(milestone)")
        }
    }

    @ViewBuilder
    private var heartPopOverlay: some View {
        if heartPop {
            Image(systemName: "heart.fill")
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.25), radius: 8)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func likeWithPop() {
        if !liked { Haptics.success() } else { Haptics.light() }
        store.toggleDiaryLike(entry.id)
        if store.isDiaryLiked(entry.id) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { heartPop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.25)) { heartPop = false }
            }
        }
    }

    private var timeText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f.string(from: entry.date)
    }
}

// MARK: - 댓글 시트

private struct DiaryCommentSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entryId: UUID
    let authorName: String
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    let comments = store.comments(for: entryId)
                    if comments.isEmpty {
                        Text("첫 댓글을 남겨보세요.\n가족 공유가 열리면 조부모님도 함께 댓글을 남길 수 있어요.")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Spacing.s8)
                    } else {
                        VStack(alignment: .leading, spacing: Spacing.s3) {
                            ForEach(Array(comments.enumerated()), id: \.offset) { _, c in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("나").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink)
                                    Text(c).font(.system(size: 14)).foregroundStyle(AppColors.ink)
                                    Spacer()
                                }
                            }
                        }
                        .padding(Spacing.s4)
                    }
                }
                HStack(spacing: Spacing.s2) {
                    TextField("댓글 달기…", text: $text)
                        .font(AppFont.body)
                        .padding(.horizontal, Spacing.s4).frame(height: 44)
                        .background(AppColors.surface2, in: Capsule())
                    Button {
                        store.addComment(entryId: entryId, text: text)
                        text = ""; Haptics.light()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(text.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.ink3 : AppColors.primary)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(Spacing.s3)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("댓글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }
}
