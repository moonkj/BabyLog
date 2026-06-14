// CrewMeetupDetail.swift
// BabyLog · Features/Dongne
// 크루 모임 상세 화면 (NavigationStack push 또는 sheet)
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - CrewMeetupDetail

struct CrewMeetupDetail: View {
    let meetup: CrewMeetup

    @EnvironmentObject private var store: AppStore
    @State private var showGroupChatGuide = false
    @State private var showChat = false
    @State private var showDeleteConfirm = false
    @State private var joinBusy = false   // 참가 토글 중복 탭 방지(서버 정합)
    @State private var deleteBusy = false   // 삭제 요청 중(중복 탭 방지)
    @State private var deleteFailed = false // 서버 삭제 실패 안내
    @State private var showLogin = false    // 로그인 게이트(참가·채팅)
    @Environment(\.dismiss) private var dismiss

    private var isJoined: Bool { store.isJoinedCrew(meetup.id) }
    private var joinedCount: Int { store.crewJoinedCount(meetup) }
    private var spotsLeft: Int { max(0, meetup.capacity - joinedCount) }
    private var isFull: Bool { joinedCount >= meetup.capacity && !isJoined }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroHeader
                    contentSection
                        .padding(.bottom, 96)
                }
            }
            .background(AppColors.canvas.ignoresSafeArea())

            bottomBar
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if meetup.mine {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("모임 삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColors.ink2)
                    }
                    .accessibilityLabel("모임 관리")
                }
            }
        }
        .sheet(isPresented: $showGroupChatGuide) {
            CrewGroupChatGuideSheet(meetup: meetup)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showLogin) {
            AppleLoginSheet(message: "모임 참가·채팅은 로그인이 필요해요.") {}
        }
        .sheet(isPresented: $showChat) {
            CrewChatSheet(meetup: meetup)
                .presentationDetents([.large])
                .environmentObject(store)
        }
        .confirmationDialog("이 모임을 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                guard !deleteBusy else { return }
                Haptics.warning()
                if SupabaseConfig.isConfigured {
                    // 서버가 원본: 실제 삭제를 확인한 뒤에만 로컬 삭제·닫기(재조회 시 부활 방지)
                    deleteBusy = true
                    Task { @MainActor in
                        let ok = await CrewBackend.deleteMeetup(meetupId: meetup.id)
                        deleteBusy = false
                        if ok {
                            store.deleteCrew(id: meetup.id)
                            dismiss()
                        } else {
                            deleteFailed = true
                        }
                    }
                } else {
                    // 미구성(로컬 데모): 기존 동작 유지
                    store.deleteCrew(id: meetup.id)
                    dismiss()
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제하면 되돌릴 수 없어요.")
        }
        .alert("삭제 실패", isPresented: $deleteFailed) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("모임을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 히어로 헤더
    private var heroHeader: some View {
        ZStack {
            // 배경 컬러 블록
            Rectangle()
                .fill(meetup.meetupType.bgColor)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 14) {
                // 모임 타입 아이콘
                ZStack {
                    Circle()
                        .fill(meetup.meetupType.iconColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: meetup.meetupType.systemIcon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(meetup.meetupType.iconColor)
                }
                .accessibilityHidden(true)

                Text(meetup.place)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)

                BLBadge(
                    tone: meetup.meetupType == .park ? .mint : .pink,
                    text: meetup.meetupType == .park ? "야외 모임" : "실내 모임",
                    systemIcon: meetup.meetupType.systemIcon,
                    dot: false
                )
            }
            .padding(.top, 52)
            .padding(.bottom, 20)
        }
        .accessibilityLabel("\(meetup.meetupType == .park ? "야외" : "실내") 모임. 장소: \(meetup.place)")
    }

    // MARK: 콘텐츠 섹션
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 일시/정원 인포
            meetingInfoCard

            // 참가자 아바타 섹션
            participantsSection

            // 호스트 카드
            hostCard

            // 그룹 채팅 안내
            groupChatCard

            // 안전 수칙
            safetyRule
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, 18)
    }

    // MARK: 모임 정보 카드
    private var meetingInfoCard: some View {
        BLCard(padding: 16) {
            VStack(spacing: 0) {
                CrewInfoRow(
                    icon: "calendar",
                    iconColor: AppColors.primary,
                    label: "일시",
                    value: meetup.when
                )
                Rectangle()
                    .fill(AppColors.line)
                    .frame(height: 1)
                    .padding(.vertical, 10)
                CrewInfoRow(
                    icon: "mappin.circle.fill",
                    iconColor: Color(hex: 0xB5478A),
                    label: "장소",
                    value: meetup.place
                )
                Rectangle()
                    .fill(AppColors.line)
                    .frame(height: 1)
                    .padding(.vertical, 10)
                CrewInfoRow(
                    icon: "person.2.fill",
                    iconColor: Color(hex: 0x3B6FA8),
                    label: "정원",
                    value: "\(joinedCount)/\(meetup.capacity)명 · 남은 자리 \(spotsLeft)자리"
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: 참가자 섹션
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
                Text("참가자 \(joinedCount)명")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.ink)
            }

            if joinedCount == 0 {
                Text("아직 참가자가 없어요. 첫 참가자가 되어보세요.")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                    .padding(.vertical, Spacing.s1)
            }

            // 아바타 그리드 — 실제 참가자 이름은 모르므로 익명 아바타로(가짜 이름 금지)
            HStack(spacing: 10) {
                ForEach(0..<min(joinedCount, 8), id: \.self) { i in
                    Circle()
                        .fill(CrewAvatarPalette.color(for: i))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .overlay { Circle().stroke(AppColors.surface, lineWidth: 2) }
                        .accessibilityHidden(true)
                }

                if joinedCount > 8 {
                    Circle()
                        .fill(AppColors.surface2)
                        .frame(width: 40, height: 40)
                        .overlay {
                            Text("+\(joinedCount - 8)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AppColors.ink3)
                        }
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("참가자 \(joinedCount)명")
    }

    // MARK: 호스트 카드
    private var hostCard: some View {
        BLCard(padding: 14, flat: true) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppColors.goldTint)
                        .frame(width: 44, height: 44)
                    Text(String(meetup.hostName.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(meetup.hostName)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        BLBadge(
                            tone: meetup.hostTier.badgeTone,
                            text: meetup.hostTier.rawValue,
                            systemIcon: nil,
                            dot: false
                        )
                    }

                    Text("모임 주최자")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }

                Spacer(minLength: 0)

                if meetup.mine {
                    BLBadge(tone: .mint, text: "내 모임", systemIcon: nil, dot: false)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("호스트 \(meetup.hostName), \(meetup.hostTier.rawValue)")
    }

    // MARK: 그룹 채팅 카드
    // 참가자 → 실제 채팅방 열기 / 비참가자 → 안내 시트(기존 동작 유지)
    private var groupChatCard: some View {
        Button {
            Haptics.selection()
            guard LoginGate.ready() else { showLogin = true; return }   // 로그인 필수(신상 특정)
            // 누구나 채팅 가능(참석 희망자·이웃 코디네이션). 미참가 상태면 채팅 입장과 함께 자동 참가
            // 처리해 알림 대상에 포함시킨다(crew_meetup_join). 호스트는 이미 참가 상태.
            if !isJoined {
                store.toggleJoinCrew(meetup.id)
                Task { _ = await CrewBackend.joinMeetup(meetupId: meetup.id) }
            }
            showChat = true
        } label: {
            BLCard(padding: 14, flat: true) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.primaryTint)
                            .frame(width: 44, height: 44)
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("채팅방 열기")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text("모임 참가자들과 바로 대화해보세요.")
                            .font(.system(size: 12.5, weight: .regular))
                            .foregroundStyle(AppColors.ink2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.99))
        .accessibilityLabel("채팅방 열기")
        .accessibilityHint("모임 채팅방을 엽니다. 미참가 시 참가 처리됩니다.")
    }

    // MARK: 안전 수칙
    private var safetyRule: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("안전을 위해 공공장소(공원·도서관 등)에서 모임을 진행하세요.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(3)
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .accessibilityLabel("안전 수칙: 공공장소에서 모임을 진행하세요.")
    }

    // MARK: 하단 고정 바
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.line)
                .frame(height: 1)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFull ? "정원 마감" : (isJoined ? "신청 완료" : "남은 자리 \(spotsLeft)자리"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isFull ? AppColors.ink3 : (isJoined ? AppColors.primary : AppColors.ink3))
                    Text(meetup.when)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                }
                .padding(.leading, Spacing.s5)

                Spacer(minLength: 12)

                LiquidButton(
                    fill: isFull ? AppColors.surface3 : (isJoined ? AppColors.ink3 : AppColors.primary),
                    action: {
                        guard !joinBusy else { return }
                        guard LoginGate.ready() else { showLogin = true; return }   // 로그인 필수
                        Haptics.selection()
                        let willJoin = !isJoined
                        store.toggleJoinCrew(meetup.id)
                        if SupabaseConfig.isConfigured {
                            joinBusy = true
                            Task {
                                let ok = willJoin
                                    ? await CrewBackend.joinMeetup(meetupId: meetup.id)
                                    : await CrewBackend.leaveMeetup(meetupId: meetup.id)
                                if !ok { store.toggleJoinCrew(meetup.id) }   // 실패 시 롤백
                                joinBusy = false
                            }
                        }
                    }
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: isFull ? "person.crop.circle.badge.xmark" : (isJoined ? "checkmark.circle.fill" : "person.badge.plus.fill"))
                            .font(.system(size: 16, weight: .bold))
                            .accessibilityHidden(true)
                        Text(isFull ? "마감" : (isJoined ? "신청됨" : "참가 신청"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(isFull ? AppColors.ink3 : AppColors.onPrimary)
                    .frame(height: 52)
                }
                .frame(maxWidth: 180)
                .disabled(isFull || joinBusy)
                .padding(.trailing, Spacing.s5)
                .accessibilityLabel(isFull ? "정원 마감" : (isJoined ? "참가 신청됨. 취소하려면 탭하세요." : "참가 신청하기"))
                .accessibilityHint(isFull ? "정원이 가득 찼습니다" : (isJoined ? "" : "모임에 참가합니다. 남은 자리 \(spotsLeft)자리."))
            }
            .padding(.vertical, 14)
            .background(AppColors.surface)
        }
    }
}

// MARK: - CrewInfoRow (헬퍼)

private struct CrewInfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.ink3)
                .frame(width: 36, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - CrewAvatarPalette (헬퍼)

private enum CrewAvatarPalette {
    private static let colors: [Color] = [
        AppColors.primary,
        Color(hex: 0xB5478A),
        Color(hex: 0x3B6FA8),
        Color(hex: 0xC9A961),
        Color(hex: 0x4E8268),
        Color(hex: 0xB45840),
    ]
    private static let initials = ["보", "하", "민", "서", "지", "태"]
    private static let names    = ["보리맘", "하준이네", "민서맘", "서연이네", "지우맘", "태양맘"]

    static func color(for index: Int) -> Color { colors[index % colors.count] }
    static func initial(for index: Int) -> String { initials[index % initials.count] }
    static func name(for index: Int) -> String { names[index % names.count] }
}

// MARK: - CrewGroupChatGuideSheet

private struct CrewGroupChatGuideSheet: View {
    let meetup: CrewMeetup
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryTint)
                        .frame(width: 72, height: 72)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                }
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text("그룹 채팅 자동 생성")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    Text("'\(meetup.place)' 모임에 참가하면\n전용 그룹 채팅방이 자동으로 만들어져요.\n모임 하루 전에 알림도 보내드릴게요.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                // 안내 항목들
                VStack(alignment: .leading, spacing: 12) {
                    CrewChatGuideRow(icon: "bell.fill", color: AppColors.primary, text: "모임 전날 오전 10시에 알림이 와요")
                    CrewChatGuideRow(icon: "map.fill", color: Color(hex: 0x3B6FA8), text: "채팅방에서 장소 지도를 바로 확인해요")
                    CrewChatGuideRow(icon: "shield.checkered", color: Color(hex: 0x4E8268), text: "공개 장소 모임 — 안전하게 만나요")
                }
                .padding(.horizontal, Spacing.s4)

                LiquidButton(action: { dismiss() }) {
                    Text("확인")
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.horizontal, Spacing.s5)
                .accessibilityLabel("확인")
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s6)
        }
        .background(AppColors.canvas)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - CrewChatGuideRow (헬퍼)

private struct CrewChatGuideRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

            Text(text)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(text)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("모임 상세 — 공원") {
    NavigationStack {
        CrewMeetupDetail(meetup: CrewMeetup(id: "pm1",
            place: "망원한강공원 잔디밭",
            when: "오늘 오후 3시",
            hostName: "보리맘",
            hostTier: .golden,
            joined: 5,
            capacity: 8,
            meetupType: .park
        ))
    }
}

#Preview("모임 상세 — 실내") {
    NavigationStack {
        CrewMeetupDetail(meetup: CrewMeetup(id: "pm2",
            place: "성산 실내놀이터",
            when: "내일 오전 10시",
            hostName: "하준이네",
            hostTier: .warm,
            joined: 3,
            capacity: 6,
            meetupType: .indoor
        ))
    }
}

#Preview("그룹 채팅 가이드") {
    CrewGroupChatGuideSheet(meetup: CrewMeetup(id: "pm1",
        place: "망원한강공원 잔디밭",
        when: "오늘 오후 3시",
        hostName: "보리맘",
        hostTier: .golden,
        joined: 5,
        capacity: 8,
        meetupType: .park
    ))
}
#endif
