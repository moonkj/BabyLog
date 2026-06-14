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
    /// ⭐ 즐겨찾기만 모아보기 토글.
    @State private var favoritesOnly = false
    /// Pro: 가족 피드 반응(하트·댓글) — post.id(=기록 entry.id)로 색인. 프리는 미사용.
    @State private var familyPosts: [String: BLFeedPost] = [:]

    // store에서 실데이터 (일기 + 성장, date 내림차순 통합). 즐겨찾기 필터 시 ⭐ 일기만.
    private var allItems: [(date: Date, item: TimelineItem)] {
        let diaries = store.diaryEntries
            .filter { $0.childId == child.id }
            .filter { !favoritesOnly || store.isDiaryLiked($0.id) }
            .map { (date: $0.date, item: TimelineItem.diary($0)) }
        // 성장 기록은 즐겨찾기 대상이 아니므로 필터 시 제외.
        let growth = favoritesOnly ? [] : store.growthRecords
            .filter { $0.childId == child.id }
            .map { (date: $0.date, item: TimelineItem.growth($0)) }
        return (diaries + growth).sorted { $0.date > $1.date }
    }

    private var totalCount: Int { allItems.count }
    /// 이 아이의 즐겨찾기(⭐) 일기 수 — 필터 칩 노출 여부·배지 수.
    private var favoriteCount: Int {
        store.diaryEntries.filter { $0.childId == child.id && store.isDiaryLiked($0.id) }.count
    }
    /// 필터와 무관한 전체 기록 유무 — '첫 기록' 빈 상태 판단용.
    private var hasAnyRecords: Bool {
        store.diaryEntries.contains { $0.childId == child.id }
            || store.growthRecords.contains { $0.childId == child.id }
    }

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
        if !hasAnyRecords {
            BLEmptyState(
                icon: "book.closed.fill",
                title: "첫 기록을 남겨볼까요?",
                message: "\(child.name)의 소중한 순간을\n하나씩 담아보세요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                if favoriteCount > 0 { filterBar }
                if allItems.isEmpty {
                    // 즐겨찾기 필터인데 결과가 비어있을 때(전체엔 기록 있음)
                    BLEmptyState(
                        icon: "star",
                        title: "즐겨찾기한 기록이 없어요",
                        message: "사진의 ⭐를 눌러 베스트 순간을 모아보세요."
                    )
                } else {
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
                                    DiaryTimelineCard(entry: e, child: child,
                                                      familyPost: familyPosts[e.id.uuidString])
                                }
                            }
                        }
                    }
                    // 하단 안내
                    Text(favoritesOnly
                         ? "\(child.name)의 즐겨찾기 \(totalCount)개 💛"
                         : "\(child.name)의 \(totalCount)개 순간이 기록되었어요 💛")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Spacing.s2)
                }
            }
            // Pro: 가족 피드 반응 로드(기록↔포스트 id 매칭). isPro 토글·공유 완료 시 재로드.
            .task(id: "\(store.isPro)_\(store.familyFeedVersion)") { await loadFamilySocial() }
        }
    }

    private func loadFamilySocial() async {
        guard store.isPro, AuthStore.shared.isLoggedIn else { familyPosts = [:]; return }
        familyPosts = await FamilyFeedBackend.fetchFamilySocial()
    }

    // ⭐ 즐겨찾기 필터 칩 — 전체 / 즐겨찾기 N (즐겨찾기가 1개 이상일 때만 노출)
    private var filterBar: some View {
        HStack(spacing: Spacing.s2) {
            filterPill(title: "전체", icon: nil, active: !favoritesOnly,
                       tint: AppColors.primary) { favoritesOnly = false }
            filterPill(title: "즐겨찾기 \(favoriteCount)", icon: "star.fill", active: favoritesOnly,
                       tint: AppColors.gold) { favoritesOnly = true }
            Spacer(minLength: 0)
        }
    }

    private func filterPill(title: String, icon: String?, active: Bool,
                            tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            withAnimation(.easeInOut(duration: 0.18)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title).font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(active ? .white : AppColors.ink2)
            .padding(.horizontal, 14).frame(height: 34)
            .background(active ? tint : AppColors.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 보기")
        .accessibilityAddTraits(active ? [.isSelected] : [])
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
    @State private var showDeleteConfirm = false
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
                Haptics.light(); showDeleteConfirm = true
            } label: {
                Label("기록 삭제", systemImage: "trash")
            }
        }
        .confirmationDialog("이 성장 기록을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { Haptics.warning(); store.deleteGrowthRecord(id: record.id) }
            Button("취소", role: .cancel) {}
        } message: {
            Text("키·몸무게 기록이 삭제돼요. 되돌릴 수 없어요.")
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
    /// Pro: 이 기록과 연결된 가족 피드 포스트(하트·댓글). 프리/미공유면 nil → 소셜 미표시.
    var familyPost: BLFeedPost? = nil
    @State private var showComments = false
    @State private var showEdit = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heartPop = false
    @State private var cardIndex = 0
    @State private var fullPhoto: UIImage? = nil
    // 가족 소셜(서버) — 부모가 넘긴 familyPost를 받아 로컬에서 하트·댓글 후 즉시 갱신.
    @State private var fpost: BLFeedPost? = nil
    @State private var commentDraft = ""
    @State private var sharing = false
    @State private var showLoginForShare = false
    @State private var shareError: String?
    @State private var showDeleteConfirm = false

    private var isMilestone: Bool { entry.milestone != nil }
    private var liked: Bool { store.isDiaryLiked(entry.id) }
    private var commentCount: Int { store.comments(for: entry.id).count }
    private var hasPhoto: Bool { !entry.photoRefList.isEmpty }
    /// 이 기록을 가족에 공유했거나(서버) 공유 진행 중(낙관적 표시).
    private var sharedIntent: Bool { store.sharedFeedEntryIds.contains(entry.id.uuidString) }
    /// Pro 모드 + 이 기록이 가족에 공유됨 → 가족 하트·댓글 표시.
    private var showsFamilySocial: Bool { store.isPro && fpost != nil }
    /// Pro 모드에서 카드 하단에 가족 UI(하트·댓글/공유중/공유하기)가 보이는지 — 패딩 조절용.
    private var showsAnyFamilyUI: Bool { store.isPro && (fpost != nil || hasPhoto) }

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
                familySocialBlock
            }
        }
        .onAppear { if fpost == nil { fpost = familyPost } }
        .onChange(of: familyPost) { _, new in if new != nil { fpost = new } }
        // 배치(familyPosts)가 아직 못 잡은 기록은 카드가 자기 id로 직접 확인 — 자동공유 직후 반영 보장.
        // 공유 완료 시 store.familyFeedVersion이 증가 → 이 task 재실행 → 새 포스트를 잡아 버튼→하트로 전환.
        .task(id: store.familyFeedVersion) {
            guard store.isPro, AuthStore.shared.isLoggedIn, hasPhoto, familyPost == nil else { return }
            if let p = await FamilyFeedBackend.fetchPost(postId: entry.id.uuidString) { fpost = p }
        }
        .contextMenu {
            Button { Haptics.light(); showEdit = true } label: {
                Label("수정", systemImage: "pencil")
            }
            Button(role: .destructive) { Haptics.light(); showDeleteConfirm = true } label: {
                Label("기록 삭제", systemImage: "trash")
            }
        }
        .fullScreenCover(item: Binding(
            get: { fullPhoto.map { IdentifiableImage(image: $0) } },
            set: { if $0 == nil { fullPhoto = nil } }
        )) { wrapper in
            FullScreenPhotoView(image: wrapper.image, onClose: { fullPhoto = nil })
        }
        .alert("가족과 공유", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(shareError ?? "") }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteRecord() }
            Button("취소", role: .cancel) {}
        } message: {
            Text(showsFamilySocial || sharedIntent
                 ? "사진·메모가 삭제되고 가족 보관함에서도 사라져요. 되돌릴 수 없어요."
                 : "사진·메모가 삭제되며 되돌릴 수 없어요.")
        }
        .sheet(isPresented: $showLoginForShare) {
            VStack(spacing: Spacing.s4) {
                Image(systemName: "person.2.fill").font(.system(size: 34))
                    .foregroundStyle(AppColors.primary).padding(.top, Spacing.s6)
                Text("로그인하고 가족과 공유").font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("로그인하면 이 기록을 가족과 함께 보고\n하트·댓글을 받을 수 있어요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
                AppleSignInButton { ok in
                    if ok { showLoginForShare = false; Task { await shareThisRecord() } }
                }
                .frame(height: 50).padding(.horizontal, Spacing.s5)
                Spacer()
            }
            .frame(maxWidth: .infinity).background(AppColors.canvas)
            .presentationDetents([.height(300)])
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
                Button(role: .destructive) { Haptics.light(); showDeleteConfirm = true } label: {
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
            // 무료=혼자 보는 저널 → 하트(소셜) 대신 즐겨찾기(⭐). 베스트 사진 선별·회고용.
            // (가족 하트·댓글은 Pro 가족 피드에서 — SPEC 값 사다리.)
            Button { likeWithPop() } label: {
                Image(systemName: liked ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(liked ? AppColors.gold : AppColors.ink)
                    .scaleEffect(heartPop ? 1.25 : 1.0)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(liked ? "즐겨찾기 해제" : "즐겨찾기")

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
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                    Text("즐겨찾기에 담음")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                }
            }
            if let content = entry.content, !content.isEmpty {
                (Text(child.name).font(.system(size: 14, weight: .bold))
                 + Text("  ") + Text(content).font(.system(size: 14)))
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, showsAnyFamilyUI ? 6 : 14)
    }

    // Pro 가족 소셜 — 공유됨이면 하트·댓글, 사진 있는데 미공유면 '가족과 공유하기'. 프리엔 미표시.
    @ViewBuilder
    private var familySocialBlock: some View {
        if store.isPro {
            if fpost != nil {
                sharedSocialView
            } else if sharedIntent, hasPhoto {
                sharingPlaceholder           // 공유 직후 업로드 중 — 즉시 '공유 중' 표시
            } else if hasPhoto {
                shareToFamilyBar
            }
        }
    }

    // 공유 직후(업로드 진행 중) — 등록과 동시에 '가족과 공유 중'을 보여 버튼이 깜빡이지 않게.
    private var sharingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.line)
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("가족과 공유 중…").font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColors.ink2)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "person.2.fill").font(.system(size: 10))
                    Text("가족 보관함").font(.system(size: 11, weight: .semibold))
                }.foregroundStyle(AppColors.ink3)
            }
            .frame(minHeight: 40)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    // 사진 있는데 아직 가족 피드에 없음 → 한 번에 공유(연결 id = entry.id).
    private var shareToFamilyBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(AppColors.line)
            Button {
                if AuthStore.shared.isLoggedIn { Task { await shareThisRecord() } }
                else { showLoginForShare = true }
            } label: {
                HStack(spacing: 6) {
                    if sharing { ProgressView().controlSize(.small).tint(AppColors.primary) }
                    else { Image(systemName: "person.2.fill").font(.system(size: 14)) }
                    Text(sharing ? "공유 중…" : "가족과 공유하기")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppColors.primary)
                .frame(minHeight: 40)
            }
            .disabled(sharing)
            .accessibilityHint("이 기록을 가족 보관함에 올려 함께 하트·댓글을 남길 수 있어요")
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var sharedSocialView: some View {
        if let p = fpost {
            let myUid = AuthStore.shared.userId
            let famLiked = myUid != nil && p.reactions.contains { $0.uid == myUid }
            VStack(alignment: .leading, spacing: 8) {
                Divider().overlay(AppColors.line)
                HStack(spacing: 18) {
                    Button { Task { await toggleFamilyHeart() } } label: {
                        HStack(spacing: 5) {
                            Image(systemName: famLiked ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundStyle(famLiked ? Color(hex: 0xE8607A) : AppColors.ink)
                            Text("\(p.reactions.count)").font(AppFont.num(13)).foregroundStyle(AppColors.ink2)
                        }
                    }.buttonStyle(.plain)
                    .accessibilityLabel(famLiked ? "가족 좋아요 취소" : "가족 좋아요")
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.right").font(.system(size: 19)).foregroundStyle(AppColors.ink)
                        Text("\(p.comments.count)").font(AppFont.num(13)).foregroundStyle(AppColors.ink2)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill").font(.system(size: 10))
                        Text("가족과 공유중").font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(AppColors.ink3)
                    .accessibilityLabel("가족과 공유중")
                }
                // 가족 댓글 목록
                ForEach(p.comments) { c in
                    (Text(c.authorName).font(.system(size: 13, weight: .bold))
                     + Text("  ") + Text(c.text).font(.system(size: 13)))
                        .foregroundStyle(AppColors.ink).fixedSize(horizontal: false, vertical: true)
                }
                // 댓글 입력(가족 스레드)
                HStack(spacing: 8) {
                    TextField("댓글 달기…", text: $commentDraft)
                        .font(.system(size: 13)).padding(.horizontal, 12).frame(height: 36)
                        .background(AppColors.surface2, in: Capsule())
                    Button { Task { await sendFamilyComment() } } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24)).foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("댓글 보내기")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }

    private func toggleFamilyHeart() async {
        guard let p = fpost, let myUid = AuthStore.shared.userId else { return }
        let famLiked = p.reactions.contains { $0.uid == myUid }
        Haptics.light()
        if await FamilyFeedBackend.setHeart(post: p, on: !famLiked) {
            fpost = await FamilyFeedBackend.fetchPost(postId: p.id)
        }
    }

    private func sendFamilyComment() async {
        guard let p = fpost else { return }
        let t = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        commentDraft = ""; Haptics.light()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        if await FamilyFeedBackend.addComment(post: p, text: t) {
            fpost = await FamilyFeedBackend.fetchPost(postId: p.id)
        }
    }

    /// 확인 후 삭제 — 로컬 기록 + (공유됐으면) 가족 피드 포스트까지 정리.
    private func deleteRecord() {
        Haptics.warning()
        let pid = entry.id.uuidString
        let wasShared = fpost != nil || sharedIntent
        store.deleteDiaryEntry(id: entry.id)
        store.unmarkFeedShared(pid)
        if wasShared { Task { await FamilyFeedBackend.deletePostFully(postId: pid) } }   // R2 원본까지 제거
    }

    /// 이 기록을 가족 피드에 공유(연결 id = entry.id) — 공유 후 하트·댓글 UI가 열린다.
    private func shareThisRecord() async {
        let imgs = entry.photoRefList.compactMap { PhotoStore.image($0) }
        guard !imgs.isEmpty else { return }
        sharing = true; defer { sharing = false }
        let ok = await FamilyFeedBackend.shareRecordToFamily(
            postId: entry.id.uuidString, images: imgs,
            caption: entry.content, childLabel: child.name)
        if ok {
            Haptics.success()
            fpost = await FamilyFeedBackend.fetchPost(postId: entry.id.uuidString)
        } else {
            Haptics.warning()
            shareError = FamilyFeedBackend.lastError ?? "공유에 실패했어요. 잠시 후 다시 시도해 주세요."
        }
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
            Image(systemName: "star.fill")
                .font(.system(size: 90, weight: .bold))
                .foregroundStyle(AppColors.gold.opacity(0.92))
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
