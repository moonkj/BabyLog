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

struct CrewGroup: Identifiable {
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isActive {
                CrewActiveContent()
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
    @State private var showWrite = false
    @State private var selectedPost: CrewPost?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                meetupSection
                    .padding(.top, Spacing.s5)
                crewSection
                boardSection
                    .padding(.bottom, 100)
            }
        }
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
    }

    // MARK: 같이 가요
    private var meetupSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            BLSectionHead(
                eyebrow: "주변 모임",
                title: "같이 가요"
            )
            .padding(.horizontal, Spacing.s5)

            ForEach(store.crews) { meetup in
                NavigationLink(value: meetup) {
                    CrewMeetupCard(meetup: meetup)
                        .padding(.horizontal, Spacing.s5)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.bottom, Spacing.s6)
        .navigationDestination(for: CrewMeetup.self) { meetup in
            CrewMeetupDetail(meetup: meetup)
        }
    }

    // MARK: 비슷한 또래 크루
    private var crewSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            BLSectionHead(
                eyebrow: "반경 1km",
                title: "비슷한 또래 크루"
            )
            .padding(.horizontal, Spacing.s5)

            ForEach(crewGroups) { group in
                CrewGroupCard(group: group)
                    .padding(.horizontal, Spacing.s5)
            }
        }
        .padding(.bottom, Spacing.s6)
    }

    // MARK: 동네 게시판
    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                BLSectionHead(
                    eyebrow: "동네 이야기",
                    title: "동네 게시판"
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
                    .padding(.horizontal, 12).frame(height: 36)
                    .background(AppColors.primary, in: Capsule())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.95))
                .accessibilityLabel("글쓰기")
                .accessibilityHint("동네 게시판에 새 글을 작성합니다")
            }
            .padding(.horizontal, Spacing.s5)

            BLCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(store.crewPosts.enumerated()), id: \.element.id) { idx, post in
                        Button {
                            Haptics.light()
                            selectedPost = post
                        } label: {
                            CrewPostRow(post: post)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .overlay(alignment: .top) {
                                    if idx > 0 {
                                        Rectangle()
                                            .fill(AppColors.line)
                                            .frame(height: 1)
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
                        BLBadge(tone: meetup.hostTier.badgeTone, text: meetup.hostTier.rawValue, systemIcon: nil, dot: false)
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
                    store.toggleJoinCrew(meetup.id)
                } label: {
                    Text(isFull ? "마감" : (isJoined ? "참가중" : "참가"))
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(isFull ? AppColors.ink3 : (isJoined ? AppColors.ink2 : Color.white))
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(isFull ? AppColors.surface3 : (isJoined ? AppColors.surface2 : AppColors.ink),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.94))
                .disabled(isFull)
                .accessibilityLabel(isFull ? "마감" : (isJoined ? "참가 취소" : "참가"))
                .accessibilityHint(isFull ? "\(meetup.place) 모임. 정원이 가득 찼습니다" : "\(meetup.place) 모임. 남은 자리 \(spotsLeft)자리")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(meetup.place), \(meetup.when), \(meetup.joined)명 중 \(meetup.capacity)명 정원, 주최자 \(meetup.hostName)")
    }
}

// MARK: - CrewGroupCard

private struct CrewGroupCard: View {
    @EnvironmentObject private var store: AppStore
    let group: CrewGroup
    private var isJoined: Bool { store.isJoinedGroup(group.id) }
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

                // 가입 토글
                Button {
                    Haptics.selection()
                    store.toggleJoinGroup(group.id)
                } label: {
                    Text(isJoined ? "가입중" : "가입")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isJoined ? AppColors.ink2 : Color.white)
                        .padding(.horizontal, 14).frame(height: 40)
                        .background(isJoined ? AppColors.surface2 : AppColors.primary,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.94))
                .accessibilityLabel(isJoined ? "\(group.name) 가입 취소" : "\(group.name) 가입")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - CrewPostRow

private struct CrewPostRow: View {
    @EnvironmentObject private var store: AppStore
    let post: CrewPost
    private var isLiked: Bool { store.isCrewPostLiked(post.id) }
    private var likeCount: Int { post.likeCount + (isLiked ? 1 : 0) }
    private var replyCount: Int { store.crewPostReplyCount(post) }

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
                    store.toggleCrewPostLike(post.id)
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
    @AppStorage("crew_open_notify") private var crewNotifyRequested = false

    private let progressPercent: Double = 0.78
    private let remainingCount: Int = 22

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

            Text("망원동, 거의 다 모였어요")
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

            // 오픈 알림 신청 — 로컬 신청 토글
            Button {
                crewNotifyRequested.toggle()
                Haptics.success()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: crewNotifyRequested ? "bell.fill" : "bell.badge.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(crewNotifyRequested ? "오픈 알림 신청됨" : "오픈 알림 신청")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(crewNotifyRequested ? AppColors.primary : AppColors.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .blShadow(.chip)
            }
            .buttonStyle(LiquidPressStyle(scale: 0.975))
            .accessibilityLabel(crewNotifyRequested ? "오픈 알림 신청됨" : "오픈 알림 신청")
            .accessibilityHint("크루가 오픈되면 알림을 받습니다")
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

                    Text("지금 합류하면 영구 뱃지 + Pro 체험 + 마켓 수수료 면제를 드려요.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color(hex: 0xA8813A))
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("초기 멤버 혜택. 영구 뱃지, Pro 체험, 마켓 수수료 면제")
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
