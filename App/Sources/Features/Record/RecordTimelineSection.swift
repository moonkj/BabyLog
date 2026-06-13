// Features/Record/RecordTimelineSection.swift
// BabyLog · 성장 기록 탭 — 타임라인 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI
import UIKit

private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

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
                        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
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

enum TimelineItem: Identifiable {
    case growth(GrowthRecord)
    case diary(DiaryEntry)
    /// 안정 식별자 — ForEach가 위치(offset)가 아닌 레코드 id로 카드 @State를 보존하게 한다.
    var id: UUID {
        switch self {
        case .growth(let r): return r.id
        case .diary(let e):  return e.id
        }
    }
}

// 날짜 구분선 헤더
private struct DateGroupHeader: View {
    var label: String
    var body: some View {
        HStack(spacing: Spacing.s2) {
            // 날짜 마커 점(시각적 타임라인 앵커)
            Circle()
                .fill(AppColors.primary.opacity(0.5))
                .frame(width: 5, height: 5)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(AppColors.ink2)
            Rectangle()
                .fill(AppColors.line)
                .frame(height: 1)
        }
        .padding(.top, Spacing.s1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)   // VoiceOver 로터로 날짜 그룹 탐색 가능
    }
}

// 성장 측정 카드
private struct GrowthTimelineCard: View {
    @EnvironmentObject private var store: AppStore
    var record: GrowthRecord
    var body: some View {
        BLCard(padding: Spacing.s4) {
            HStack(spacing: 12) {
                // 색+아이콘 인코딩 — 박스 배경과 아이콘 색을 같은 tone(primary)으로 일치
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.primaryTint)
                        .frame(width: 46, height: 46)
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("성장 측정")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    HStack(spacing: 6) {
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
        .contextMenu {
            Button(role: .destructive) {
                Haptics.warning()
                store.deleteGrowthRecord(id: record.id)
            } label: {
                Label("기록 삭제", systemImage: "trash")
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
    @State private var showComments = false
    @State private var showEdit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heartPop = false
    @State private var cardIndex = 0
    @State private var fullPhoto: UIImage? = nil

    private var isMilestone: Bool { entry.milestone != nil }
    private var liked: Bool { store.isDiaryLiked(entry.id) }
    private var commentCount: Int { store.comments(for: entry.id).count }

    var body: some View {
        let photos = entry.photoRefList.compactMap { PhotoStore.image($0) }
        let videoURL = PhotoStore.videoURL(entry.videoRef)
        let pageCount = photos.count + (videoURL != nil ? 1 : 0)
        return BLCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header

                // 미디어 — 스와이프 캐러셀(사진 여러 장 + 동영상), 더블탭 좋아요 / 탭 전체화면
                if pageCount > 0 {
                    TabView(selection: $cardIndex) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { idx, img in
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 360).clipped()
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { likeWithPop() }
                                .onTapGesture { fullPhoto = img }
                                .tag(idx)
                                // VoiceOver: 침묵하던 사진에 라벨·동작 부여(좋아요는 액션바 버튼으로도 가능)
                                .accessibilityElement()
                                .accessibilityLabel("\(child.name) 사진 \(idx + 1)\(photos.count > 1 ? ", 전체 \(photos.count)장" : "")")
                                .accessibilityAddTraits(.isImage)
                                .accessibilityHint("두 번 탭하면 전체화면")
                                .accessibilityAction { fullPhoto = img }
                        }
                        if let videoURL {
                            VideoPreviewView(url: videoURL)
                                .frame(maxWidth: .infinity).frame(height: 360)
                                .tag(photos.count)
                        }
                    }
                    .frame(height: 360)
                    .tabViewStyle(.page(indexDisplayMode: pageCount > 1 ? .always : .never))
                    .overlay(alignment: .topLeading) { milestoneBadge }
                    .overlay { heartPopOverlay }
                    .overlay(alignment: .topTrailing) {
                        if pageCount > 1 {
                            Text("\(min(cardIndex + 1, pageCount))/\(pageCount)")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).frame(height: 22)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(10)
                                .accessibilityHidden(true)   // 시각 전용 페이지 표시(사진 라벨이 장수 안내)
                        }
                    }
                } else if isMilestone {
                    PhotoPlaceholder(seed: 2, cornerRadius: 0)
                        .frame(height: 200)
                        .clipped()
                        .overlay(alignment: .topLeading) { milestoneBadge }
                }

                actionBar(photo: photos.first)
                captionBlock
            }
        }
        .contextMenu {
            Button { Haptics.light(); showEdit = true } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) { Haptics.warning(); store.deleteDiaryEntry(id: entry.id) } label: {
                Label("기록 삭제", systemImage: "trash")
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullPhoto.map { IdentifiableImage(image: $0) } },
            set: { if $0 == nil { fullPhoto = nil } }
        )) { wrapper in
            FullScreenPhotoView(image: wrapper.image, onClose: { fullPhoto = nil })
        }
        .sheet(isPresented: $showComments) {
            DiaryCommentSheet(entryId: entry.id, authorName: child.name)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showEdit) {
            DiaryEditSheet(entry: entry)
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
                Button { Haptics.light(); showEdit = true } label: {
                    Label("수정", systemImage: "pencil")
                }
                Button(role: .destructive) { Haptics.warning(); store.deleteDiaryEntry(id: entry.id) } label: {
                    Label("기록 삭제", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColors.ink3)
                    .frame(width: 44, height: 44)   // 44pt 터치 타깃
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("기록 메뉴 — 수정·삭제")
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
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(liked ? Color(hex: 0xE8607A) : AppColors.ink)
                    .scaleEffect(heartPop ? 1.25 : 1.0)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(liked ? "좋아요 취소" : "좋아요")

            Button { showComments = true } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(AppColors.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("댓글")

            if let photo {
                ShareLink(item: Image(uiImage: photo),
                          preview: SharePreview("\(child.name) 기록", image: Image(uiImage: photo))) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(AppColors.ink)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("공유")
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 0)
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
                .background(.black.opacity(0.12), in: Capsule())
                .padding(12)
                .accessibilityLabel("이정표: \(milestone)")
        }
    }

    @ViewBuilder
    private var heartPopOverlay: some View {
        // reduceMotion이면 90pt 스프링 팝을 생략(전정장애 배려). 좋아요 자체는 정상 동작.
        if heartPop && !reduceMotion {
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
        if store.isDiaryLiked(entry.id) && !reduceMotion {
            // 앱 공통 보상 모션 토큰(Motion.reward)으로 다른 축하와 질감 통일
            withAnimation(Motion.reward) { heartPop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(Motion.micro) { heartPop = false }
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
                            ForEach(Array(comments.enumerated()), id: \.offset) { idx, c in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("나").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink)
                                    Text(c).font(.system(size: 14)).foregroundStyle(AppColors.ink)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteComment(entryId: entryId, at: idx)
                                        Haptics.light()
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
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

// MARK: - 기록 수정 시트

// 캡션·이정표만 수정 (사진/영상은 유지).
private struct DiaryEditSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let entry: DiaryEntry
    @State private var caption: String
    @State private var milestone: String

    init(entry: DiaryEntry) {
        self.entry = entry
        _caption = State(initialValue: entry.content ?? "")
        _milestone = State(initialValue: entry.milestone ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    field(title: "캡션", placeholder: "오늘의 이야기를 적어보세요…", text: $caption, lines: 4)
                    field(title: "이정표 (선택)", placeholder: "예: 첫 걸음마", text: $milestone, lines: 1)

                    LiquidButton(action: save) {
                        Text("저장")
                    }
                    .padding(.top, Spacing.s2)

                    Text("사진과 동영상은 그대로 유지돼요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                        .frame(maxWidth: .infinity)
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func field(title: String, placeholder: String, text: Binding<String>, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.ink2)
            TextField(placeholder, text: text, axis: .vertical)
                .font(AppFont.body)
                .lineLimit(lines, reservesSpace: lines > 1)
                .foregroundStyle(AppColors.ink)
                .padding(Spacing.s3)
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }

    private func save() {
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMilestone = milestone.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateDiaryEntry(
            id: entry.id,
            content: trimmedCaption.isEmpty ? nil : trimmedCaption,
            milestone: trimmedMilestone.isEmpty ? nil : trimmedMilestone
        )
        Haptics.success()
        dismiss()
    }
}
