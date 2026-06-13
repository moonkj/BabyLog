import SwiftUI
import UIKit
import UniformTypeIdentifiers

// 사업자 정보(BusinessInfo)·법적 고지 화면은 LegalNoticeScreen.swift로 분리.

// MARK: - SettingsScreen

/// 앱 설정 화면 — ProfileScreen 기어 버튼에서 진입.
/// (앱은 라이트 모드 고정 — BabyLogApp.preferredColorScheme(.light). 테마 설정 없음.)
/// AppStorage 키 목록:
///   bl_night_dim      Bool                     야간 초저휘도 모드
///   bl_fab_side       "right|left"             FAB 위치
///   bl_caregiver_title "양육자|맘|파파"          호칭(프로필 헤더에 역할로 표시)
struct SettingsScreen: View {

    // MARK: AppStorage

    @AppStorage("bl_night_dim")        private var nightDim: Bool          = false
    @AppStorage("bl_fab_side")         private var fabSide: String         = "right"
    @AppStorage("bl_caregiver_title")  private var caregiverTitle: String  = "양육자"
    @AppStorage("bl_nickname")         private var nickname: String        = "양육자님"
    @AppStorage("bl_cloud_sync")       private var cloudSync: Bool         = false
    @AppStorage("bl_memory_notif")     private var memoryNotif: Bool       = true
    @ObservedObject private var auth = AuthStore.shared
    @State private var showDeleteAccount = false
    @State private var authAlert: String? = nil
    @State private var cloudStatus: String? = nil
    @State private var cloudBusy = false
    @State private var showCloudRestoreConfirm = false

    // MARK: Environment

    @EnvironmentObject private var store: AppStore

    // MARK: State

    @State private var exportURL: URL?   = nil
    @State private var showShareSheet    = false
    @State private var showExportError   = false
    // 전체 백업(사진 포함)
    @AppStorage("bl_last_backup") private var lastBackupAt: Double = 0
    @State private var showBackupImporter = false
    @State private var backupBusy = false
    @State private var backupAlert: String? = nil

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 앱 공용 헤더(28pt) — 다른 탭과 통일
                BLScreenHeader(title: "설정", eyebrow: "환경설정")

                VStack(spacing: Spacing.s5) {
                    accountSection      // 로그인 — 최상단
                    caregiverSection    // 프로필 이름·호칭 — 최상단
                    displaySection
                    quickRecordSection
                    notificationSection
                    backupSection
                    iCloudSection
                    dataSection
                    infoSection
                }
                .padding(.horizontal, Spacing.s5)   // 헤더(s5)와 좌우 정렬
                .padding(.top, Spacing.s2)
                .padding(.bottom, Spacing.s8)
            }
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        // 설정 변경 미세 피드백 (§8.5)
        .sensoryFeedback(.selection, trigger: fabSide)
        .sensoryFeedback(.selection, trigger: caregiverTitle)
        .sensoryFeedback(.impact(weight: .light), trigger: nightDim)
        .sensoryFeedback(.impact(weight: .light), trigger: memoryNotif)
        // 추억 알림 토글 — 실제로 알림을 등록/취소(체감되는 실동작)
        .onChange(of: memoryNotif) { _, on in applyMemoryNotif(on) }
        .sheet(isPresented: $showShareSheet, onDismiss: {
            // 공유/저장 후 임시 파일 정리 — 반복 내보내기 시 tmp에 대용량 백업이 쌓이지 않도록.
            if let url = exportURL { try? FileManager.default.removeItem(at: url); exportURL = nil }
        }) {
            if let url = exportURL {
                SettingsShareSheet(activityItems: [url])
            }
        }
        .fileImporter(isPresented: $showBackupImporter,
                      allowedContentTypes: [UTType(filenameExtension: BackupService.fileExtension) ?? .data, .data]) { result in
            switch result {
            case .success(let url):
                // 큰 백업은 복원이 길어질 수 있어 "준비 중…" 표시가 먼저 그려지도록
                // 한 번 양보한 뒤 복원을 수행한다. restore는 @MainActor라 메인에서 실행.
                backupBusy = true
                Task { @MainActor in
                    // 어떤 경로(성공·실패·예외)에서도 버튼이 영구 비활성화되지 않도록 항상 리셋
                    defer { backupBusy = false }
                    await Task.yield()   // SwiftUI가 backupBusy=true 상태를 먼저 렌더
                    let ok = await BackupService.restore(from: url, into: store)
                    backupAlert = ok ? "백업에서 복원했어요. 사진과 기록이 돌아왔습니다 🤍" : "이 파일을 복원하지 못했어요. 올바른 백업 파일인지 확인해 주세요."
                }
            case .failure:
                backupBusy = false
                backupAlert = "파일을 열지 못했어요."
            }
        }
        .alert("백업", isPresented: Binding(get: { backupAlert != nil }, set: { if !$0 { backupAlert = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(backupAlert ?? "") }
        .alert("내보내기 실패", isPresented: $showExportError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("데이터를 준비하는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요.")
        }
        .confirmationDialog("계정을 삭제할까요?", isPresented: $showDeleteAccount, titleVisibility: .visible) {
            Button("계정 삭제", role: .destructive) {
                Task {
                    let ok = await auth.deleteAccount()
                    authAlert = ok
                        ? "계정을 삭제했어요. 작성한 글은 익명으로 남고 본인 식별만 해제됩니다."
                        : "계정 삭제를 처리하지 못했어요. 잠시 후 다시 시도해 주세요."
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("로그인 식별이 해제됩니다. 다른 기기에서 내 글로 다시 연결되지 않아요.")
        }
        .alert("계정", isPresented: Binding(get: { authAlert != nil }, set: { if !$0 { authAlert = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(authAlert ?? "") }
        .confirmationDialog("iCloud 백업으로 덮어쓸까요?", isPresented: $showCloudRestoreConfirm, titleVisibility: .visible) {
            Button("iCloud에서 복원", role: .destructive) { Task { await runCloud(.restore) } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 기기의 현재 기록을 iCloud 백업으로 덮어씁니다. iCloud 백업이 더 오래된 것이면 최근 기록이 사라질 수 있어요.")
        }
    }

    // MARK: - 계정 섹션 (Apple 로그인 — Supabase 연동 시에만 노출)

    @ViewBuilder
    private var accountSection: some View {
        if SupabaseConfig.isConfigured {
            settingsSection(eyebrow: "계정", title: "로그인") {
                if auth.isLoggedIn {
                    settingsRow(icon: "checkmark.seal.fill",
                                iconBg: AppColors.primarySoft, iconFg: AppColors.primary) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple로 로그인됨")
                                .font(.system(size: 14.5, weight: .bold)).foregroundStyle(AppColors.primary)
                            Text("기기를 바꿔도 내 글·모임이 유지돼요")
                                .font(.system(size: 12)).foregroundStyle(AppColors.ink2)
                        }
                    }
                    .accessibilityLabel("Apple로 로그인됨")

                    Divider().overlay(AppColors.line).padding(.leading, 62)

                    Button { Task { await auth.signOut() } } label: {
                        settingsRow(icon: "rectangle.portrait.and.arrow.right",
                                    iconBg: Color(hex: 0xEFF1F4), iconFg: AppColors.ink3, showChevron: true) {
                            Text("로그아웃")
                                .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(AppColors.line).padding(.leading, 62)

                    Button { showDeleteAccount = true } label: {
                        settingsRow(icon: "trash",
                                    iconBg: Color(hex: 0xFBE9E7), iconFg: AppColors.danger, showChevron: true) {
                            Text("계정 삭제")
                                .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.danger)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("계정 삭제")
                } else {
                    VStack(alignment: .leading, spacing: Spacing.s3) {
                        Text("로그인하면 기기를 바꿔도 내 글·모임이 유지되고, 본인 글만 수정·삭제할 수 있어요. 크루는 로그인 없이도 익명으로 참여할 수 있어요.")
                            .font(.system(size: 12.5)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                        AppleSignInButton { ok in
                            authAlert = ok ? "로그인했어요 🌿" : "로그인에 실패했어요. 잠시 후 다시 시도해 주세요."
                        }
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                }
            }
        }
    }

    // MARK: - 화면 섹션

    private var displaySection: some View {
        settingsSection(eyebrow: "화면", title: "야간 모드") {
            // 야간 초저휘도 모드
            settingsRow(
                icon: "moon.fill",
                iconBg: Color(hex: 0x1A1A2E).opacity(0.12),
                iconFg: Color(hex: 0x5B5BA8)
            ) {
                HStack(spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("야간 초저휘도 모드")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                        Text("22시~06시 자동 적용 — 새벽 수유 시 아이를 깨우지 않아요")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                        // 즉시 체감용 상태 — 낮엔 토글해도 화면이 안 어두워져 '안 됨'으로 보이는 오해 방지
                        if nightDim {
                            Text(isNightNow ? "● 지금 적용 중 — 화면이 어두워졌어요"
                                            : "○ 켜짐 — 밤 22시가 되면 자동으로 어두워져요")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(isNightNow ? AppColors.primary : AppColors.ink3)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: $nightDim)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("야간 초저휘도 모드. 22시~06시 자동 적용. \(nightDim ? "켜짐" : "꺼짐")")
            .accessibilityAddTraits(.isToggle)
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

                    Divider().overlay(AppColors.line)

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

    // MARK: - iCloud 가족 백업 (CloudKit)

    private var iCloudSection: some View {
        settingsSection(eyebrow: "백업", title: "iCloud 백업") {
            if CloudSyncService.isAvailableInBuild {
                // 자동 백업 토글
                settingsRow(icon: "icloud.fill", iconBg: Color(hex: 0xE6F1FB), iconFg: Color(hex: 0x3B6FA8)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Spacing.s3) {
                            Text("iCloud 자동 백업").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                            Spacer(minLength: 0)
                            Toggle("", isOn: $cloudSync).labelsHidden().tint(AppColors.primary)
                        }
                        Text("켜두면 앱을 닫을 때 기록을 내 iCloud에 자동 백업해요. 새 기기에서도 같은 iCloud 계정으로 복원할 수 있어요.")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider().overlay(AppColors.line).padding(.leading, 62)
                Button { Task { await runCloud(.backup) } } label: {
                    settingsRow(icon: "arrow.up.circle.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                        Text(cloudBusy ? "처리 중…" : "지금 백업").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                    }
                }.buttonStyle(.plain).disabled(cloudBusy).opacity(cloudBusy ? 0.5 : 1)
                Divider().overlay(AppColors.line).padding(.leading, 62)
                Button { showCloudRestoreConfirm = true } label: {
                    settingsRow(icon: "arrow.down.circle.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                        Text("iCloud에서 복원").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                    }
                }.buttonStyle(.plain).disabled(cloudBusy).opacity(cloudBusy ? 0.5 : 1)
                if let s = cloudStatus {
                    Text(s).font(AppFont.caption).foregroundStyle(AppColors.ink3)
                        .padding(.horizontal, Spacing.s4).padding(.bottom, Spacing.s2)
                }
            } else {
                settingsRow(icon: "icloud", iconBg: Color(hex: 0xE6F1FB), iconFg: Color(hex: 0x3B6FA8)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud 백업 (준비됨)").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("유료 Apple Developer 계정 + iCloud(CloudKit) 연결 시 켜져요. 켜면 기록을 내 iCloud에 자동 백업하고, 새 기기에서 복원할 수 있습니다.")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private enum CloudOp { case backup, restore }
    private func runCloud(_ op: CloudOp) async {
        cloudBusy = true; cloudStatus = nil
        defer { cloudBusy = false }
        do {
            switch op {
            case .backup:
                try await CloudSyncService.shared.push(store.snapshot())
                cloudStatus = "백업 완료 ✓"
            case .restore:
                if let remote = try await CloudSyncService.shared.pull() {
                    store.restore(remote)
                    cloudStatus = "복원 완료 ✓"
                } else {
                    cloudStatus = "iCloud에 백업이 없어요."
                }
            }
            Haptics.success()
        } catch {
            cloudStatus = (error as? CloudSyncError)?.errorDescription ?? "잠시 후 다시 시도해 주세요."
            Haptics.warning()
        }
    }

    // MARK: - 알림 섹션

    private var notificationSection: some View {
        settingsSection(eyebrow: "알림", title: "알림 관리") {
            // 추억 알림 토글 (실제 발송되는 유일한 알림 — 직접 켜고 끔)
            settingsRow(
                icon: "bell.badge.fill",
                iconBg: Color(hex: 0xFAEEDA),
                iconFg: Color(hex: 0x98711E)
            ) {
                HStack(spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("추억 알림")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                        Text("기록한 다이어리를 바탕으로 ‘N년 전 오늘’을 가끔 보여드려요. 광고·마케팅 알림은 없습니다.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: $memoryNotif)
                        .labelsHidden()
                        .tint(AppColors.primary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("추억 알림. \(memoryNotif ? "켜짐" : "꺼짐")")
            .accessibilityAddTraits(.isToggle)

            Divider()
                .overlay(AppColors.line)
                .padding(.leading, 62)

            // 민감 시기 보호 (민감영역 원칙)
            settingsRow(
                icon: "heart.slash.fill",
                iconBg: Color(hex: 0xEFF1F4),
                iconFg: AppColors.ink3
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("민감 시기 보호")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text("‘기록 멈춤’이나 상실 시 임신 주차·태아 가이드 알림을 즉시 중단합니다. 절대 닦달하지 않아요.")
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

    // MARK: - 데이터 백업 (사진 포함 전체)

    private var lastBackupText: String {
        guard lastBackupAt > 0 else { return "아직 백업하지 않았어요" }
        let days = Int(Date().timeIntervalSince1970 - lastBackupAt) / 86400
        if days <= 0 { return "오늘 백업함" }
        return "\(days)일 전 백업"
    }
    private var backupOverdue: Bool {
        lastBackupAt == 0 || (Date().timeIntervalSince1970 - lastBackupAt) > 86400 * 14
    }

    private var backupSection: some View {
        settingsSection(eyebrow: "백업", title: "데이터 백업 (사진 포함)") {
            // 안내 — 로컬 저장의 위험 고지
            settingsRow(icon: "exclamationmark.shield.fill",
                        iconBg: AppColors.goldTint, iconFg: AppColors.gold) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lastBackupText)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(backupOverdue ? AppColors.gold : AppColors.ink)
                    Text("앱을 삭제하면 기기 데이터가 사라져요. 사진·기록 전체를 파일로 백업해 두세요.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider().overlay(AppColors.line).padding(.leading, 62)

            // 전체 백업 내보내기
            Button { handleBackupExport() } label: {
                settingsRow(icon: "arrow.up.doc.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backupBusy ? "준비 중…" : "전체 백업 내보내기")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("사진·영상·기록을 파일 하나로 — 파일 앱/iCloud Drive에 저장")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.buttonStyle(.plain).disabled(backupBusy).opacity(backupBusy ? 0.5 : 1)

            Divider().overlay(AppColors.line).padding(.leading, 62)

            // 백업에서 복원
            Button { showBackupImporter = true } label: {
                settingsRow(icon: "arrow.down.doc.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("백업에서 복원")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("새 기기·재설치 후 백업 파일로 사진과 기록을 되살려요")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.buttonStyle(.plain).disabled(backupBusy).opacity(backupBusy ? 0.5 : 1)
        }
    }

    private func handleBackupExport() {
        backupBusy = true
        Task { @MainActor in
            defer { backupBusy = false }
            if let url = await BackupService.makeArchive(store) {
                exportURL = url
                lastBackupAt = Date().timeIntervalSince1970
                showShareSheet = true
            } else {
                showExportError = true
            }
        }
    }

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

            // 법적 고지 및 약관 (개인정보처리방침·오픈소스·사업자 정보)
            NavigationLink {
                LegalNoticeScreen()
            } label: {
                settingsRow(
                    icon: "doc.text.fill",
                    iconBg: Color(hex: 0xEFF1F4),
                    iconFg: AppColors.ink3,
                    showChevron: true
                ) {
                    Text("법적 고지 및 약관")
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

    /// 현재 시각이 야간(22~06시)인지 — 야간모드 토글의 즉시 상태 표시용.
    private var isNightNow: Bool {
        let h = Calendar.current.component(.hour, from: Date())
        return h >= 22 || h < 6
    }

    /// 추억 알림 토글 적용 — 켜면 권한 요청 후 실제 등록, 끄면 보류 중인 추억 알림을 모두 취소.
    private func applyMemoryNotif(_ on: Bool) {
        let scheduler = UNPendingScheduler()
        if on {
            let entries = store.diaryEntries
            let childName = store.selectedChild?.name ?? "우리 아이"
            Task {
                guard await scheduler.requestAuthorization() else { return }
                let reqs = NotificationScheduler.memoryReminders(
                    diaryEntries: entries, childName: childName, now: Date())
                scheduler.schedule(reqs)
            }
        } else {
            scheduler.cancelMemoryReminders()
        }
    }

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
        // 세로 패딩 추가 — 버튼·세그먼트가 든 행에서 카드가 콘텐츠에 딱 붙던 문제 해결(여백 확보).
        .padding(.vertical, Spacing.s3)
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
