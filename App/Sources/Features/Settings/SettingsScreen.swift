import SwiftUI
import UIKit

// MARK: - SettingsScreen

/// 앱 설정 화면 — ProfileScreen 기어 버튼에서 진입.
/// AppStorage 키 목록:
///   bl_theme          "system|light|dark"      화면 테마
///   bl_night_dim      Bool                     야간 초저휘도 모드
///   bl_fab_side       "right|left"             FAB 위치
///   bl_caregiver_title "양육자|맘|파파"          호칭
struct SettingsScreen: View {

    // MARK: AppStorage

    @AppStorage("bl_theme")            private var theme: String           = "system"
    @AppStorage("bl_night_dim")        private var nightDim: Bool          = false
    @AppStorage("bl_fab_side")         private var fabSide: String         = "right"
    @AppStorage("bl_caregiver_title")  private var caregiverTitle: String  = "양육자"
    @AppStorage("bl_nickname")         private var nickname: String        = "양육자님"
    @State private var showOpenSource = false

    // MARK: Environment

    @EnvironmentObject private var store: AppStore

    // MARK: State

    @State private var exportURL: URL?   = nil
    @State private var showShareSheet    = false
    @State private var showExportError   = false

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s4) {
                displaySection
                quickRecordSection
                caregiverSection
                notificationSection
                dataSection
                infoSection
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.large)
        .alert("오픈소스 고지", isPresented: $showOpenSource) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("BabyLog는 Apple 시스템 프레임워크(SwiftUI·Swift Charts·WidgetKit 등)로 제작되었습니다. 추가 서드파티 오픈소스를 도입하면 이 화면에 라이선스를 명시합니다.")
        }
        // 설정 변경 미세 피드백 (§8.5)
        .sensoryFeedback(.selection, trigger: theme)
        .sensoryFeedback(.selection, trigger: fabSide)
        .sensoryFeedback(.selection, trigger: caregiverTitle)
        .sensoryFeedback(.impact(weight: .light), trigger: nightDim)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                SettingsShareSheet(activityItems: [url])
            }
        }
        .alert("내보내기 실패", isPresented: $showExportError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("데이터를 준비하는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    // MARK: - 화면 섹션

    private var displaySection: some View {
        settingsSection(eyebrow: "화면", title: "테마 · 야간 모드") {
            // 테마 선택
            settingsRow(
                icon: "paintpalette.fill",
                iconBg: Color(hex: 0xEEEDFE),
                iconFg: Color(hex: 0x5B53B0)
            ) {
                HStack {
                    Text("테마")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    themePickerMenu
                }
            }

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 야간 초저휘도 모드
            settingsRow(
                icon: "moon.fill",
                iconBg: Color(hex: 0x1A1A2E).opacity(0.12),
                iconFg: Color(hex: 0x5B5BA8)
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("야간 초저휘도 모드")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                            Text("22시~06시 자동 적용 — 새벽 수유 시 아이를 깨우지 않아요")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppColors.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Toggle("", isOn: $nightDim)
                            .labelsHidden()
                            .tint(AppColors.primary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("야간 초저휘도 모드. 22시~06시 자동 적용. \(nightDim ? "켜짐" : "꺼짐")")
            .accessibilityAddTraits(.isToggle)
        }
    }

    // 테마 피커 — Picker(segmented) 대신 Menu로 콤팩트하게
    private var themePickerMenu: some View {
        Menu {
            Button {
                theme = "system"
            } label: {
                Label("시스템 기본", systemImage: theme == "system" ? "checkmark" : "")
            }
            Button {
                theme = "light"
            } label: {
                Label("라이트", systemImage: theme == "light" ? "checkmark" : "")
            }
            Button {
                theme = "dark"
            } label: {
                Label("다크", systemImage: theme == "dark" ? "checkmark" : "")
            }
        } label: {
            HStack(spacing: Spacing.s1) {
                Text(themeDisplayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.ink2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
            }
            .padding(.horizontal, Spacing.s3)
            .frame(height: 32)
            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .accessibilityLabel("테마 선택. 현재 \(themeDisplayName)")
    }

    private var themeDisplayName: String {
        switch theme {
        case "light":  return "라이트"
        case "dark":   return "다크"
        default:       return "시스템"
        }
    }

    // MARK: - 빠른 기록 섹션

    private var quickRecordSection: some View {
        settingsSection(eyebrow: "빠른 기록", title: "FAB 위치") {
            settingsRow(
                icon: "hand.point.up.left.fill",
                iconBg: Color(hex: 0xDCEFE6),
                iconFg: Color(hex: 0x2E7A5C)
            ) {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("빠른 기록 버튼 위치")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                            Text("아이를 안고 한 손으로 조작하기 편한 쪽을 선택하세요")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppColors.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }

                    // 좌/우 선택 세그먼트
                    HStack(spacing: Spacing.s2) {
                        fabSideButton(label: "우하단", value: "right", icon: "hand.point.down.left.fill")
                        fabSideButton(label: "좌하단", value: "left",  icon: "hand.point.down.right.fill")
                    }
                }
            }
        }
    }

    private func fabSideButton(label: String, value: String, icon: String) -> some View {
        let selected = fabSide == value
        return Button {
            fabSide = value
        } label: {
            HStack(spacing: Spacing.s2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 13.5, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : AppColors.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                selected ? AppColors.primary : AppColors.surface2,
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(selected ? Color.clear : AppColors.line, lineWidth: 1)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(label) 선택\(selected ? " — 현재 선택됨" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 호칭 섹션

    private var caregiverSection: some View {
        settingsSection(eyebrow: "호칭", title: "양육자 호칭") {
            settingsRow(
                icon: "person.fill",
                iconBg: Color(hex: 0xFBEAF0),
                iconFg: Color(hex: 0xB5478A)
            ) {
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    // 프로필에 표시되는 이름 (내정보 헤더와 실연동)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("프로필 이름")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                        TextField("양육자님", text: $nickname)
                            .font(AppFont.body)
                            .padding(.horizontal, Spacing.s3)
                            .frame(height: 44)
                            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .submitLabel(.done)
                            .accessibilityLabel("프로필 이름 입력")
                    }

                    Divider().background(AppColors.line)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("나를 부르는 호칭")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                        Text("BabyLog는 모든 양육자를 환영합니다 — 아빠·조부모·다양한 가족")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: Spacing.s2) {
                        caregiverButton(title: "양육자", subtitle: "기본·중립")
                        caregiverButton(title: "맘",     subtitle: "엄마 호칭")
                        caregiverButton(title: "파파",   subtitle: "아빠 호칭")
                    }
                }
            }
        }
    }

    private func caregiverButton(title: String, subtitle: String) -> some View {
        let selected = caregiverTitle == title
        return Button {
            caregiverTitle = title
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .regular))
            }
            .foregroundStyle(selected ? Color.white : AppColors.ink2)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                selected ? AppColors.primary : AppColors.surface2,
                in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(selected ? Color.clear : AppColors.line, lineWidth: 1)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel("\(title) (\(subtitle))\(selected ? " — 현재 선택됨" : "")")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 알림 섹션

    private var notificationSection: some View {
        settingsSection(eyebrow: "알림", title: "알림 관리") {
            // 필수 알림 안내
            settingsRow(
                icon: "bell.badge.fill",
                iconBg: Color(hex: 0xFAEEDA),
                iconFg: Color(hex: 0x98711E)
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("필수 알림 (접종 · 지원금)")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text("예방접종·정부 지원금 등 중요 알림. 개인화 추천·마케팅과 완전히 분리됩니다")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 권유 알림 안내
            settingsRow(
                icon: "bell.slash.fill",
                iconBg: Color(hex: 0xEFF1F4),
                iconFg: AppColors.ink3
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("권유 알림 (기록 유도 · 콘텐츠)")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text("오래 미접속 시 자동으로 빈도를 줄여요. 상실·민감 시기엔 즉시 중단됩니다")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 시스템 설정 열기
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                settingsRow(
                    icon: "gear",
                    iconBg: AppColors.surface3,
                    iconFg: AppColors.ink2,
                    showChevron: true
                ) {
                    Text("알림 시스템 설정 열기")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 데이터 섹션

    private var dataSection: some View {
        settingsSection(eyebrow: "데이터", title: "내 데이터") {
            // 내 데이터 내보내기
            Button {
                handleExport()
            } label: {
                settingsRow(
                    icon: "square.and.arrow.up.fill",
                    iconBg: Color(hex: 0xEEEDFE),
                    iconFg: Color(hex: 0x5B53B0),
                    showChevron: true
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("내 데이터 내보내기")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                        Text("JSON 표준 포맷 — 언제든, 어디서든 사용 가능")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 원칙 고지 카드
            dataPrincipleNotice
        }
    }

    private var dataPrincipleNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
                Text("BabyLog 데이터 3대 원칙")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.ink)
            }

            VStack(alignment: .leading, spacing: Spacing.s2) {
                principleRow(icon: "hand.raised.slash.fill",
                             text: "아동 데이터는 절대 외부에 판매하지 않습니다")
                principleRow(icon: "archivebox.fill",
                             text: "무료 사용자의 데이터도 영구 보존합니다 — 인질극 없이")
                principleRow(icon: "icloud.slash.fill",
                             text: "사진은 내 기기·iCloud에만 저장됩니다 (서버 비전송)")
            }
        }
        .padding(Spacing.s4)
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BabyLog 데이터 3대 원칙: 데이터 비매각, 영구 보존, 사진 서버 비전송")
    }

    private func principleRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(AppColors.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 정보 섹션

    private var infoSection: some View {
        settingsSection(eyebrow: "정보", title: "앱 정보") {
            // 버전
            settingsRow(
                icon: "info.circle.fill",
                iconBg: Color(hex: 0xE6F1FB),
                iconFg: Color(hex: 0x3B6FA8)
            ) {
                HStack {
                    Text("버전")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Spacer()
                    Text(appVersion)
                        .font(AppFont.num(14))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .accessibilityLabel("버전 \(appVersion)")

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 오픈소스 고지
            Button {
                showOpenSource = true
            } label: {
            settingsRow(
                icon: "doc.text.fill",
                iconBg: Color(hex: 0xEFF1F4),
                iconFg: AppColors.ink3,
                showChevron: true
            ) {
                Text("오픈소스 고지")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
            }
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 의료 면책
            settingsRow(
                icon: "cross.circle.fill",
                iconBg: Color(hex: 0xFAEEDA),
                iconFg: Color(hex: 0x98711E)
            ) {
                Text("이 앱은 의료 상담을 대체하지 않습니다. 건강 이상 시 전문 의료기관을 방문하세요.")
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityLabel("의료 면책 고지: 이 앱은 의료 상담을 대체하지 않습니다.")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - Helpers

    /// 데이터 내보내기 실행
    private func handleExport() {
        let state = store.snapshot()
        if let url = try? DataExporter.exportToTemporaryFile(state) {
            exportURL = url
            showShareSheet = true
        } else {
            showExportError = true
        }
    }

    // MARK: - Layout Helpers

    /// 섹션 컨테이너 — BLSectionHead + BLCard
    private func settingsSection<Content: View>(
        eyebrow: String,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: eyebrow, title: title)
            BLCard(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }

    /// 공용 설정 행 — 아이콘 + 콘텐츠 + 옵션 chevron
    @ViewBuilder
    private func settingsRow<Content: View>(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        showChevron: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: Spacing.s3) {
            // 아이콘 (색+아이콘+레이블 3중 인코딩 — accessibilityHidden here, label from parent)
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconFg)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .frame(minHeight: 64)
    }
}

// MARK: - SettingsShareSheet

/// UIActivityViewController 래퍼 (Settings 전용)
private struct SettingsShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        SettingsScreen()
    }
    .environmentObject(SampleData.store())
}
#endif
