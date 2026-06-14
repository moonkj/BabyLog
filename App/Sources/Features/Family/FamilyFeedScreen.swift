// FamilyFeedScreen.swift
// BabyLog — Pro 가족 피드 UI(클라우드 가족 보관함).
// 로그인 → 가족 생성/참여 → 사진 포스트·하트·댓글(양방향). 무료 미노출(AppFeatures.proFamilyFeed).
// 이미지는 R2 공개 베이스(Secrets R2_PUBLIC_BASE, CDN/r2.dev 연결 후 점등) + 키로 구성.

import SwiftUI

struct FamilyFeedScreen: View {
    @ObservedObject private var auth = AuthStore.shared
    @EnvironmentObject private var store: AppStore

    @State private var family: BLFamily?
    @State private var posts: [BLFeedPost] = []
    @State private var loading = true
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var pendingDelete: BLFeedPost?   // 본인 사진 삭제 확인

    private var myUid: String? { auth.userId }
    /// R2 공개 베이스(앱이 키로 이미지 URL 구성). 미설정이면 플레이스홀더.
    private var publicBase: String? { APIConfig.key("R2_PUBLIC_BASE") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                BLScreenHeader(title: "가족 보관함", eyebrow: "Pro · 함께 보는 피드")
                content
            }
            .padding(.horizontal, Spacing.s5).padding(.top, Spacing.s2).padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .alert("가족 보관함", isPresented: Binding(get: { errorMsg != nil }, set: { if !$0 { errorMsg = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(errorMsg ?? "") }
        .confirmationDialog("이 사진을 가족 보관함에서 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible, presenting: pendingDelete) { post in
            Button("삭제", role: .destructive) { Task { await deletePost(post) } }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("가족 모두의 보관함에서 사라지고 하트·댓글도 함께 삭제돼요. 되돌릴 수 없어요.")
        }
    }

    @ViewBuilder private var content: some View {
        if !SupabaseConfig.isConfigured {
            BLEmptyState(icon: "icloud.slash", title: "서버 미구성", message: "백엔드 설정이 필요해요.")
        } else if !auth.isLoggedIn {
            BLCard {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("가족과 함께 보려면 로그인하세요")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                    Text("로그인하면 가족 보관함을 만들고, 조부모님을 초대해 함께 사진을 보고 반응할 수 있어요.")
                        .font(.system(size: 13)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)
                    AppleSignInButton { ok in if ok { Task { await load() } } }
                }
            }
        } else if loading {
            ProgressView().frame(maxWidth: .infinity).padding(.top, Spacing.s7)
        } else if family == nil {
            createFamilyCard
        } else {
            if posts.isEmpty {
                BLEmptyState(icon: "photo.on.rectangle.angled", title: "기록하면 여기 모여요",
                             message: "기록 탭에서 사진을 올리면 가족 보관함에 자동으로 공유돼요. 가족이 하트·댓글로 함께해요.")
            } else {
                ForEach(posts) { post in postCard(post) }
            }
        }
    }

    private var createFamilyCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("가족 보관함 만들기").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("우리 가족만의 비공개 공간을 만들어요. 만든 뒤 조부모님을 초대할 수 있어요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { busy = true; family = await FamilyFeedBackend.createFamily(name: "우리 가족"); busy = false
                        if family == nil { errorMsg = FamilyFeedBackend.lastError ?? "만들지 못했어요. 잠시 후 다시 시도해 주세요." } else { await load() } }
                } label: {
                    Text(busy ? "만드는 중…" : "가족 보관함 만들기")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }.buttonStyle(LiquidPressStyle(scale: 0.98)).disabled(busy)
            }
        }
    }

    private func postCard(_ post: BLFeedPost) -> some View {
        let liked = myUid != nil && post.reactions.contains { $0.uid == myUid }
        return BLCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // 사진 — 자연 비율로 전체 표시(잘림 방지). 세로/가로 사진 모두 통째로 보임.
                if let key = post.media.first?.r2Key, let base = publicBase,
                   let url = URL(string: "\(base)/\(key)") {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit().frame(maxWidth: .infinity)
                        case .empty:
                            ZStack { Rectangle().fill(AppColors.surface2); ProgressView() }.frame(height: 280)
                        default:
                            Rectangle().fill(AppColors.surface2).frame(height: 280)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surface2)
                } else {
                    ZStack {
                        Rectangle().fill(AppColors.surface2).frame(height: 200)
                        VStack(spacing: 6) {
                            Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(AppColors.ink3)
                            Text("사진 표시 준비 중 (CDN 연결 필요)").font(AppFont.caption).foregroundStyle(AppColors.ink3)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    HStack(spacing: Spacing.s4) {
                        Button { Task { await toggleHeart(post, to: !liked) } } label: {
                            HStack(spacing: 4) {
                                Image(systemName: liked ? "heart.fill" : "heart")
                                    .foregroundStyle(liked ? Color(hex: 0xE8607A) : AppColors.ink)
                                Text("\(post.reactions.count)").font(AppFont.num(13)).foregroundStyle(AppColors.ink2)
                            }
                        }.buttonStyle(.plain)
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right").foregroundStyle(AppColors.ink)
                            Text("\(post.comments.count)").font(AppFont.num(13)).foregroundStyle(AppColors.ink2)
                        }
                        Spacer()
                        // 올린 본인만 삭제 가능
                        if post.authorUid == myUid {
                            Menu {
                                Button(role: .destructive) { pendingDelete = post } label: {
                                    Label("사진 삭제", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColors.ink3)
                                    .frame(width: 32, height: 32)
                            }
                            .accessibilityLabel("사진 옵션")
                        }
                    }
                    if let cap = post.caption, !cap.isEmpty {
                        Text(cap).font(.system(size: 14)).foregroundStyle(AppColors.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(post.comments) { c in
                        (Text(c.authorName).font(.system(size: 13, weight: .bold))
                         + Text("  ") + Text(c.text).font(.system(size: 13)))
                            .foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    CommentField { text in Task { await addComment(post, text) } }
                }
                .padding(Spacing.s3)
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard SupabaseConfig.isConfigured, auth.isLoggedIn else { loading = false; return }
        loading = true
        family = await FamilyFeedBackend.myFamily()
        if let f = family { posts = await FamilyFeedBackend.fetchFeed(familyId: f.id) }
        loading = false
    }

    private func toggleHeart(_ post: BLFeedPost, to on: Bool) async {
        if await FamilyFeedBackend.setHeart(post: post, on: on), let f = family {
            posts = await FamilyFeedBackend.fetchFeed(familyId: f.id)
        }
    }

    private func addComment(_ post: BLFeedPost, _ text: String) async {
        if await FamilyFeedBackend.addComment(post: post, text: text), let f = family {
            posts = await FamilyFeedBackend.fetchFeed(familyId: f.id)
        }
    }

    /// 본인이 올린 가족 보관함 사진 삭제 — DB 삭제(미디어·하트·댓글 FK cascade) + 로컬 공유표시 해제.
    private func deletePost(_ post: BLFeedPost) async {
        busy = true; defer { busy = false }
        if await FamilyFeedBackend.deletePost(postId: post.id) {
            posts.removeAll { $0.id == post.id }
            store.unmarkFeedShared(post.id)        // 기록 카드의 '공유 중' 표시 해제
            store.familyFeedVersion &+= 1          // 기록 탭 카드들 재조회 트리거
        } else {
            errorMsg = "삭제하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

// 댓글 입력 한 줄
private struct CommentField: View {
    var onSubmit: (String) -> Void
    @State private var text = ""
    var body: some View {
        HStack(spacing: Spacing.s2) {
            TextField("댓글 달기…", text: $text)
                .font(.system(size: 13)).padding(.horizontal, Spacing.s3).frame(height: 38)
                .background(AppColors.surface2, in: Capsule())
            Button {
                let t = text; text = ""
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                if !t.trimmingCharacters(in: .whitespaces).isEmpty { onSubmit(t) }
            } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 26)).foregroundStyle(AppColors.primary) }
        }
        .padding(.top, 2)
    }
}
