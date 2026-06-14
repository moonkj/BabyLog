// CrewGroupDetail.swift
// BabyLog · 비슷한 또래 그룹 상세 — 정보 + 가입/탈퇴 + 그룹 채팅(가입자 전용).
// 모임(CrewMeetupDetail) 패턴 미러링. 그룹은 '가입'해야 채팅 입장.

import SwiftUI

struct CrewGroupDetail: View {
    let group: CrewGroup
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showChat = false
    @State private var joinBusy = false
    @State private var showLogin = false   // 로그인 게이트(가입·채팅)
    @State private var showDeleteConfirm = false      // 크루장: 크루 삭제 확인
    @State private var showLastMemberLeave = false    // 크루장이 마지막 멤버일 때 탈퇴=삭제 안내
    @State private var notice: String? = nil

    private var isJoined: Bool { store.isJoinedGroup(group.id) }
    private var memberCount: Int { group.memberCount + (isJoined ? 1 : 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    infoCard
                    chatCard
                    safety
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if group.mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("크루 삭제")
                }
            }
        }
        .sheet(isPresented: $showChat) {
            CrewGroupChatSheet(group: group).environmentObject(store)
        }
        .sheet(isPresented: $showLogin) {
            AppleLoginSheet(message: "그룹 가입·채팅은 로그인이 필요해요.") {}
        }
        .confirmationDialog("이 크루를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { deleteGroup() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("크루와 그룹 채팅이 모두 사라져요. 되돌릴 수 없어요.")
        }
        .confirmationDialog("크루의 마지막 멤버예요", isPresented: $showLastMemberLeave, titleVisibility: .visible) {
            Button("크루 삭제하고 나가기", role: .destructive) { deleteGroup() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("혼자 남은 크루예요. 나가면 크루가 사라져요.")
        }
        .alert("크루", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(notice ?? "") }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: 0xE6F1FB)).frame(width: 76, height: 76)
                Image(systemName: "person.3.fill").font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3B6FA8))
            }.accessibilityHidden(true)
            Text(group.name).font(.system(size: 21, weight: .heavy)).foregroundStyle(AppColors.ink)
                .multilineTextAlignment(.center)
            Text("\(memberCount)명 · \(group.distanceText) · \(group.ageRange)")
                .font(AppFont.num(13)).foregroundStyle(AppColors.ink3)
            // 크루장(개설자) 표시 — 처음 만든 사람이 크루장
            if let leader = group.mine ? "나" : group.creatorName, !leader.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").font(.system(size: 10, weight: .bold))
                    Text("크루장 \(leader)").font(.system(size: 11.5, weight: .bold))
                }
                .foregroundStyle(AppColors.gold)
                .padding(.horizontal, 9).frame(height: 22)
                .background(AppColors.goldTint, in: Capsule())
            }
            if !group.interestTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(group.interestTags, id: \.self) { tag in
                            Text(tag).font(.system(size: 11.5, weight: .medium)).foregroundStyle(AppColors.ink2)
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(AppColors.surface2, in: Capsule())
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var infoCard: some View {
        BLCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("이 그룹은요").font(.system(size: 13.5, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("\(group.ageRange) 또래를 키우는 \(group.distanceText) 이웃들의 모임이에요. 가입하면 그룹 채팅에서 정보·일상을 나눌 수 있어요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chatCard: some View {
        Button {
            if isJoined { Haptics.light(); showChat = true }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(AppColors.primarySoft).frame(width: 42, height: 42)
                    Image(systemName: "bubble.left.and.bubble.right.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(AppColors.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(isJoined ? "그룹 채팅 열기" : "가입하면 채팅이 열려요")
                        .font(.system(size: 14.5, weight: .bold)).foregroundStyle(AppColors.ink)
                    Text(isJoined ? "가입한 이웃들과 대화해요" : "아래 ‘가입하기’를 누르면 입장할 수 있어요")
                        .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: isJoined ? "arrow.right.circle.fill" : "lock.fill")
                    .font(.system(size: isJoined ? 18 : 14, weight: .semibold))
                    .foregroundStyle(isJoined ? AppColors.primary : AppColors.ink3)
            }
            .padding(14)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!isJoined)
    }

    private var safety: some View {
        Text("처음 만나는 이웃과는 공공장소에서, 아이 정보·민감한 개인정보는 조심히 나눠요.")
            .font(.system(size: 11.5)).foregroundStyle(AppColors.ink3)
            .frame(maxWidth: .infinity, alignment: .center).padding(.top, 2)
    }

    private var bottomBar: some View {
        Button {
            guard !joinBusy else { return }
            guard LoginGate.ready() else { showLogin = true; return }   // 로그인 필수(신상 특정)
            Haptics.light()
            handleMembershipTap()
        } label: {
            Text(isJoined ? "가입 취소" : "가입하기")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isJoined ? AppColors.ink2 : .white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(isJoined ? AppColors.surface2 : AppColors.primary,
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .padding(.horizontal, Spacing.s5).padding(.top, 12).padding(.bottom, 26)
        .background(AppColors.surface.ignoresSafeArea(edges: .bottom))
    }

    /// 가입/탈퇴 처리. 크루장이 탈퇴하면 다음 가입자에게 크루장을 위임(없으면 크루 삭제 안내).
    private func handleMembershipTap() {
        if !isJoined {
            store.toggleJoinGroup(group.id); joinBusy = true
            Task { @MainActor in
                let ok = await CrewBackend.setGroupMembership(groupId: group.id, join: true)
                if !ok { store.toggleJoinGroup(group.id) }
                joinBusy = false
            }
            return
        }
        // 탈퇴 — 크루장이면 위임 우선
        if group.mine {
            joinBusy = true
            Task { @MainActor in
                let me = await SupabaseConfig.ownerID()
                guard let next = await CrewBackend.nextGroupMember(groupId: group.id, excluding: me) else {
                    joinBusy = false
                    showLastMemberLeave = true   // 혼자 남음 → 삭제 안내
                    return
                }
                let transferred = await CrewBackend.transferGroupCreator(groupId: group.id, to: next, name: nil)
                guard transferred else { joinBusy = false; notice = "잠시 후 다시 시도해 주세요."; return }
                store.toggleJoinGroup(group.id)
                let left = await CrewBackend.setGroupMembership(groupId: group.id, join: false)
                if !left { store.toggleJoinGroup(group.id) }
                joinBusy = false
                notice = "크루장을 다음 멤버에게 넘기고 나갔어요."
            }
            return
        }
        // 일반 멤버 탈퇴
        store.toggleJoinGroup(group.id); joinBusy = true
        Task { @MainActor in
            let ok = await CrewBackend.setGroupMembership(groupId: group.id, join: false)
            if !ok { store.toggleJoinGroup(group.id) }
            joinBusy = false
        }
    }

    private func deleteGroup() {
        joinBusy = true
        Task { @MainActor in
            let ok = await CrewBackend.deleteGroup(groupId: group.id)
            joinBusy = false
            if ok { dismiss() } else { notice = "삭제하지 못했어요. 잠시 후 다시 시도해 주세요." }
        }
    }
}

// MARK: - 그룹 채팅 시트(가입자)

struct CrewGroupChatSheet: View {
    let group: CrewGroup
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var messages: [ChatMessage] = []
    @State private var text = ""
    @State private var reportTarget: ChatMessage? = nil   // 신고 대상(작성자명 탭)
    @State private var reportDone = false

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }

    private func poll() async {
        while !Task.isCancelled {
            if scenePhase == .active, let m = await CrewBackend.fetchGroupMessages(groupId: group.id) { messages = m }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }
    }
    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        text = ""; Haptics.light()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        Task {
            if await CrewBackend.sendGroupMessage(groupId: group.id, body: t, authorName: nickname),
               let m = await CrewBackend.fetchGroupMessages(groupId: group.id) { messages = m }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name).font(.system(size: 16, weight: .bold)).foregroundStyle(AppColors.ink).lineLimit(1)
                    Text("\(group.ageRange) · 그룹 채팅").font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Button("닫기") { dismiss() }.font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.ink2)
            }
            .padding(.horizontal, Spacing.s5).padding(.vertical, Spacing.s3)
            Divider().overlay(AppColors.line)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty {
                            Text("첫 메시지를 보내 그룹을 시작해보세요.")
                                .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                                .frame(maxWidth: .infinity).padding(.vertical, Spacing.s5)
                        }
                        ForEach(messages) { m in bubble(m).id(m.id) }
                    }
                    .padding(Spacing.s4)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: Spacing.s2) {
                TextField("메시지 입력…", text: $text)
                    .font(AppFont.body).padding(.horizontal, Spacing.s4).frame(height: 44)
                    .background(AppColors.surface2, in: Capsule())
                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundStyle(AppColors.primary)
                }
            }
            .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s3)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .task(id: group.id) { await poll() }
        .confirmationDialog("이 사용자를 신고할까요?", isPresented: Binding(
            get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } }
        ), titleVisibility: .visible, presenting: reportTarget) { msg in
            ForEach(ReportBackend.reasons, id: \.self) { reason in
                Button(reason, role: .destructive) {
                    let snap = messages.suffix(20).map { ["author": $0.author ?? ($0.mine ? "나" : "상대"), "text": $0.text] }
                    Task { _ = await ReportBackend.submit(surface: "crew_group", contextId: group.id,
                        reportedName: msg.author, reportedId: msg.authorId, reason: reason, transcript: snap) }
                    reportDone = true
                }
            }
            Button("취소", role: .cancel) {}
        } message: { msg in Text("‘\(msg.author ?? "사용자")’ 님을 신고합니다. 대화 내용이 운영자에게 증거로 전달돼요.") }
        .alert("신고 접수됐어요", isPresented: $reportDone) {
            Button("확인", role: .cancel) {}
        } message: { Text("운영자가 확인 후 조치합니다. 감사합니다.") }
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 40) }
            VStack(alignment: m.mine ? .trailing : .leading, spacing: 2) {
                if !m.mine, let name = m.author, !name.isEmpty {
                    Button { reportTarget = m } label: {
                        HStack(spacing: 3) {
                            Text(name).font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                            Image(systemName: "ellipsis").font(.system(size: 9, weight: .bold)).foregroundStyle(AppColors.ink3)
                        }
                    }.buttonStyle(.plain)
                }
                Text(m.text)
                    .font(.system(size: 14)).foregroundStyle(m.mine ? .white : AppColors.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(m.mine ? AppColors.primary : AppColors.surface2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !m.mine { Spacer(minLength: 40) }
        }
    }
}
