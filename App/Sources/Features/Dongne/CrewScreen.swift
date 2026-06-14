// CrewScreen.swift
// BabyLog · Features/Dongne
// DongneTab의 "크루" 세그먼트에 임베드하여 사용합니다.
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - Crew Models

enum CrewPostCategory: String, CaseIterable, Codable {
    case info    = "정보공유"
    case together = "같이해요"
    case consult  = "고민상담"

    var badgeTone: BadgeTone {
        switch self {
        case .info:     return .blue
        case .together: return .mint
        case .consult:  return .coral
        }
    }

    var systemIcon: String {
        switch self {
        case .info:     return "lightbulb.fill"
        case .together: return "person.2.fill"
        case .consult:  return "bubble.left.fill"
        }
    }
}

enum CrewMeetupType: String, Hashable, Codable, CaseIterable {
    case park, indoor

    var label: String {
        switch self {
        case .park:   return "야외/공원"
        case .indoor: return "실내"
        }
    }

    var systemIcon: String {
        switch self {
        case .park:   return "sun.max.fill"
        case .indoor: return "house.fill"
        }
    }

    var bgColor: Color {
        switch self {
        case .park:   return AppColors.primaryTint
        case .indoor: return Color(hex: 0xFBEAF0)
        }
    }

    var iconColor: Color {
        switch self {
        case .park:   return AppColors.primary
        case .indoor: return Color(hex: 0xB5478A)
        }
    }
}

struct CrewMeetup: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var place: String
    var when: String
    var hostName: String
    var hostTier: MarketSellerTier   // 재사용 (amber=골든맘, warm=따뜻한이웃)
    var joined: Int                  // 기본 참여 인원(나 제외)
    var capacity: Int
    var meetupType: CrewMeetupType
    var description: String = ""
    var mine: Bool = false
    var createdAt: Date = Date()
}

struct CrewGroup: Identifiable, Hashable {
    let id: String
    let name: String
    let memberCount: Int
    let distanceText: String
    let ageRange: String
    let interestTags: [String]
}

struct CrewPost: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var category: CrewPostCategory
    var authorName: String
    var timeText: String
    var title: String
    var body: String = ""
    var replyCount: Int
    var likeCount: Int
    var mine: Bool = false
    var createdAt: Date = Date()
}

// 하위 호환 디코딩 — 필드 추가 시 구 저장파일 전체가 깨지지 않게(데이터 보존 절대원칙).
extension CrewMeetup {
    enum CodingKeys: String, CodingKey {
        case id, place, when, hostName, hostTier, joined, capacity, meetupType, description, mine, createdAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        place       = try c.decodeIfPresent(String.self, forKey: .place) ?? "모임"
        when        = try c.decodeIfPresent(String.self, forKey: .when) ?? "일정 협의"
        hostName    = try c.decodeIfPresent(String.self, forKey: .hostName) ?? "이웃"
        hostTier    = MarketSellerTier(rawValue: (try? c.decode(String.self, forKey: .hostTier)) ?? "") ?? .new
        joined      = try c.decodeIfPresent(Int.self, forKey: .joined) ?? 0
        capacity    = try c.decodeIfPresent(Int.self, forKey: .capacity) ?? 8
        meetupType  = CrewMeetupType(rawValue: (try? c.decode(String.self, forKey: .meetupType)) ?? "") ?? .park
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        mine        = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        createdAt   = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

extension CrewPost {
    enum CodingKeys: String, CodingKey {
        case id, category, authorName, timeText, title, body, replyCount, likeCount, mine, createdAt
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        category   = CrewPostCategory(rawValue: (try? c.decode(String.self, forKey: .category)) ?? "") ?? .info
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName) ?? "이웃"
        timeText   = try c.decodeIfPresent(String.self, forKey: .timeText) ?? ""
        title      = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        body       = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount) ?? 0
        likeCount  = try c.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        mine       = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        createdAt  = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Mock Data

extension CrewMeetup {
    static let seedSamples: [CrewMeetup] = [
        CrewMeetup(id: "cm1", place: "망원한강공원 잔디밭",   when: "오늘 오후 3시",   hostName: "보리맘",  hostTier: .golden, joined: 5, capacity: 8, meetupType: .park),
        CrewMeetup(id: "cm2", place: "성산 실내놀이터",       when: "내일 오전 10시",  hostName: "하준이네", hostTier: .warm,   joined: 3, capacity: 6, meetupType: .indoor),
        CrewMeetup(id: "cm3", place: "마포구청 어린이공원",   when: "토 오후 2시",     hostName: "민서맘",  hostTier: .warm,   joined: 7, capacity: 10, meetupType: .park),
    ]
}

private let crewGroups: [CrewGroup] = [
    CrewGroup(id: "g1", name: "망원 8-12개월 크루",    memberCount: 23, distanceText: "반경 500m", ageRange: "8–12개월",   interestTags: ["이유식", "공원 산책", "성장 기록"]),
    CrewGroup(id: "g2", name: "마포 워킹맘 모임",      memberCount: 41, distanceText: "반경 1km",  ageRange: "6–18개월",   interestTags: ["육아 정보", "복직 준비", "어린이집"]),
    CrewGroup(id: "g3", name: "한강뷰 아파트 이웃들",  memberCount: 17, distanceText: "같은 단지", ageRange: "0–24개월",   interestTags: ["직거래", "공동구매", "놀이터"]),
]

extension CrewPost {
    static let seedSamples: [CrewPost] = [
        CrewPost(id: "po1", category: .info,     authorName: "서연이네", timeText: "10분 전",  title: "망원소아과 주말 대기 시간 공유해요 (오늘 기준)",              body: "오늘 오전 기준 대기 12팀이었어요. 오후 2시 이후가 한산합니다.", replyCount: 12, likeCount: 31),
        CrewPost(id: "po2", category: .together, authorName: "지우맘",   timeText: "1시간 전", title: "내일 한강 나들이 같이 가실 분 계신가요? (유아차 OK)",          body: "내일 오전 10시 망원한강공원에서 산책해요. 댓글 주세요!", replyCount: 8,  likeCount: 14),
        CrewPost(id: "po3", category: .consult,  authorName: "하준이네", timeText: "3시간 전", title: "8개월인데 아직 뒤집기를 잘 못해요 — 비슷한 경험 있으신 분?",  body: "또래보다 느린 것 같아 걱정이에요. 비슷한 경험 나눠주세요.", replyCount: 21, likeCount: 46),
        CrewPost(id: "po4", category: .info,     authorName: "민서맘",   timeText: "어제",    title: "마포구 유아 발달 지원금 신청 방법 정리했어요",                  body: "복지로에서 신청 가능하고 서류는 ~~~ 입니다.", replyCount: 5,  likeCount: 28),
    ]
}

// MARK: - CrewScreen

/// DongneTab의 "크루" 세그먼트에 임베드하는 메인 뷰.
/// `isPreviewActive` 내부 토글로 콜드스타트 / 활성 상태 전환 가능 (팀 QA용).
struct CrewScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var isActive: Bool = true   // 로컬 기능 활성 (콜드스타트는 토글로 미리보기)
    @State private var showCreate = false
    @State private var refreshTick = 0          // 모임 생성 후 활성 화면 재로드 트리거

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isActive {
                CrewActiveContent(refreshTick: refreshTick)
            } else {
                CrewColdStartContent(onJoinWaitlist: { })
            }

            #if DEBUG
            previewToggle   // 팀 QA 전용 — 릴리스 빌드 미노출
            #endif
        }
        .background(AppColors.canvas.ignoresSafeArea())
        // 공용 글래스 FAB — 모임 만들기 (모양·위치는 전 화면 공유, 기능만 다름)
        .appFAB { if isActive { Haptics.light(); showCreate = true } }
        .sheet(isPresented: $showCreate) {
            CrewCreateSheet().environmentObject(store).presentationDetents([.large])
        }
        .onChange(of: showCreate) { _, open in if !open { refreshTick += 1 } }
    }

    private var previewToggle: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isActive.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isActive ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(isActive ? "오픈전" : "활성화")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(AppColors.ink3)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(AppColors.surface, in: Capsule())
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.95))
        .padding(.top, Spacing.s2)
        .padding(.trailing, Spacing.s5)
        .accessibilityLabel(isActive ? "오픈 전 보기로 전환" : "활성 보기로 전환")
        .accessibilityHint("팀 미리보기 토글")
    }
}

// MARK: - CrewActiveContent (활성 상태)

private struct CrewActiveContent: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var location = NearbyLocationProvider.shared
    @State private var showWrite = false
    @State private var selectedPost: CrewPost?
    @State private var showAllMeetups = false
    @State private var showAllGroups = false
    @State private var showAllPosts = false
    /// 서버 공유(미구성/미로드 시 nil → 로컬 폴백)
    @State private var sharedPosts: [CrewPost]? = nil
    @State private var sharedMeetups: [CrewMeetup]? = nil
    @State private var sharedGroups: [CrewGroup]? = nil
    @State private var showCreateGroup = false
    /// 동네별 첫 로드 완료 여부(서버 연동 시 가짜 시드 플래시 방지)
    @State private var didLoad = false
    /// 세 요청(게시글·모임·그룹)이 모두 실패 — 네트워크 실패를 빈 동네와 구분
    @State private var loadFailed = false
    /// 부모(CrewScreen)에서 모임 생성 후 증가 → 재로드 트리거
    var refreshTick: Int = 0

    private let sectionLimit = 5
    // 크루는 '내 동네'(동 단위). 미설정 시에만 현재 GPS 동으로 폴백.
    private var hood: String { store.selectedDong ?? location.localityName ?? "우리 동네" }
    // 서버 연동 시엔 서버 데이터만(시드 폴백 금지 — 정직 원칙). 미구성 시에만 로컬/목업.
    private var posts: [CrewPost] { SupabaseConfig.isConfigured ? (sharedPosts ?? []) : store.crewPosts }
    private var meetups: [CrewMeetup] { SupabaseConfig.isConfigured ? (sharedMeetups ?? []) : store.crews }
    private var groups: [CrewGroup] { SupabaseConfig.isConfigured ? (sharedGroups ?? []) : crewGroups }

    private func loadCrew() async {
        guard SupabaseConfig.isConfigured else { return }
        let p = await CrewBackend.fetchPosts(hood: hood)
        if let p {
            sharedPosts = p.map { po in
                guard store.isCrewPostLiked(po.id) else { return po }
                var x = po; x.likeCount = max(0, po.likeCount - 1); return x
            }
        }
        // 서버 카운트는 본인을 포함 → "나 제외" 규약 유지를 위해 내가 참여/가입한 항목은 1 차감.
        let m = await CrewBackend.fetchMeetups(hood: hood)
        if let m {
            sharedMeetups = m.map { mt in
                guard store.isJoinedCrew(mt.id) else { return mt }
                var x = mt; x.joined = max(0, mt.joined - 1); return x
            }
        }
        let g = await CrewBackend.fetchGroups(hood: hood)
        if let g {
            sharedGroups = g.map { gr in
                guard store.isJoinedGroup(gr.id) else { return gr }
                return CrewGroup(id: gr.id, name: gr.name, memberCount: max(0, gr.memberCount - 1),
                                 distanceText: gr.distanceText, ageRange: gr.ageRange, interestTags: gr.interestTags)
            }
        }
        // 셋 다 nil이면 네트워크 실패 — 빈 동네와 구분해 재시도 UI를 띄운다.
        loadFailed = (p == nil && m == nil && g == nil)
        didLoad = true
    }

    /// 동네(내 동네 또는 GPS)가 아직 안 잡혔으면 빈/실패 화면 대신 로딩을 유지한다.
    private var isLoading: Bool { SupabaseConfig.isConfigured && (!didLoad || hood == "우리 동네") }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    loadingView
                } else if loadFailed && posts.isEmpty && meetups.isEmpty && groups.isEmpty {
                    crewLoadFailedView
                } else {
                    meetupSection
                        .padding(.top, Spacing.s5)
                    crewSection
                    boardSection
                        .padding(.bottom, 100)
                }
            }
        }
        .refreshable { await loadCrew() }
        .sheet(isPresented: $showWrite) {
            CrewPostWriteSheet()
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .sheet(item: $selectedPost) { post in
            CrewPostDetailSheet(post: post)
                .environmentObject(store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showAllMeetups) {
            CrewMeetupListScreen(meetups: meetups).environmentObject(store)
        }
        .sheet(isPresented: $showAllGroups) {
            CrewGroupListScreen(groups: groups, onToggle: { id, join in syncGroupJoin(id, join: join) })
                .environmentObject(store)
        }
        .sheet(isPresented: $showAllPosts) {
            CrewPostListScreen(posts: posts).environmentObject(store)
        }
        .task(id: hood) { didLoad = false; loadFailed = false; await loadCrew() }
        .onChange(of: showWrite) { _, open in if !open { Task { await loadCrew() } } }
        .onChange(of: selectedPost) { _, sel in if sel == nil { Task { await loadCrew() } } }
        .onChange(of: refreshTick) { _, _ in Task { await loadCrew() } }
    }

    // MARK: 같이 가요
    private var meetupSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(
                eyebrow: "주변 모임",
                title: "같이 가요",
                action: meetups.count > sectionLimit ? "전체보기" : nil,
                onAction: meetups.count > sectionLimit ? { Haptics.light(); showAllMeetups = true } : nil
            )
            .padding(.horizontal, Spacing.s5)

            if meetups.isEmpty {
                sectionEmptyNotice("아직 우리 동네 모임이 없어요.\n우상단 + 버튼으로 첫 모임을 열어보세요.")
            } else {
                ForEach(Array(meetups.prefix(sectionLimit))) { meetup in
                    NavigationLink(value: meetup) {
                        CrewMeetupCard(meetup: meetup)
                            .padding(.horizontal, Spacing.s5)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.bottom, Spacing.s6)
        .navigationDestination(for: CrewMeetup.self) { meetup in
            CrewMeetupDetail(meetup: meetup)
        }
        .navigationDestination(for: CrewGroup.self) { group in
            CrewGroupDetail(group: group)
        }
    }

    // MARK: 비슷한 또래 크루
    private var crewSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(
                eyebrow: sharedGroups != nil ? "우리 동네" : "반경 1km",
                title: "비슷한 또래 크루",
                action: groups.count > sectionLimit ? "전체보기" : nil,
                onAction: groups.count > sectionLimit ? { Haptics.light(); showAllGroups = true } : nil
            )
            .padding(.horizontal, Spacing.s5)

            if groups.isEmpty {
                emptyGroupNotice
            } else {
                ForEach(groups.prefix(sectionLimit)) { group in
                    NavigationLink(value: group) { CrewGroupCard(group: group) }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, Spacing.s5)
                }
            }

            // 그룹 개설 (서버 연동 시에만 — 로컬 목업 모드에선 숨김)
            if SupabaseConfig.isConfigured {
                Button { Haptics.light(); showCreateGroup = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 15, weight: .semibold))
                        Text("우리 또래 그룹 만들기").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(AppColors.primary)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))
                .padding(.horizontal, Spacing.s5)
                .padding(.top, 2)
            }
        }
        .padding(.bottom, Spacing.s6)
        .sheet(isPresented: $showCreateGroup) {
            CrewGroupCreateSheet().presentationDetents([.large])
        }
        .onChange(of: showCreateGroup) { _, open in if !open { Task { await loadCrew() } } }
    }

    private var emptyGroupNotice: some View {
        Text("아직 우리 동네 또래 그룹이 없어요.\n첫 그룹을 만들어 이웃과 이어보세요.")
            .font(AppFont.caption)
            .foregroundStyle(AppColors.ink3)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s5)
            .padding(.vertical, Spacing.s2)
    }

    private func sectionEmptyNotice(_ text: String) -> some View {
        Text(text)
            .font(AppFont.caption)
            .foregroundStyle(AppColors.ink3)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.s5)
            .padding(.vertical, Spacing.s2)
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.s3) {
            ProgressView()
            Text("우리 동네 크루를 불러오는 중…")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
        .accessibilityLabel("우리 동네 크루를 불러오는 중")
    }

    // MARK: 불러오기 실패 (네트워크) — 빈 동네와 구분
    private var crewLoadFailedView: some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("크루 소식을 불러오지 못했어요")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.ink)
            Text("네트워크 연결을 확인하고 다시 시도해 주세요.")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)

            Button {
                Haptics.light()
                Task { await loadCrew() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("다시 시도")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(AppColors.surface, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.96))
            .padding(.top, Spacing.s1)
            .accessibilityLabel("다시 시도")
            .accessibilityHint("우리 동네 크루 소식을 다시 불러옵니다")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("크루 소식을 불러오지 못했어요. 네트워크 연결을 확인하고 다시 시도해 주세요.")
    }

    /// 그룹 가입 토글을 서버에도 반영(서버 그룹만; 미구성/목업은 setGroupMembership가 무시).
    private func syncGroupJoin(_ groupId: String, join: Bool) {
        guard SupabaseConfig.isConfigured, sharedGroups != nil else { return }
        Task {
            let ok = await CrewBackend.setGroupMembership(groupId: groupId, join: join)
            if !ok { store.toggleJoinGroup(groupId); return }   // 실패 시 로컬 가입상태 롤백
            if let g = await CrewBackend.fetchGroups(hood: hood) {
                sharedGroups = g.map { gr in
                    guard store.isJoinedGroup(gr.id) else { return gr }
                    return CrewGroup(id: gr.id, name: gr.name, memberCount: max(0, gr.memberCount - 1),
                                     distanceText: gr.distanceText, ageRange: gr.ageRange, interestTags: gr.interestTags)
                }
            }
        }
    }

    // MARK: 동네 게시판
    private var boardSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                BLSectionHead(
                    eyebrow: "동네 이야기",
                    title: "동네 게시판",
                    action: posts.count > sectionLimit ? "전체보기" : nil,
                    onAction: posts.count > sectionLimit ? { Haptics.light(); showAllPosts = true } : nil
                )
                Button {
                    Haptics.light()
                    showWrite = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil").font(.system(size: 13, weight: .bold))
                        Text("글쓰기").font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.s3).frame(height: 44)
                    .background(AppColors.primary, in: Capsule())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.95))
                .accessibilityLabel("글쓰기")
                .accessibilityHint("동네 게시판에 새 글을 작성합니다")
            }
            .padding(.horizontal, Spacing.s5)

            if posts.isEmpty {
                sectionEmptyNotice("아직 동네 게시글이 없어요.\n첫 글을 남겨 이웃과 이야기를 시작해보세요.")
            } else {
                BLCard(padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.prefix(sectionLimit).enumerated()), id: \.element.id) { idx, post in
                            Button {
                                Haptics.light()
                                selectedPost = post
                            } label: {
                                CrewPostRow(post: post)
                                    .padding(.horizontal, Spacing.s4)
                                    .padding(.vertical, 14)
                                    .overlay(alignment: .top) {
                                        if idx > 0 {
                                            Rectangle()
                                                .fill(AppColors.line)
                                                .frame(height: 1)
                                                .padding(.horizontal, Spacing.s4)
                                        }
                                    }
                            }
                            .buttonStyle(LiquidPressStyle(scale: 0.985))
                        }
                    }
                }
                .padding(.horizontal, Spacing.s5)
            }
        }
    }
}

// MARK: - 전체보기 리스트 화면

private struct CrewMeetupListScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var meetups: [CrewMeetup]
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.s3) {
                    ForEach(meetups) { meetup in
                        NavigationLink(value: meetup) {
                            CrewMeetupCard(meetup: meetup).padding(.horizontal, Spacing.s5)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("같이 가요")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .navigationDestination(for: CrewMeetup.self) { CrewMeetupDetail(meetup: $0) }
        }
    }
}

private struct CrewGroupListScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var groups: [CrewGroup]
    var onToggle: (String, Bool) -> Void = { _, _ in }
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: Spacing.s3) {
                    ForEach(groups) { group in
                        NavigationLink(value: group) { CrewGroupCard(group: group) }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, Spacing.s5)
                    }
                }
                .padding(.vertical, Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("비슷한 또래 크루")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CrewGroup.self) { group in CrewGroupDetail(group: group) }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
        }
    }
}

private struct CrewPostListScreen: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPost: CrewPost?
    var posts: [CrewPost]
    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                BLCard(padding: 0) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { idx, post in
                            Button { Haptics.light(); selectedPost = post } label: {
                                CrewPostRow(post: post)
                                    .padding(.horizontal, Spacing.s4).padding(.vertical, 14)
                                    .overlay(alignment: .top) {
                                        if idx > 0 {
                                            Rectangle().fill(AppColors.line).frame(height: 1)
                                                .padding(.horizontal, Spacing.s4)
                                        }
                                    }
                            }
                            .buttonStyle(LiquidPressStyle(scale: 0.985))
                        }
                    }
                }
                .padding(Spacing.s5)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("동네 게시판")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } } }
            .sheet(item: $selectedPost) { post in
                CrewPostDetailSheet(post: post).environmentObject(store).presentationDetents([.large])
            }
        }
    }
}

// MARK: - CrewMeetupCard

private struct CrewMeetupCard: View {
    @EnvironmentObject private var store: AppStore
    let meetup: CrewMeetup

    private var joinedCount: Int { store.crewJoinedCount(meetup) }
    private var isJoined: Bool { store.isJoinedCrew(meetup.id) }
    private var spotsLeft: Int { max(0, meetup.capacity - joinedCount) }
    private var isFull: Bool { joinedCount >= meetup.capacity && !isJoined }

    var body: some View {
        BLCard(padding: 15) {
            HStack(alignment: .center, spacing: 13) {
                // 모임 타입 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(meetup.meetupType.bgColor)
                        .frame(width: 50, height: 50)
                    Image(systemName: meetup.meetupType.systemIcon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(meetup.meetupType.iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(meetup.place)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)

                    HStack(spacing: 5) {
                        Text(meetup.when)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                        Text("·")
                            .foregroundStyle(AppColors.ink3)
                        Text(meetup.hostName)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                        BLBadge(tone: meetup.hostTier.badgeTone, text: meetup.hostTier.rawValue, systemIcon: meetup.hostTier.systemIcon, dot: false)
                    }

                    // 참가자 아바타 + 정원
                    HStack(spacing: 5) {
                        MkAvatarStack(count: min(joinedCount, 4))
                        Text("\(joinedCount)/\(meetup.capacity)명")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)

                // 참가 버튼 (토글 / 마감)
                Button {
                    Haptics.selection()
                    let willJoin = !isJoined
                    store.toggleJoinCrew(meetup.id)   // 낙관적 토글
                    // 상세 화면과 동일하게 서버에도 반영 — 카드에서만 누르면 이웃에게 안 보이던 버그 수정
                    if SupabaseConfig.isConfigured {
                        Task {
                            let ok = willJoin
                                ? await CrewBackend.joinMeetup(meetupId: meetup.id)
                                : await CrewBackend.leaveMeetup(meetupId: meetup.id)
                            if !ok { store.toggleJoinCrew(meetup.id) }   // 실패 시 롤백
                        }
                    }
                } label: {
                    Text(isFull ? "마감" : (isJoined ? "참가중" : "참가"))
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(isFull ? AppColors.ink3 : (isJoined ? AppColors.ink2 : Color.white))
                        .padding(.horizontal, Spacing.s4)
                        .frame(height: 44)
                        .background(isFull ? AppColors.surface3 : (isJoined ? AppColors.surface2 : AppColors.ink),
                                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.94))
                .disabled(isFull)
                .accessibilityLabel(isFull ? "마감" : (isJoined ? "참가 취소" : "참가"))
                .accessibilityHint(isFull ? "\(meetup.place) 모임. 정원이 가득 찼습니다" : "\(meetup.place) 모임. 남은 자리 \(spotsLeft)자리")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(meetup.place), \(meetup.when), 정원 \(meetup.capacity)명 중 \(joinedCount)명 참가, 주최자 \(meetup.hostName)")
    }
}

// MARK: - CrewGroupCard

private struct CrewGroupCard: View {
    @EnvironmentObject private var store: AppStore
    let group: CrewGroup
    private var isJoined: Bool { store.isJoinedGroup(group.id) }
    // group.memberCount는 "나 제외"(서버 fetch 시 본인을 뺌) → 가입 시 +1.
    private var memberCount: Int { group.memberCount + (isJoined ? 1 : 0) }

    var body: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(hex: 0xE6F1FB))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x3B6FA8))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)

                    Text("\(memberCount)명 · \(group.distanceText) · \(group.ageRange)")
                        .font(AppFont.num(12))
                        .foregroundStyle(AppColors.ink3)

                    // 관심사 태그
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(group.interestTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppColors.ink2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.surface2, in: Capsule())
                            }
                        }
                    }
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)

                // 가입 상태 + 입장 안내(가입/채팅은 상세에서)
                VStack(spacing: 3) {
                    if isJoined {
                        Text("가입중").font(.system(size: 11, weight: .heavy)).foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(AppColors.primarySoft, in: Capsule())
                    }
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColors.ink3)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(memberCount)명, \(group.ageRange). \(isJoined ? "가입중. " : "")탭하면 그룹 입장")
    }
}

// MARK: - CrewPostRow

private struct CrewPostRow: View {
    @EnvironmentObject private var store: AppStore
    let post: CrewPost
    private var isLiked: Bool { store.isCrewPostLiked(post.id) }
    private var likeCount: Int { post.likeCount + (isLiked ? 1 : 0) }
    // 서버 연동 시 댓글 수는 서버 카운트(post.replyCount)만 사용 — 로컬 댓글 중복 가산 금지.
    private var replyCount: Int { SupabaseConfig.isConfigured ? post.replyCount : store.crewPostReplyCount(post) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                // 카테고리: 색+아이콘+레이블 3중 인코딩
                BLBadge(
                    tone: post.category.badgeTone,
                    text: post.category.rawValue,
                    systemIcon: post.category.systemIcon,
                    dot: false
                )
                Text("\(post.authorName) · \(post.timeText)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
            }

            Text(post.title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink3)
                    Text("\(replyCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                .accessibilityLabel("댓글 \(replyCount)개")

                Button {
                    Haptics.selection()
                    let willLike = !isLiked
                    store.toggleCrewPostLike(post.id)
                    // 목록에서도 좋아요를 서버에 반영(상세에서만 저장되던 버그 수정) + 실패 시 롤백
                    if SupabaseConfig.isConfigured {
                        Task {
                            let ok = await CrewBackend.setPostLike(postId: post.id, like: willLike)
                            if !ok { store.toggleCrewPostLike(post.id) }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 13))
                            .foregroundStyle(isLiked ? AppColors.danger : AppColors.ink3)
                        Text("\(likeCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isLiked ? "좋아요 취소, 현재 \(likeCount)개" : "좋아요, 현재 \(likeCount)개")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - CrewColdStartContent (콜드스타트 = 기대감 UI)

private struct CrewColdStartContent: View {
    var onJoinWaitlist: () -> Void
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var location = NearbyLocationProvider.shared

    /// 서버 연동 시 실제 신청 수(미구성/실패 시 nil → 목업).
    @State private var realCount: Int? = nil
    private var target: Int { CrewBackend.openThreshold }
    private var progressPercent: Double {
        if let c = realCount { return min(1, Double(c) / Double(max(1, target))) }
        return SupabaseConfig.isConfigured ? 0 : 0.78   // 서버 연동 시 실제 로드 전엔 0(가짜 78% 금지), 미구성 데모만 목업
    }
    private var remainingCount: Int {
        if let c = realCount { return max(0, target - c) }
        return SupabaseConfig.isConfigured ? target : 22
    }

    /// 내 동네(동) 기준 — 미설정 시 현재 GPS 동 폴백
    private var hood: String { store.selectedDong ?? location.localityName ?? "우리 동네" }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                heroArea
                progressCard
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s6)
                actionButtons
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, 18)
                benefitCard
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, 20)
                    .padding(.bottom, Spacing.s8)
            }
        }
        // 서버 연동 시 동네별 실제 대기 수 로드
        .task(id: hood) {
            guard SupabaseConfig.isConfigured, hood != "우리 동네" else { return }
            realCount = await CrewBackend.waitlistCount(hood: hood)
        }
    }

    // MARK: 히어로 영역
    private var heroArea: some View {
        VStack(spacing: 0) {
            // 캐릭터 아이콘
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xDCEFE6), Color(hex: 0xE1F5EE)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                // 까닥이는 이웃 (§8.4)
                NoddingNeighborView(size: 40, tint: AppColors.primary)
            }
            .padding(.top, 32)
            .padding(.bottom, 20)
            .accessibilityHidden(true)

            Text("\(hood), 거의 다 모였어요")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(AppColors.ink)
                .multilineTextAlignment(.center)

            Text("조금만 더 모이면 크루 기능이 열려요.\n친구를 초대하면 더 빨리 열린답니다.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 8)
                .padding(.horizontal, Spacing.s7)
        }
    }

    // MARK: 진행바 카드
    private var progressCard: some View {
        BLCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColors.primary)
                        Text("우리 동네 준비도")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                    }
                    Spacer()
                    Text("\(Int(progressPercent * 100))%")
                        .font(AppFont.num(13, weight: .heavy))
                        .foregroundStyle(AppColors.primary)
                }

                // 진행 바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.surface3)
                            .frame(height: 12)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x5E9B7C), AppColors.primary],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progressPercent, height: 12)
                    }
                }
                .frame(height: 12)
                .accessibilityLabel("준비도 \(Int(progressPercent * 100))퍼센트")
                .accessibilityValue("\(Int(progressPercent * 100))%")

                Text("\(remainingCount)명 더 모이면 오픈돼요")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 액션 버튼들
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // 친구 초대 — 시스템 공유 시트(ShareLink)
            ShareLink(
                item: URL(string: "https://babylog.app")!,
                subject: Text("BabyLog 초대"),
                message: Text("우리 동네 육아 앱 BabyLog, 같이 써요! 🌱")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text("친구 초대하고 빨리 열기")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(AppColors.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppColors.ink, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .blShadow(.chip)
            }
            .accessibilityLabel("친구 초대하고 빨리 열기")
            .accessibilityHint("공유 시트로 친구를 초대합니다")

            // 자동 안내 — 신청 버튼 없이, 우리 동네 사람이 모이면 자동으로 열리고 알림
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                Text("이 동네에 이웃이 충분히 모이면 자동으로 열리고 알려드려요")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("이웃이 충분히 모이면 자동으로 열리고 알림을 받습니다")
        }
    }

    // MARK: 초기 멤버 혜택 카드
    private var benefitCard: some View {
        BLCard(padding: 15, flat: true) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("초기 멤버 혜택")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(AppColors.gold)

                    Text("지금 합류하면 우리 동네 1호 멤버 영구 뱃지를 드려요.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color(hex: 0xA8813A))
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("초기 멤버 혜택. 우리 동네 1호 멤버 영구 뱃지")
    }
}

// MARK: - MkAvatarStack (공유 헬퍼)

/// 겹쳐진 아바타 스택 (크루 카드 참가자 표시용)
private struct MkAvatarStack: View {
    let count: Int
    private static let gradColors: [Color] = [
        Color(hex: 0xF3E4D2), Color(hex: 0xDCEFE6),
        Color(hex: 0xEDEBFB), Color(hex: 0xFBE6EE),
    ]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(Self.gradColors[i % Self.gradColors.count])
                    .frame(width: 22, height: 22)
                    .overlay { Circle().stroke(AppColors.surface, lineWidth: 1.5) }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("크루 — 활성") {
    NavigationStack {
        CrewScreen()
            .onAppear { }
    }
}

#Preview("크루 — 콜드스타트") {
    NavigationStack {
        CrewColdStartContent(onJoinWaitlist: { })
    }
}
#endif
