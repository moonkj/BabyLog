// CrewPostSheets.swift
// BabyLog · Features/Dongne
// 동네 게시판 — 글쓰기 시트 + 글 상세(댓글) 시트
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - CrewPostWriteSheet (글쓰기)

struct CrewPostWriteSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var location = NearbyLocationProvider.shared
    @AppStorage("bl_nickname") private var nickname: String = "양육자님"

    @State private var category: CrewPostCategory = .info
    @State private var title = ""
    @State private var body_ = ""
    @State private var submitting = false        // 서버 전송 중(중복 탭 방지)
    @State private var alertMessage: String? = nil // 서버 전송 실패 안내

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    // 카테고리 선택 — 색+아이콘+레이블 3중 인코딩
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("카테고리").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack(spacing: Spacing.s2) {
                            ForEach(CrewPostCategory.allCases, id: \.self) { c in
                                Button {
                                    Haptics.selection()
                                    category = c
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: c.systemIcon).font(.system(size: 13, weight: .semibold))
                                        Text(c.rawValue).font(.system(size: 13.5, weight: .semibold))
                                    }
                                    .foregroundStyle(category == c ? .white : AppColors.ink2)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(category == c ? AppColors.ink : AppColors.surface2,
                                                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                                }
                                .buttonStyle(LiquidPressStyle(scale: 0.96))
                                .accessibilityLabel(c.rawValue)
                                .accessibilityAddTraits(category == c ? .isSelected : [])
                            }
                        }
                    }

                    // 제목
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("제목").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("이웃에게 전할 제목을 적어주세요", text: $title)
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, Spacing.s4).frame(height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .accessibilityLabel("제목 입력")
                    }

                    // 내용
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("내용 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("자세한 내용을 적어주세요", text: $body_, axis: .vertical)
                            .font(AppFont.body).lineLimit(4...10)
                            .padding(.horizontal, Spacing.s4).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .accessibilityLabel("내용 입력")
                    }

                    LiquidButton(fill: (canSave && !submitting) ? AppColors.primary : AppColors.ink3, action: {
                        guard canSave, !submitting else { return }
                        if SupabaseConfig.isConfigured {
                            // 서버 모드: 목록이 서버 기준이므로 성공을 확인한 뒤에만 닫는다(소리없는 실패 방지)
                            submitting = true
                            let hood = store.selectedDong ?? location.localityName ?? ""
                            let cat = category.rawValue, t = title, b = body_, nm = nickname
                            Task { @MainActor in
                                let ok = await CrewBackend.createPost(hood: hood, category: cat, title: t, body: b, authorName: nm)
                                submitting = false
                                if ok {
                                    store.addCrewPost(category: category, title: title, body: body_)   // 로컬 낙관적 반영
                                    Haptics.success()
                                    dismiss()
                                } else {
                                    Haptics.warning()
                                    alertMessage = "게시하지 못했어요. 잠시 후 다시 시도해 주세요."   // 입력 내용은 유지
                                }
                            }
                        } else {
                            // 미구성: 로컬 즉시 반영(기존 동작 유지)
                            store.addCrewPost(category: category, title: title, body: body_)
                            Haptics.success()
                            dismiss()
                        }
                    }) {
                        Text("게시하기").frame(maxWidth: .infinity)
                    }
                    .disabled(submitting)
                    .padding(.top, Spacing.s2)
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("글쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .alert("게시 실패", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("확인", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }
}

// MARK: - CrewPostDetailSheet (글 상세 + 댓글)

struct CrewPostDetailSheet: View {
    let post: CrewPost

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var commentText = ""
    @State private var commentError = false   // 댓글 전송 실패(서버) — 다시 입력하면 자동 해제
    @State private var lastFailedComment = "" // 실패 시 복원된 본문 — onChange가 오류를 즉시 지우는 것 방지
    @State private var showLogin = false      // 로그인 게이트(좋아요·댓글)
    @State private var showDeleteConfirm = false
    @State private var deleteBusy = false     // 삭제 요청 중(중복 탭 방지)
    @State private var deleteFailed = false   // 서버 삭제 실패 안내
    /// 서버 공유 댓글(미구성/미로드 시 nil → 로컬 폴백)
    @State private var serverComments: [String]? = nil
    @AppStorage("bl_nickname") private var nickname: String = "양육자님"

    private var isLiked: Bool { store.isCrewPostLiked(post.id) }
    private var likeCount: Int { post.likeCount + (isLiked ? 1 : 0) }
    private var comments: [String] { serverComments ?? store.crewPostCommentList(postId: post.id) }
    private var replyCount: Int {
        serverComments?.count ?? (SupabaseConfig.isConfigured ? post.replyCount : store.crewPostReplyCount(post))
    }

    /// 댓글 폴링(상세 열려 있는 동안 3초 주기, 닫히면 task 취소, 백그라운드면 건너뜀).
    private func pollReplies() async {
        guard SupabaseConfig.isConfigured else { return }
        while !Task.isCancelled {
            if scenePhase == .active,
               let r = await CrewBackend.fetchReplies(postId: post.id) { serverComments = r }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }

    private func sendComment() {
        guard LoginGate.ready() else { showLogin = true; return }   // 로그인 필수
        let text = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        commentText = ""
        commentError = false
        Haptics.light()
        if SupabaseConfig.isConfigured {
            Task { @MainActor in
                let ok = await CrewBackend.addReply(postId: post.id, body: text, authorName: nickname)
                if ok {
                    if let r = await CrewBackend.fetchReplies(postId: post.id) { serverComments = r }
                } else {
                    // 실패 — 입력 내용을 되돌려 다시 보낼 수 있게 한다(소리없는 실패 방지)
                    // 복원 자체가 onChange를 발화시켜 오류 표시를 바로 지우므로, 복원값을 기억해 onChange에서 구분한다.
                    lastFailedComment = text
                    commentText = text
                    commentError = true
                    Haptics.warning()
                }
            }
        } else {
            store.addCrewPostComment(postId: post.id, text: text)
        }
    }

    private func toggleLike() {
        guard LoginGate.ready() else { showLogin = true; return }   // 로그인 필수
        Haptics.selection()
        let willLike = !isLiked
        store.toggleCrewPostLike(post.id)   // 낙관적 반영
        if SupabaseConfig.isConfigured {
            Task { @MainActor in
                let ok = await CrewBackend.setPostLike(postId: post.id, like: willLike)
                if !ok { store.toggleCrewPostLike(post.id) }   // 실패 시 롤백
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        postBody
                        Divider().overlay(AppColors.line)
                        commentsSection

                        // 새 댓글로 자동 스크롤하기 위한 하단 앵커
                        Color.clear
                            .frame(height: 1)
                            .id("BOTTOM")
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s4)
                    .padding(.bottom, 16)
                }
                .onChange(of: comments.count) { _ in
                    withAnimation { proxy.scrollTo("BOTTOM", anchor: .bottom) }
                }
            }

            inputBar
        }
        .background(AppColors.canvas)
        .accessibilityElement(children: .contain)
        .task(id: post.id) { await pollReplies() }
        .confirmationDialog("이 글을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                guard !deleteBusy else { return }
                if SupabaseConfig.isConfigured {
                    // 서버가 원본: 실제 삭제를 확인한 뒤에만 로컬 삭제·닫기(재조회 시 부활 방지)
                    deleteBusy = true
                    Task { @MainActor in
                        let ok = await CrewBackend.deletePost(postId: post.id)
                        deleteBusy = false
                        if ok {
                            store.deleteCrewPost(id: post.id)
                            Haptics.success()
                            dismiss()
                        } else {
                            Haptics.warning()
                            deleteFailed = true
                        }
                    }
                } else {
                    // 미구성(로컬 데모): 기존 동작 유지
                    store.deleteCrewPost(id: post.id)
                    Haptics.success()
                    dismiss()
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제한 글은 복구할 수 없어요.")
        }
        .alert("삭제 실패", isPresented: $deleteFailed) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("글을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        .sheet(isPresented: $showLogin) {
            AppleLoginSheet(message: "좋아요·댓글은 로그인이 필요해요.") {}
        }
    }

    // MARK: 헤더
    private var header: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)
                .accessibilityHidden(true)

            HStack {
                Text("동네 게시판")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                Spacer()
                if post.mine {
                    Button {
                        Haptics.light()
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(AppColors.danger)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("글 삭제")
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("닫기")
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s3)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppColors.line).frame(height: 1)
        }
    }

    // MARK: 본문
    private var postBody: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: 6) {
                BLBadge(
                    tone: post.category.badgeTone,
                    text: post.category.rawValue,
                    systemIcon: post.category.systemIcon,
                    dot: false
                )
                Text("\(post.authorName) · \(post.timeText)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
            }

            Text(post.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !post.body.isEmpty {
                Text(post.body)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 좋아요 + 댓글 수
            HStack(spacing: 14) {
                Button {
                    toggleLike()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 15))
                            .foregroundStyle(isLiked ? AppColors.danger : AppColors.ink3)
                        Text("\(likeCount)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .padding(.horizontal, Spacing.s3).frame(height: 44)
                    .background(AppColors.surface2, in: Capsule())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.94))
                .accessibilityLabel(isLiked ? "좋아요 취소, 현재 \(likeCount)개" : "좋아요, 현재 \(likeCount)개")

                HStack(spacing: 5) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.ink3)
                    Text("\(replyCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                }
                .padding(.horizontal, Spacing.s3).frame(height: 44)
                .background(AppColors.surface2, in: Capsule())
                .accessibilityLabel("댓글 \(replyCount)개")

                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
    }

    // MARK: 댓글
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("댓글 \(comments.count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.ink)

            if comments.isEmpty {
                Text("첫 댓글을 남겨 이웃과 이야기를 시작해보세요.")
                    .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.s5)
            } else {
                ForEach(Array(comments.enumerated()), id: \.offset) { _, text in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(AppColors.surface3)
                            .frame(width: 30, height: 30)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppColors.ink3)
                            }
                            .accessibilityHidden(true)
                        Text(text)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AppColors.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("댓글: \(text)")
                }
            }
        }
    }

    // MARK: 입력 바
    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            if commentError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .accessibilityHidden(true)
                    Text("댓글을 보내지 못했어요. 다시 시도해 주세요.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppColors.danger)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("댓글을 보내지 못했어요. 다시 시도해 주세요.")
            }

            HStack(spacing: 10) {
                TextField("댓글을 입력하세요", text: $commentText, axis: .vertical)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1...4)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(commentError ? AppColors.danger : AppColors.line, lineWidth: 1) }
                    .onChange(of: commentText) { newValue in
                        // 다시 입력하면 오류 해제 — 단, 실패 직후 복원된 값과 같으면 유지(오류 깜빡임 방지)
                        if commentError && newValue != lastFailedComment { commentError = false }
                    }
                    .accessibilityLabel("댓글 입력")

                Button {
                    sendComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.ink3 : AppColors.primary)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(width: 44, height: 44)
                .accessibilityLabel("댓글 등록")
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(AppColors.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(AppColors.line).frame(height: 1)
        }
    }
}
