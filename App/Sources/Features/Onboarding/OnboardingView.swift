// Features/Onboarding/OnboardingView.swift
// BabyLog · 온보딩 플로우 (자기완결형 목업)
// Swift 5 / iOS 17 / SwiftUI + Foundation only
// 팀장 통합 시: Shell/MainTabView 에서 onComplete 클로저 연결

import SwiftUI
import Foundation
import CoreLocation
import UserNotifications

// MARK: - 진입점

/// 온보딩 루트 뷰.
/// `onComplete` 는 팀장이 MainTabView 에서 연결 — 내부에서는 단계 전환만 담당.
struct OnboardingView: View {
    var onComplete: () -> Void
    @EnvironmentObject private var store: AppStore

    // 현재 단계 (0 스플래시 → 4 프리퍼미션)
    @State private var step: Int = 0

    // 2단계: 기록 밀도
    @State private var density: RecordDensity? = nil

    // 3단계: 임신/출산 분기
    @State private var phase: BabyPhase = .baby
    @State private var nickname: String = ""
    @State private var dueOrBirthDate: Date = Date()
    @State private var dateEntered: Bool = false

    // 4단계: 권한 — 실제 시스템 프롬프트 + 카드 상태 반영
    @StateObject private var locationCoordinator = LocationPermissionCoordinator()
    @State private var locationStatus: PermissionUIState = .undetermined
    @State private var notificationStatus: PermissionUIState = .undetermined

    private let totalSteps = 5   // 스텝 0~4, 진행바는 1~3 구간 표시

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                // 상단 진행바 (스텝 1~3 구간)
                if step > 0 && step < totalSteps - 1 {
                    progressBar
                        .padding(.horizontal, Spacing.s5)
                        .padding(.top, Spacing.s6)
                        .padding(.bottom, Spacing.s2)
                }

                // 본문 단계별 뷰
                Group {
                    switch step {
                    case 0: splashStep
                    case 1: previewStep
                    case 2: densityStep
                    case 3: registerStep
                    case 4: permissionStep
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.28), value: step)
            }
        }
    }

    // MARK: - 진행바

    private var progressBar: some View {
        HStack(spacing: 5) {
            // 스텝 1·2·3 — 총 3구간
            ForEach(1..<4, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppColors.primary : AppColors.surface3)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("온보딩 \(min(step, 3))단계 / 3단계 완료")
    }

    // MARK: - 공통 다음 버튼

    private func nextButton(title: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        LiquidButton(
            fill: disabled ? AppColors.surface3 : AppColors.primary,
            action: action
        ) {
            Text(title)
                .foregroundStyle(disabled ? AppColors.ink3 : AppColors.onPrimary)
        }
        .disabled(disabled)
        .accessibilityLabel(title)
    }

    private func skipButton(title: String = "나중에 할게요", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.subhead)
                .foregroundStyle(AppColors.ink3)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel(title)
    }

    // MARK: - 스텝 0: 스플래시

    private var splashStep: some View {
        VStack(spacing: 0) {
            Spacer()

            // 앱 아이콘 + 이름
            VStack(spacing: Spacing.s6) {
                // 아이콘 배경
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryPress],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .blShadow(.sheet)

                    // 하트 + 아기 아이콘 (SF Symbols 조합)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                .accessibilityHidden(true)

                VStack(spacing: Spacing.s3) {
                    // 앱 이름
                    HStack(spacing: 0) {
                        Text("Baby")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(AppColors.ink)
                        Text("Log")
                            .font(.system(size: 32, weight: .heavy))
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityLabel("BabyLog")

                    Text("우리 동네 육아의\n모든 것")
                        .font(AppFont.h2)
                        .foregroundStyle(AppColors.ink2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            // CTA 영역
            VStack(spacing: Spacing.s1) {
                nextButton(title: "시작하기") {
                    advance()
                }

                Button {
                    onComplete()
                } label: {
                    Text("이미 계정이 있어요")
                        .font(AppFont.subhead)
                        .foregroundStyle(AppColors.ink3)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
                .accessibilityLabel("이미 계정이 있어요 — 로그인")
            }
            .padding(.bottom, Spacing.s8)
        }
        .padding(.horizontal, Spacing.s5)
    }

    // MARK: - 스텝 1: 게스트 가치 미리보기

    private var previewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 타이틀
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text("가입 전에 먼저,\n지금 도움이 될 거예요")
                        .font(.system(size: 25, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                        .lineSpacing(3)

                    Text("망원동 기준 · 지금 영업 중인 소아과예요")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink2)
                }
                .padding(.top, Spacing.s6)

                // 야간 소아과 미리보기 카드들
                VStack(spacing: Spacing.s3) {
                    previewClinicCard(
                        name: "행복소아과",
                        distance: "230m",
                        isNight: true
                    )
                    previewClinicCard(
                        name: "미래아동병원",
                        distance: "480m",
                        isNight: false
                    )
                }
                .padding(.top, Spacing.s5)

                // 게스트 안내 카드
                BLCard(padding: Spacing.s3, flat: true) {
                    HStack(spacing: Spacing.s3) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.primary)
                            .accessibilityHidden(true)
                        Text("가입하지 않아도 둘러볼 수 있어요. 마음에 들면 그때 시작하세요.")
                            .font(AppFont.callout)
                            .foregroundStyle(AppColors.ink2)
                            .lineSpacing(3)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .stroke(AppColors.primarySoft, lineWidth: 1)
                )
                .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .padding(.top, Spacing.s4)

                // CTA
                VStack(spacing: Spacing.s1) {
                    nextButton(title: "좋아요, 시작할게요") { advance() }
                    skipButton(title: "나중에 할게요") { onComplete() }
                }
                .padding(.top, Spacing.s5)
                .padding(.bottom, Spacing.s8)
            }
            .padding(.horizontal, Spacing.s5)
        }
    }

    private func previewClinicCard(name: String, distance: String, isNight: Bool) -> some View {
        BLCard(padding: 14, flat: true) {
            HStack(spacing: Spacing.s3) {
                // 아이콘 배경
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BadgeTone.coral.bg)
                        .frame(width: 44, height: 44)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(BadgeTone.coral.ink)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(AppFont.title)
                        .foregroundStyle(AppColors.ink)
                    Text("\(distance) · \(isNight ? "야간진료" : "진료중")")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)

                Spacer()

                BLBadge(tone: .mint, text: "영업중", systemIcon: "circle.fill")
            }
        }
        .accessibilityLabel("\(name), \(distance), \(isNight ? "야간진료 가능" : "진료중"), 현재 영업중")
    }

    // MARK: - 스텝 2: 기록 밀도

    private var densityStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 타이틀
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("기록은 어떻게 할까요?")
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(AppColors.ink)

                Text("나중에 언제든 바꿀 수 있어요")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink2)
            }
            .padding(.top, Spacing.s6)

            // 밀도 선택 카드
            VStack(spacing: Spacing.s3) {
                densityCard(
                    kind: .light,
                    icon: "camera.fill",
                    iconColor: density == .light ? AppColors.onPrimary : AppColors.primary,
                    title: "가볍게",
                    description: "사진 한 장이면 충분해요. 바쁜 날도 부담 없이."
                )
                densityCard(
                    kind: .rich,
                    icon: "book.fill",
                    iconColor: density == .rich ? AppColors.onPrimary : AppColors.primary,
                    title: "꼼꼼히",
                    description: "키·몸무게·이정표까지 풍부하게 남길래요."
                )
            }
            .padding(.top, Spacing.s5)

            Spacer()

            // CTA
            VStack(spacing: Spacing.s1) {
                nextButton(
                    title: "다음",
                    disabled: density == nil
                ) { advance() }
                skipButton { advance() }
            }
            .padding(.bottom, Spacing.s8)
        }
        .padding(.horizontal, Spacing.s5)
    }

    private func densityCard(kind: RecordDensity, icon: String, iconColor: Color, title: String, description: String) -> some View {
        let isOn = density == kind
        return Button {
            density = kind
        } label: {
            HStack(spacing: 14) {
                // 아이콘 셀
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isOn ? AppColors.primary : AppColors.primaryTint)
                        .frame(width: 52, height: 52)
                        .animation(.easeInOut(duration: 0.2), value: isOn)
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor)
                }
                .accessibilityHidden(true)

                // 텍스트
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text(description)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 라디오 인디케이터 (색+아이콘 2중 인코딩)
                ZStack {
                    Circle()
                        .fill(isOn ? AppColors.primary : Color.clear)
                        .frame(width: 24, height: 24)
                    Circle()
                        .stroke(isOn ? AppColors.primary : AppColors.line2, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.onPrimary)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isOn)
                .accessibilityHidden(true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(isOn ? AppColors.primary : Color.clear, lineWidth: 2)
            )
            .blShadow(.card)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(title) — \(description)")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - 스텝 3: 임신/출산 등록

    private var registerStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 타이틀 (phase에 따라 변경)
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text(phase == .pregnancy ? "임신을 축하해요" : "아이를 알려주세요")
                        .font(.system(size: 25, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    Text(phase == .pregnancy
                         ? "예정일만 있으면 시작할 수 있어요"
                         : "생일만 있으면 시작할 수 있어요")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink2)
                }
                .padding(.top, Spacing.s6)

                // 임신/출산 분기 토글
                HStack(spacing: Spacing.s2) {
                    phaseToggleButton(kind: .baby,      label: "👶 출산했어요")
                    phaseToggleButton(kind: .pregnancy, label: "🤰 임신 중이에요")
                }
                .padding(.top, Spacing.s5)

                // 사진 자리
                VStack(spacing: Spacing.s3) {
                    ZStack {
                        PhotoPlaceholder(seed: phase == .pregnancy ? 3 : 0, cornerRadius: 26)
                            .frame(width: 96, height: 96)
                        Text(phase == .pregnancy ? "🤰" : "")
                            .font(.system(size: 40))
                        if phase == .baby {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .accessibilityLabel(phase == .pregnancy ? "임신 중 이모지" : "사진 추가 버튼")

                    Text("사진 추가 (선택)")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s5)

                // 입력 필드
                VStack(spacing: Spacing.s3) {
                    // 이름/태명 입력
                    inputField(
                        label: "이름 또는 태명",
                        placeholder: phase == .pregnancy ? "튼튼이" : "지호",
                        text: $nickname
                    )

                    // 예정일/생일 입력
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text(phase == .pregnancy ? "출산 예정일" : "생년월일")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                            .fontWeight(.semibold)

                        DatePicker(
                            "",
                            selection: $dueOrBirthDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.graphical)
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.s2)
                        .padding(.vertical, Spacing.s2)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(AppColors.line, lineWidth: 1)
                        )
                        .onChange(of: dueOrBirthDate) { _, _ in
                            dateEntered = true
                        }
                    }
                }
                .padding(.top, Spacing.s4)

                // 타임라인 자동 생성 안내 (날짜 입력 시 노출)
                if dateEntered {
                    BLCard(padding: Spacing.s3, flat: true) {
                        HStack(spacing: Spacing.s2) {
                            Text(phase == .pregnancy ? "🌸" : "🎉")
                                .font(.system(size: 16))
                                .accessibilityHidden(true)
                            Text(phase == .pregnancy
                                 ? "임신 주차와 산전검진 일정이 자동으로 만들어졌어요"
                                 : "예방접종 타임라인이 자동으로 만들어졌어요")
                                .font(AppFont.caption)
                                .foregroundStyle(
                                    phase == .pregnancy
                                    ? AppColors.pregnancyPink
                                    : Color(hex: 0x98711E)
                                )
                                .fontWeight(.semibold)
                                .lineSpacing(2)
                        }
                    }
                    .background(
                        phase == .pregnancy
                        ? BadgeTone.pink.bg
                        : AppColors.goldTint,
                        in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    )
                    .padding(.top, Spacing.s4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeOut(duration: 0.3), value: dateEntered)
                }

                // CTA
                VStack(spacing: Spacing.s1) {
                    nextButton(title: "다음") { advance() }
                    skipButton { advance() }
                }
                .padding(.top, Spacing.s5)
                .padding(.bottom, Spacing.s8)
            }
            .padding(.horizontal, Spacing.s5)
        }
    }

    private func phaseToggleButton(kind: BabyPhase, label: String) -> some View {
        let isOn = phase == kind
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { phase = kind }
        } label: {
            Text(label)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(isOn ? AppColors.primaryPress : AppColors.ink2)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isOn ? AppColors.primaryTint : AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .stroke(isOn ? AppColors.primary : AppColors.line, lineWidth: 2)
                )
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink3)
                .fontWeight(.semibold)

            TextField(placeholder, text: text)
                .font(AppFont.body)
                .padding(.horizontal, Spacing.s4)
                .frame(height: 52)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                )
                .accessibilityLabel(label)
        }
    }

    // MARK: - 스텝 4: 프리퍼미션

    private var permissionStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 타이틀
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("두 가지만\n허락해주세요")
                    .font(.system(size: 25, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .lineSpacing(3)

                Text("꼭 필요할 때만, 이유와 함께 요청해요")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink2)
            }
            .padding(.top, Spacing.s6)

            // 권한 카드들 — 탭하면 실제 iOS 시스템 권한 프롬프트
            VStack(spacing: Spacing.s3) {
                permissionCard(
                    icon: "location.fill",
                    iconBg: BadgeTone.blue.bg,
                    iconFg: BadgeTone.blue.ink,
                    title: "위치",
                    description: "근처 소아과·약국을 보여드릴게요",
                    accessibilityHint: "위치 권한 — 근처 소아과와 약국 표시에 사용",
                    state: locationStatus,
                    action: requestLocation
                )
                permissionCard(
                    icon: "bell.fill",
                    iconBg: AppColors.goldTint,
                    iconFg: Color(hex: 0x98711E),
                    title: "알림",
                    description: "접종일·지원금 마감을 놓치지 않게요",
                    accessibilityHint: "알림 권한 — 접종일과 지원금 마감 알림에 사용",
                    state: notificationStatus,
                    action: requestNotifications
                )
            }
            .padding(.top, Spacing.s5)
            .onAppear { syncPermissionStates() }
            .onReceive(locationCoordinator.$authorization) { status in
                locationStatus = PermissionUIState(location: status)
            }

            Spacer()

            // CTA
            VStack(spacing: Spacing.s1) {
                LiquidButton(action: { finish() }) {
                    Text("BabyLog 시작하기")
                }
                .accessibilityLabel("BabyLog 시작하기")

                skipButton(title: "나중에 설정할게요") { finish() }
            }
            .padding(.bottom, Spacing.s8)
        }
        .padding(.horizontal, Spacing.s5)
    }

    private func permissionCard(icon: String, iconBg: Color, iconFg: Color, title: String, description: String, accessibilityHint: String, state: PermissionUIState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BLCard(padding: 16) {
                HStack(spacing: Spacing.s3) {
                    // 아이콘 (색+아이콘 2중 인코딩)
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(iconBg)
                            .frame(width: 48, height: 48)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundStyle(iconFg)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text(description)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink2)
                            .lineSpacing(2)
                    }
                    .accessibilityElement(children: .combine)

                    Spacer(minLength: Spacing.s2)

                    // 상태 표시 (색+아이콘+레이블 3중 인코딩)
                    permissionStatusTag(state)
                }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .disabled(state == .granted)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(state.accessibilityValue)
    }

    @ViewBuilder
    private func permissionStatusTag(_ state: PermissionUIState) -> some View {
        switch state {
        case .undetermined:
            Text("허용하기")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.primary)
        case .granted:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("허용됨")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(BadgeTone.mint.ink)
        case .denied:
            Text("설정에서 변경")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
        }
    }

    // MARK: - 단계 전환

    private func advance() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if step < totalSteps - 1 {
                step += 1
            } else {
                finish()
            }
        }
    }

    /// 완료 — 입력한 아이/임신을 AppStore에 기록한 뒤 onComplete.
    private func finish() {
        let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            if phase == .baby {
                store.completeBabyOnboarding(name: name, birthDate: dueOrBirthDate, gender: nil)
            } else {
                store.startPregnancy(lmp: nil, edd: dueOrBirthDate, nickname: name)
            }
        }
        onComplete()
    }

    // MARK: - 권한 요청

    /// 위치 권한 — CLLocationManager 를 코디네이터가 강하게 보유한 채 시스템 프롬프트.
    private func requestLocation() {
        Haptics.light()
        guard locationStatus == .undetermined else {
            // 이미 결정됨 → 미결정만 직접 프롬프트, 그 외엔 상태만 갱신.
            syncPermissionStates()
            return
        }
        locationCoordinator.request()
    }

    /// 알림 권한 — UNUserNotificationCenter 시스템 프롬프트.
    private func requestNotifications() {
        Haptics.light()
        guard notificationStatus == .undetermined else {
            syncPermissionStates()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationStatus = granted ? .granted : .denied
            }
        }
    }

    /// 현재 시스템 권한 상태를 카드 UI 상태로 동기화.
    private func syncPermissionStates() {
        locationStatus = PermissionUIState(location: locationCoordinator.authorization)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = PermissionUIState(notification: settings.authorizationStatus)
            }
        }
    }
}

// MARK: - 보조 타입

/// 권한 카드의 단순 UI 상태 (색+아이콘+레이블 3중 인코딩용).
private enum PermissionUIState: Equatable {
    case undetermined  // 아직 묻지 않음 → "허용하기"
    case granted       // 허용됨
    case denied        // 거부됨 → "설정에서 변경"

    init(location status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: self = .granted
        case .denied, .restricted:                    self = .denied
        case .notDetermined:                          self = .undetermined
        @unknown default:                             self = .undetermined
        }
    }

    init(notification status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .granted
        case .denied:                               self = .denied
        case .notDetermined:                        self = .undetermined
        @unknown default:                           self = .undetermined
        }
    }

    var accessibilityValue: String {
        switch self {
        case .undetermined: return "허용하기"
        case .granted:      return "허용됨"
        case .denied:       return "거부됨, 설정에서 변경 가능"
        }
    }
}

/// CLLocationManager 를 강하게 보유하고 권한 변경을 게시하는 코디네이터.
/// (매니저가 프롬프트 표시 전에 해제되지 않도록 @StateObject 로 생존시킴)
private final class LocationPermissionCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var authorization: CLAuthorizationStatus

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorization = manager.authorizationStatus
        }
    }
}

private enum RecordDensity: Equatable {
    case light, rich
}

private enum BabyPhase: Equatable {
    case baby, pregnancy
}

// MARK: - 미리보기

#if DEBUG
#Preview("온보딩") {
    OnboardingView(onComplete: { print("온보딩 완료") })
        .environmentObject(SampleData.store())
}
#endif
