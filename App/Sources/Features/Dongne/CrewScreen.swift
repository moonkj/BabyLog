// CrewScreen.swift
// BabyLog · Features/Dongne
// DongneTab의 "크루" 세그먼트에 임베드하여 사용합니다.
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - Crew Models

enum CrewPostCategory: String, CaseIterable {
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

enum CrewMeetupType: Hashable {
    case park, indoor

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

struct CrewMeetup: Identifiable, Hashable {
    let id: Int
    let place: String
    let when: String
    let hostName: String
    let hostTier: MarketSellerTier   // 재사용 (amber=골든맘, warm=따뜻한이웃)
    let joined: Int
    let capacity: Int
    let meetupType: CrewMeetupType
}

struct CrewGroup: Identifiable {
    let id: Int
    let name: String
    let memberCount: Int
    let distanceText: String
    let ageRange: String
    let interestTags: [String]
}

struct CrewPost: Identifiable {
    let id: Int
    let category: CrewPostCategory
    let authorName: String
    let timeText: String
    let title: String
    let replyCount: Int
    let likeCount: Int
}

// MARK: - Mock Data

private let crewMeetups: [CrewMeetup] = [
    CrewMeetup(id: 1, place: "망원한강공원 잔디밭",   when: "오늘 오후 3시",   hostName: "보리맘",  hostTier: .golden, joined: 5, capacity: 8, meetupType: .park),
    CrewMeetup(id: 2, place: "성산 실내놀이터",       when: "내일 오전 10시",  hostName: "하준이네", hostTier: .warm,   joined: 3, capacity: 6, meetupType: .indoor),
    CrewMeetup(id: 3, place: "마포구청 어린이공원",   when: "토 오후 2시",     hostName: "민서맘",  hostTier: .warm,   joined: 7, capacity: 10, meetupType: .park),
]

private let crewGroups: [CrewGroup] = [
    CrewGroup(id: 1, name: "망원 8-12개월 크루",    memberCount: 23, distanceText: "반경 500m", ageRange: "8–12개월",   interestTags: ["이유식", "공원 산책", "성장 기록"]),
    CrewGroup(id: 2, name: "마포 워킹맘 모임",      memberCount: 41, distanceText: "반경 1km",  ageRange: "6–18개월",   interestTags: ["육아 정보", "복직 준비", "어린이집"]),
    CrewGroup(id: 3, name: "한강뷰 아파트 이웃들",  memberCount: 17, distanceText: "같은 단지", ageRange: "0–24개월",   interestTags: ["직거래", "공동구매", "놀이터"]),
]

private let crewPosts: [CrewPost] = [
    CrewPost(id: 1, category: .info,     authorName: "서연이네", timeText: "10분 전",  title: "망원소아과 주말 대기 시간 공유해요 (오늘 기준)",              replyCount: 12, likeCount: 31),
    CrewPost(id: 2, category: .together, authorName: "지우맘",   timeText: "1시간 전", title: "내일 한강 나들이 같이 가실 분 계신가요? (유아차 OK)",          replyCount: 8,  likeCount: 14),
    CrewPost(id: 3, category: .consult,  authorName: "하준이네", timeText: "3시간 전", title: "8개월인데 아직 뒤집기를 잘 못해요 — 비슷한 경험 있으신 분?",  replyCount: 21, likeCount: 46),
    CrewPost(id: 4, category: .info,     authorName: "민서맘",   timeText: "어제",    title: "마포구 유아 발달 지원금 신청 방법 정리했어요",                  replyCount: 5,  likeCount: 28),
]

// MARK: - CrewScreen

/// DongneTab의 "크루" 세그먼트에 임베드하는 메인 뷰.
/// `isPreviewActive` 내부 토글로 콜드스타트 / 활성 상태 전환 가능 (팀 QA용).
struct CrewScreen: View {
    // 실제 서비스에서는 AppStore/ViewModel에서 주입
    @State private var isActive: Bool = false  // false = 콜드스타트(오픈 전), true = 활성

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isActive {
                CrewActiveContent()
            } else {
                CrewColdStartContent(onJoinWaitlist: { })
            }

            // 내부 미리보기 토글 (팀장 QA용 — 프로덕션에서 조건부 숨김 처리)
            previewToggle
        }
        .background(AppColors.canvas.ignoresSafeArea())
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
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                meetupSection
                    .padding(.top, Spacing.s5)
                crewSection
                boardSection
                    .padding(.bottom, Spacing.s7)
            }
        }
    }

    // MARK: 같이 가요
    private var meetupSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            BLSectionHead(
                eyebrow: "주변 모임",
                title: "같이 가요",
                action: "모임 만들기",
                onAction: { }
            )
            .padding(.horizontal, Spacing.s5)

            ForEach(crewMeetups) { meetup in
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
            BLSectionHead(
                eyebrow: "동네 이야기",
                title: "동네 게시판",
                action: "전체",
                onAction: { }
            )
            .padding(.horizontal, Spacing.s5)

            BLCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(crewPosts.enumerated()), id: \.element.id) { idx, post in
                        CrewPostRow(post: post)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 13)
                            .overlay(alignment: .top) {
                                if idx > 0 {
                                    Rectangle()
                                        .fill(AppColors.line)
                                        .frame(height: 1)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, Spacing.s5)
        }
    }
}

// MARK: - CrewMeetupCard

private struct CrewMeetupCard: View {
    let meetup: CrewMeetup

    private var spotsLeft: Int { meetup.capacity - meetup.joined }

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
                        MkAvatarStack(count: min(meetup.joined, 4))
                        Text("\(meetup.joined)/\(meetup.capacity)명")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)

                // 참가 버튼
                Button { } label: {
                    Text("참가")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(AppColors.ink, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.94))
                .accessibilityLabel("참가")
                .accessibilityHint("\(meetup.place) 모임에 참가합니다. 남은 자리 \(spotsLeft)자리")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(meetup.place), \(meetup.when), \(meetup.joined)명 중 \(meetup.capacity)명 정원, 주최자 \(meetup.hostName)")
    }
}

// MARK: - CrewGroupCard

private struct CrewGroupCard: View {
    let group: CrewGroup

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

                    Text("\(group.memberCount)명 · \(group.distanceText) · \(group.ageRange)")
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name), \(group.memberCount)명, \(group.distanceText), \(group.ageRange), 관심사: \(group.interestTags.joined(separator: " "))")
        .accessibilityHint("크루 상세 보기")
    }
}

// MARK: - CrewPostRow

private struct CrewPostRow: View {
    let post: CrewPost

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
                    Text("\(post.replyCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                .accessibilityLabel("댓글 \(post.replyCount)개")

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink3)
                    Text("\(post.likeCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                .accessibilityLabel("좋아요 \(post.likeCount)개")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.category.rawValue), \(post.authorName), \(post.timeText), \(post.title), 댓글 \(post.replyCount), 좋아요 \(post.likeCount)")
        .accessibilityHint("게시글 상세 보기")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - CrewColdStartContent (콜드스타트 = 기대감 UI)

private struct CrewColdStartContent: View {
    var onJoinWaitlist: () -> Void

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
                Image(systemName: "person.3.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
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
            // 친구 초대 — LiquidButton
            LiquidButton(fill: AppColors.ink, action: { }) {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 17, weight: .bold))
                    Text("친구 초대하고 빨리 열기")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .accessibilityLabel("친구 초대하고 빨리 열기")
            .accessibilityHint("친구를 초대하면 크루 오픈이 빨라집니다")

            // 오픈 알림 신청
            Button { } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("오픈 알림 신청")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .blShadow(.chip)
            }
            .buttonStyle(LiquidPressStyle(scale: 0.975))
            .accessibilityLabel("오픈 알림 신청")
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
