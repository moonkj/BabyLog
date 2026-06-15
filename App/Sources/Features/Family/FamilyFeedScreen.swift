// FamilyFeedScreen.swift
// BabyLog — Pro 가족 피드 UI(클라우드 가족 보관함).
// 로그인 → 가족 생성/참여 → 사진 포스트·하트·댓글(양방향). 무료 미노출(AppFeatures.proFamilyFeed).
// 이미지는 R2 공개 베이스(Secrets R2_PUBLIC_BASE, CDN/r2.dev 연결 후 점등) + 키로 구성.

import SwiftUI
import UIKit

struct FamilyFeedScreen: View {
    @ObservedObject private var auth = AuthStore.shared
    @EnvironmentObject private var store: AppStore

    @State private var family: BLFamily?
    @State private var posts: [BLFeedPost] = []
    @State private var loading = true
    @State private var busy = false
    @State private var errorMsg: String?
    @State private var pendingDelete: BLFeedPost?   // 본인 사진 삭제 확인
    @State private var creatingInvite = false
    @State private var inviteSheet: InviteInfo?     // 초대 링크 공유 시트
    @State private var showJoinSheet = false        // 초대코드+비번 참여 시트
    @State private var members: [BLFamilyMember] = []  // 가족 관리(주인) 멤버 목록
    @State private var loadingMembers = false
    @State private var pendingRemove: BLFamilyMember?  // 멤버 내보내기 확인
    @State private var pendingMembers: [BLFamilyMember] = []  // 승인 대기(주인) 목록
    @State private var myApproved: Bool? = nil          // 비주인 본인 승인 상태(nil=확인 전)

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
        .alert("이 사진을 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
        ), presenting: pendingDelete) { post in
            Button("삭제", role: .destructive) { Task { await deletePost(post) } }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("가족 모두의 보관함에서 사라지고 하트·댓글도 함께 삭제돼요. 되돌릴 수 없어요.")
        }
        .sheet(item: $inviteSheet) { info in InviteShareSheet(info: info) }
        .sheet(isPresented: $showJoinSheet) {
            JoinFamilySheet { code, pass in
                let name = UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님"
                if await FamilyFeedBackend.joinFamily(code: code, name: name, pass: pass) != nil {
                    await load()
                    return true
                } else {
                    errorMsg = FamilyFeedBackend.lastError ?? "참여하지 못했어요. 잠시 후 다시 시도해 주세요."
                    return false
                }
            }
        }
        .alert("이 가족 구성원을 내보낼까요?", isPresented: Binding(
            get: { pendingRemove != nil }, set: { if !$0 { pendingRemove = nil } }
        ), presenting: pendingRemove) { member in
            Button("내보내기", role: .destructive) { Task { await removeMember(member) } }
            Button("취소", role: .cancel) {}
        } message: { member in
            Text("‘\(member.displayName)’님이 가족 보관함에서 나가게 돼요. 다시 들어오려면 초대가 필요해요.")
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
            joinFamilyCard       // 초대코드+비번으로 기존 가족 합류
        } else if family?.ownerUid != myUid && myApproved == false {
            // 비주인 + 미승인(대기) — 피드를 숨기고 승인 대기 안내만 표시.
            waitingApprovalCard
        } else {
            if family?.ownerUid == myUid {
                manageCard        // 주인: 가족 관리(승인 대기·멤버 목록·내보내기·초대)
            } else {
                inviteRow         // 승인된 멤버: 조부모 초대 링크만
            }
            if posts.isEmpty {
                BLEmptyState(icon: "photo.on.rectangle.angled", title: "기록하면 여기 모여요",
                             message: "기록 탭에서 사진을 올리면 가족 보관함에 자동으로 공유돼요. 가족이 하트·댓글로 함께해요.")
            } else {
                ForEach(posts) { post in postCard(post) }
            }
        }
    }

    /// 조부모 초대 — 코드 생성 후 공유 링크 시트. 안드로이드/아이폰 모두 브라우저로 합류.
    private var inviteRow: some View {
        Button {
            guard let f = family, !creatingInvite else { return }
            Task {
                creatingInvite = true
                if let code = await FamilyFeedBackend.createInvite(familyId: f.id),
                   let url = URL(string: Self.inviteLink(code: code)) {
                    inviteSheet = InviteInfo(url: url, code: code, familyId: f.id, defaultPass: Self.genPin())
                } else {
                    errorMsg = FamilyFeedBackend.lastError ?? "초대 링크를 만들지 못했어요. 잠시 후 다시 시도해 주세요."
                }
                creatingInvite = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                Text(creatingInvite ? "만드는 중…" : "조부모님 및 가족 초대하기")
                Spacer()
                Image(systemName: "square.and.arrow.up").foregroundStyle(AppColors.ink3)
            }
            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.primary)
            .padding(.horizontal, Spacing.s4).frame(height: 50)
            .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .disabled(creatingInvite)
        .accessibilityLabel("조부모님 초대 링크 만들기")
    }

    /// 승인 대기 안내(비주인·미승인) — 피드 대신 표시. 당겨서 새로고침으로 재확인.
    private var waitingApprovalCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.primarySoft, in: Circle())
                    Text("승인 대기 중이에요")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColors.ink)
                }
                Text("가족 주인이 승인하면 사진을 볼 수 있어요. 주인에게 승인을 부탁해 주세요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)
                Text("당겨서 새로고침하면 다시 확인해요.")
                    .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
            }
        }
    }

    /// 초대 링크 — 배포한 가족 웹(FAMILY_WEB_BASE) + ?invite=코드.
    static func inviteLink(code: String) -> String {
        var base = APIConfig.key("FAMILY_WEB_BASE") ?? "https://babylog-family.pages.dev/family/"
        if !base.hasSuffix("/") { base += "/" }
        return "\(base)?invite=\(code)"
    }

    /// 기본 비밀번호 생성(숫자 6자리). 부모가 4~10자리로 바꿀 수 있음.
    static func genPin() -> String { (0..<6).map { _ in String(Int.random(in: 0...9)) }.joined() }

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

    /// 기존 가족에 합류 — 초대코드+비밀번호로 입장(가족이 없을 때 노출).
    private var joinFamilyCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("이미 만든 가족에 참여하기").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("가족이 알려준 초대 코드와 비밀번호로 들어오세요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)
                Button { showJoinSheet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.badge.key")
                        Text("가족 참여하기")
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }.buttonStyle(LiquidPressStyle(scale: 0.98))
            }
        }
    }

    /// 가족 관리(주인) — 승인 대기·멤버 목록·내보내기 + 조부모 초대.
    private var manageCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("가족 관리").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                if !pendingMembers.isEmpty {
                    Text("승인 대기 \(pendingMembers.count)")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.primary)
                    VStack(spacing: 0) {
                        ForEach(Array(pendingMembers.enumerated()), id: \.element.id) { idx, m in
                            if idx > 0 { Divider() }
                            pendingRow(m)
                        }
                    }
                    Divider().padding(.vertical, 2)
                }
                if loadingMembers {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.s2)
                } else if members.isEmpty {
                    Text("아직 구성원이 없어요.").font(.system(size: 13)).foregroundStyle(AppColors.ink3)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { idx, m in
                            if idx > 0 { Divider() }
                            memberRow(m)
                        }
                    }
                }
                inviteRow   // 조부모(안드로이드/아이폰) 초대 링크
            }
        }
        .task { await loadMembers() }
    }

    /// 승인 대기 한 행 — 이름·역할 + [승인]·[거절]. 승인=approveMember, 거절=removeMember.
    private func pendingRow(_ m: BLFamilyMember) -> some View {
        HStack(spacing: Spacing.s2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink)
                Text(roleLabel(m.role)).font(.system(size: 12)).foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Button { Task { await approveMember(m) } } label: {
                Text("승인").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, Spacing.s3).frame(height: 34)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }.buttonStyle(LiquidPressStyle(scale: 0.97))
            .disabled(busy)
            .accessibilityLabel("\(m.displayName) 승인")
            Button { pendingRemove = m } label: {
                Text("거절").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.danger)
                    .padding(.horizontal, Spacing.s3).frame(height: 34)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            }.buttonStyle(LiquidPressStyle(scale: 0.97))
            .accessibilityLabel("\(m.displayName) 거절")
        }
        .padding(.vertical, Spacing.s2)
    }

    /// 멤버 한 행 — 이름·역할 + (주인 본인·자기 자신 제외) 내보내기.
    private func memberRow(_ m: BLFamilyMember) -> some View {
        let isOwner = m.uid != nil && m.uid == family?.ownerUid
        let isMe = m.uid != nil && m.uid == myUid
        return HStack(spacing: Spacing.s2) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(m.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink)
                    if isOwner {
                        Text("주인").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(AppColors.primarySoft, in: Capsule())
                    }
                }
                Text(roleLabel(m.role)).font(.system(size: 12)).foregroundStyle(AppColors.ink3)
            }
            Spacer()
            if !isOwner && !isMe {
                Button { pendingRemove = m } label: {
                    Text("내보내기").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.danger)
                        .padding(.horizontal, Spacing.s3).frame(height: 34)
                        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                }.buttonStyle(LiquidPressStyle(scale: 0.97))
                .accessibilityLabel("\(m.displayName) 내보내기")
            }
        }
        .padding(.vertical, Spacing.s2)
    }

    private func roleLabel(_ role: String) -> String {
        switch role {
        case "parent": return "부모"
        case "grandparent": return "조부모·친척"
        default: return role
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
                        // 올린 본인 또는 가족 보관함 주인(부모)이면 삭제 가능
                        if post.authorUid == myUid || family?.ownerUid == myUid {
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
        if let f = family {
            if f.ownerUid == myUid {
                // 주인: 멤버·승인 대기 + 피드.
                myApproved = true
                await loadMembers()
                posts = await FamilyFeedBackend.fetchFeed(familyId: f.id)
            } else {
                // 비주인: 내 승인 상태 먼저 확인. 승인된 경우만 피드 로드.
                let approved = (await FamilyFeedBackend.myMembership(familyId: f.id))?.approved ?? false
                myApproved = approved
                posts = approved ? await FamilyFeedBackend.fetchFeed(familyId: f.id) : []
            }
        }
        loading = false
    }

    /// 가족 관리(주인) 멤버 목록 + 승인 대기 로드.
    private func loadMembers() async {
        guard let f = family else { return }
        loadingMembers = true
        members = await FamilyFeedBackend.fetchMembers(familyId: f.id)
        pendingMembers = await FamilyFeedBackend.fetchPendingMembers(familyId: f.id)
        loadingMembers = false
    }

    /// 멤버 승인(주인) — 성공 시 대기·멤버 목록 재로딩, 실패 시 사유 알림(인원 초과 등).
    private func approveMember(_ m: BLFamilyMember) async {
        busy = true; defer { busy = false }
        if await FamilyFeedBackend.approveMember(memberId: m.id) {
            await loadMembers()
        } else {
            errorMsg = FamilyFeedBackend.lastError ?? "승인하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }

    /// 멤버 내보내기(주인) — 성공 시 목록 갱신.
    private func removeMember(_ m: BLFamilyMember) async {
        if await FamilyFeedBackend.removeMember(memberId: m.id) {
            await loadMembers()
        } else {
            errorMsg = "내보내지 못했어요. 잠시 후 다시 시도해 주세요."
        }
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
        if await FamilyFeedBackend.deletePostFully(postId: post.id) {
            posts.removeAll { $0.id == post.id }
            store.unmarkFeedShared(post.id)        // 기록 카드의 '공유 중' 표시 해제
            store.familyFeedVersion &+= 1          // 기록 탭 카드들 재조회 트리거
        } else {
            errorMsg = "삭제하지 못했어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

// 초대 정보(공유 시트용)
struct InviteInfo: Identifiable {
    let id = UUID()
    let url: URL
    let code: String
    let familyId: String
    let defaultPass: String
}

// 초대 링크 + 비밀번호 시트 — 링크 보내기 / 비밀번호(숫자 4~10자리) 설정
private struct InviteShareSheet: View {
    let info: InviteInfo
    @State private var pin: String
    @State private var savedPin = ""
    @State private var saving = false
    @State private var copied = false

    init(info: InviteInfo) { self.info = info; _pin = State(initialValue: info.defaultPass) }

    private var valid: Bool { (4...10).contains(pin.count) && pin.allSatisfy(\.isNumber) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("조부모님 초대").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                Text("① 아래 링크를 보내고  ② 비밀번호는 따로(전화 등) 알려주세요.\n둘 다 있어야 들어올 수 있어 안전해요. 안드로이드·아이폰 모두 브라우저로 보고 ❤️·댓글 가능.")
                    .font(.system(size: 13.5)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)

                // ── 링크 ──
                Text("초대 링크").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                Text(info.url.absoluteString)
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColors.primary)
                    .lineLimit(2).truncationMode(.middle)
                    .padding(Spacing.s3).frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                HStack(spacing: Spacing.s2) {
                    ShareLink(item: info.url) {
                        Text("링크 보내기").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    Button { UIPasteboard.general.string = info.url.absoluteString; copied = true; Haptics.success() } label: {
                        Text(copied ? "복사됨 ✓" : "복사").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.primary)
                            .frame(width: 84).frame(height: 48)
                            .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                }

                Divider().padding(.vertical, 2)

                // ── 비밀번호 ──
                Text("가족 비밀번호 (숫자 4~10자리)").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                HStack(spacing: Spacing.s2) {
                    TextField("숫자 4~10자리", text: $pin)
                        .keyboardType(.numberPad)
                        .font(AppFont.num(20, weight: .heavy)).foregroundStyle(AppColors.ink)
                        .padding(.horizontal, Spacing.s3).frame(height: 50)
                        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        .onChange(of: pin) { _, v in
                            let d = String(v.filter(\.isNumber).prefix(10)); if d != pin { pin = d }
                        }
                    Button { Task { await save() } } label: {
                        Text(savedPin == pin && !savedPin.isEmpty ? "저장됨 ✓" : (saving ? "저장 중" : "저장"))
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 88).frame(height: 50)
                            .background(valid && savedPin != pin ? AppColors.primary : AppColors.ink3,
                                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }.disabled(!valid || saving || savedPin == pin)
                }
                Text("이 비밀번호는 링크와 같은 곳(카톡 등)에 적지 말고, 전화 등으로 따로 알려주세요.")
                    .font(.system(size: 12)).foregroundStyle(AppColors.ink3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.s5)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await save() }   // 생성된 기본 비번을 즉시 적용(부모가 바꾸면 다시 저장)
    }

    private func save() async {
        guard valid, pin != savedPin else { return }
        saving = true
        if await FamilyFeedBackend.setFamilyPass(familyId: info.familyId, pass: pin) { savedPin = pin }
        saving = false
    }
}

// 가족 참여 시트 — 초대코드 + 비밀번호(숫자 4~10자리)로 합류
private struct JoinFamilySheet: View {
    /// (코드, 비번) → 성공 여부. 성공 시 시트 닫힘.
    let onJoin: (String, String) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var pin = ""
    @State private var joining = false

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var valid: Bool {
        !trimmedCode.isEmpty && (4...10).contains(pin.count) && pin.allSatisfy(\.isNumber)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("가족 참여하기").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                Text("가족이 알려준 초대 코드와 비밀번호를 입력하세요. 둘 다 있어야 들어올 수 있어요.")
                    .font(.system(size: 13.5)).foregroundStyle(AppColors.ink2).fixedSize(horizontal: false, vertical: true)

                // ── 초대 코드 ──
                Text("초대 코드").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                TextField("예: ABCD2345", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 18, weight: .heavy, design: .monospaced)).foregroundStyle(AppColors.ink)
                    .padding(.horizontal, Spacing.s3).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))

                // ── 비밀번호 ──
                Text("가족 비밀번호 (숫자 4~10자리)").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                TextField("숫자 4~10자리", text: $pin)
                    .keyboardType(.numberPad)
                    .font(AppFont.num(20, weight: .heavy)).foregroundStyle(AppColors.ink)
                    .padding(.horizontal, Spacing.s3).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .onChange(of: pin) { _, v in
                        let d = String(v.filter(\.isNumber).prefix(10)); if d != pin { pin = d }
                    }

                Button { Task { await join() } } label: {
                    Text(joining ? "참여 중…" : "참여하기")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(valid && !joining ? AppColors.primary : AppColors.ink3,
                                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))
                .disabled(!valid || joining)

                Text("초대 코드와 비밀번호는 가족에게 직접 받아 입력해 주세요.")
                    .font(.system(size: 12)).foregroundStyle(AppColors.ink3).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Spacing.s5)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func join() async {
        guard valid, !joining else { return }
        joining = true
        let ok = await onJoin(trimmedCode, pin)
        joining = false
        if ok { dismiss() }
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
