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
    @AppStorage("bl_cloud_sync")       private var cloudSync: Bool         = true   // 기본 ON(데이터 안전 우선)
    @AppStorage("bl_memory_notif")     private var memoryNotif: Bool       = true
    @ObservedObject private var auth = AuthStore.shared
    @State private var showDeleteAccount = false
    @State private var authAlert: String? = nil
    @State private var cloudStatus: String? = nil
    @State private var cloudBusy = false
    @State private var showCloudRestoreConfirm = false
    @State private var cloudBackupAt: Date? = nil   // 복원 확인창에 보여줄 '최신 백업' 시각
    @State private var pendingUploads: Int = 0      // iCloud에 아직 안 올라간 사진 수(미백업 안내)
    @State private var iCloudSignedIn: Bool? = nil  // iCloud 로그인 여부(미로그인 시 자동백업 경고)
    @State private var cloudLastBackupAt: Date? = CloudSyncService.lastBackupAt()   // iCloud 마지막 백업 성공 시각(표시)

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
    // 사진 앱 자동 저장(본인 iCloud 사진으로 보존)
    @State private var photoLibBackupOn = PhotoLibraryBackup.isEnabled
    // 운영자 모드 — 내 계정 로그인 상태에서 버전 10회 탭 → 신고 목록(PIN 제거).
    // 실제 권한은 서버(admin Edge)가 JWT uid 화이트리스트(ADMIN_UIDS)로 강제.
    @State private var versionTaps = 0
    @State private var showAdmin = false
    @State private var showAdminLoginHint = false   // 비로그인 상태에서 진입 시도 안내

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 앱 공용 헤더(28pt) — 다른 탭과 통일
                BLScreenHeader(title: "설정", eyebrow: "환경설정")

                VStack(spacing: Spacing.s5) {
                    accountSection      // 로그인 — 최상단
                    caregiverSection    // 프로필 이름·호칭 — 최상단
                    familyShareSection  // 조부모/가족 사진 공유 (아이폰·안드로이드 모두)
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
        .onAppear {
            pendingUploads = CloudSyncService.pendingUploadCount()
            // iCloud 로그인 상태 확인 — 미로그인이면 자동백업이 조용히 실패하므로 사용자에게 경고.
            if CloudSyncService.isAvailableInBuild {
                Task { iCloudSignedIn = await CloudSyncService.shared.accountAvailable() }
            }
        }
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
                      allowedContentTypes: [UTType(filenameExtension: BackupService.fileExtension) ?? .data, .data, .item]) { result in
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
        .alert("계정을 삭제할까요?", isPresented: $showDeleteAccount) {
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
        .alert("iCloud 백업으로 덮어쓸까요?", isPresented: $showCloudRestoreConfirm) {
            Button("iCloud에서 복원", role: .destructive) { Task { await runCloud(.restore) } }
            Button("취소", role: .cancel) {}
        } message: {
            Text(cloudRestoreMessage)
        }
    }

    // MARK: - 계정 섹션 (Apple 로그인 — Supabase 연동 시에만 노출)

    @ViewBuilder
    private var accountSection: some View {
        if SupabaseConfig.isConfigured {
            settingsSection(eyebrow: "가족 피드·크루 계정", title: "로그인") {
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
                        Text("가족 피드·크루에서 쓰는 로그인이에요. 로그인하면 기기를 바꿔도 내 글·모임이 유지되고, 본인 글만 수정·삭제할 수 있어요. 크루는 로그인 없이도 익명으로 참여할 수 있어요.")
                            .font(.system(size: 12.5)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("※ iCloud 백업과는 별개예요 — 백업은 기기 iCloud(Apple ID)로 자동돼요.")
                            .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppColors.ink2)
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

    // MARK: - 가족 공유 섹션

    private var familyShareSection: some View {
        settingsSection(eyebrow: "가족", title: "가족과 사진 공유") {
            NavigationLink {
                FamilyFeedScreen()
            } label: {
                settingsRow(icon: "heart.text.square.fill",
                            iconBg: AppColors.primarySoft, iconFg: AppColors.primary,
                            showChevron: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("가족과 사진 공유")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("가족이 함께 보고 하트·댓글 — 부부는 무료, 조부모·친척은 Pro (아이폰·안드로이드 모두)")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .buttonStyle(.plain)
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
                            // 이름 바꾸면 가족 보관함에 보이는 내 이름도 함께 갱신(서버 사본 동기화)
                            .onSubmit { Task { await FamilyFeedBackend.updateMyDisplayName(nickname) } }
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
                        Text("※ 기기 iCloud(Apple ID)를 사용해요 — 위 ‘가족 피드·크루 로그인’과 별개예요.")
                            .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppColors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        // 미로그인 경고 — 자동백업이 조용히 실패하는 상황을 명확히 알림(데이터 유실 방지).
                        if cloudSync, iCloudSignedIn == false {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12, weight: .bold))
                                Text("iCloud에 로그인되어 있지 않아 자동 백업이 안 돼요. 기기 ‘설정 > 사용자 이름 > iCloud’에서 로그인해 주세요.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(AppColors.danger)
                            .padding(.top, 2)
                        }
                    }
                }
                Divider().overlay(AppColors.line).padding(.leading, 62)
                Button { Task { await runCloud(.backup) } } label: {
                    settingsRow(icon: "arrow.up.circle.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cloudBusy ? "처리 중…" : "지금 백업").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                            Text(cloudLastBackupText).font(AppFont.caption).foregroundStyle(AppColors.ink3)
                        }
                    }
                }.buttonStyle(.plain).disabled(cloudBusy).opacity(cloudBusy ? 0.5 : 1)
                Divider().overlay(AppColors.line).padding(.leading, 62)
                Button {
                    // 확인창을 띄우기 전에 '최신 백업' 시각을 먼저 조회해 사용자가 무엇을 되살리는지 보여준다.
                    Task { cloudBackupAt = await CloudSyncService.shared.backupDate(); showCloudRestoreConfirm = true }
                } label: {
                    settingsRow(icon: "arrow.down.circle.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                        Text("iCloud에서 복원").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                    }
                }.buttonStyle(.plain).disabled(cloudBusy).opacity(cloudBusy ? 0.5 : 1)
                if cloudSync && pendingUploads > 0 {
                    Text("⚠️ iCloud에 아직 안 올라간 사진 \(pendingUploads)장 — ‘지금 백업’을 눌러 올려두세요.")
                        .font(AppFont.caption).foregroundStyle(AppColors.gold)
                        .padding(.horizontal, Spacing.s4).padding(.bottom, Spacing.s2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let s = cloudStatus {
                    Text(s).font(AppFont.caption).foregroundStyle(AppColors.ink3)
                        .padding(.horizontal, Spacing.s4).padding(.bottom, Spacing.s2)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// 복원 확인창 문구 — '가장 최근 백업'임을 명시하고, 가능하면 그 백업 시각을 보여준다.
    /// '지금 백업' 아래 표시 — 이 기기에서 마지막으로 iCloud 백업 성공한 시각.
    private var cloudLastBackupText: String {
        guard let d = cloudLastBackupAt else { return "아직 백업한 적 없어요" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "yyyy.M.d a h:mm"
        return "마지막 백업: \(f.string(from: d))"
    }

    private var cloudRestoreMessage: String {
        if let d = cloudBackupAt {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ko_KR")
            f.dateFormat = "yyyy.MM.dd HH:mm"
            return "가장 최근 iCloud 백업(\(f.string(from: d)))으로 이 기기의 현재 기록을 덮어씁니다. 이 백업 이후에 추가한 기록은 사라질 수 있어요."
        }
        return "가장 최근 iCloud 백업으로 이 기기의 현재 기록을 덮어씁니다. 이 백업 이후에 추가한 기록은 사라질 수 있어요."
    }

    private enum CloudOp { case backup, restore }
    private func runCloud(_ op: CloudOp) async {
        cloudBusy = true; cloudStatus = nil
        // 포그라운드 백업/복원이 도중에 앱을 벗어나도 끊기지 않게 백그라운드 실행시간 확보(시간제한 완화).
        let app = UIApplication.shared
        var bgId: UIBackgroundTaskIdentifier = .invalid
        bgId = app.beginBackgroundTask(withName: "bl-icloud-manual") {
            if bgId != .invalid { app.endBackgroundTask(bgId); bgId = .invalid }
        }
        defer {
            cloudBusy = false
            pendingUploads = CloudSyncService.pendingUploadCount()   // 미백업 수 갱신
            cloudLastBackupAt = CloudSyncService.lastBackupAt()      // iCloud 마지막 백업 시각 갱신
            if bgId != .invalid { app.endBackgroundTask(bgId); bgId = .invalid }
        }
        do {
            switch op {
            case .backup:
                // 빈 상태는 백업 안 함 — 클라우드의 기존 백업을 빈 데이터로 덮어쓰는 사고 방지.
                guard !store.isEffectivelyEmpty else {
                    cloudStatus = "백업할 기록이 없어요. (빈 상태로 덮어쓰지 않아요)"
                    Haptics.warning()
                    return
                }
                try await CloudSyncService.shared.push(store.snapshot())
                let up = await CloudSyncService.shared.pushPhotos()       // 사진도 함께 백업
                if let e = up.error {
                    cloudStatus = up.uploaded > 0
                        ? "사진 \(up.uploaded)장 백업했어요. 일부는 못 올렸어요 — \(e.prefix(120))"
                        : e   // 친절 메시지(저장공간 부족 등)
                } else {
                    cloudStatus = up.uploaded > 0 ? "백업 완료 · 사진 \(up.uploaded)장" : "백업 완료"
                }
            case .restore:
                if let remote = try await CloudSyncService.shared.pull() {
                    // 백업이 비어 있으면(아이·기록 0) 정직하게 안내 — '복원 완료'로 오인 방지.
                    if remote.children.isEmpty && remote.diaryEntries.isEmpty
                        && remote.pregnancies.isEmpty && remote.growthRecords.isEmpty {
                        cloudStatus = "iCloud 백업이 비어 있어요. 복원할 기록이 없습니다."
                    } else {
                        let r = await CloudSyncService.shared.pullPhotos(refs: remote.allPhotoRefs)  // 사진 먼저 내려받고 상태 적용
                        store.restore(remote)
                        let kids = remote.children.count, recs = remote.diaryEntries.count
                        if let e = r.error {
                            cloudStatus = "복원 · 아이 \(kids), 기록 \(recs), 사진 \(r.copied)/\(r.requested) — \(e.prefix(100))"
                        } else {
                            cloudStatus = "복원 완료 · 아이 \(kids), 기록 \(recs), 사진 \(r.copied)장"
                        }
                    }
                } else {
                    cloudStatus = "iCloud에 백업이 없어요."
                }
            }
            Haptics.success()
        } catch {
            // CloudKit 사유별 친절 안내(저장공간 부족·로그인·네트워크 등).
            cloudStatus = CloudSyncService.message(for: error)
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
                    Text("⚠️ 앱을 삭제하면 이 기기의 데이터가 모두 사라져요. ‘iCloud 자동 백업’을 켜두거나, 전체 백업 파일을 iCloud Drive에 저장해 두세요.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Divider().overlay(AppColors.line).padding(.leading, 62)

            // 사진 앱 자동 저장 — 등록 사진을 iOS '사진' 앱('베이비로그' 앨범)에 자동 저장.
            // 본인 iCloud 사진으로 보존돼 앱을 삭제해도 사진이 남는다(우리 서버 X).
            settingsRow(icon: "photo.on.rectangle.angled", iconBg: AppColors.primarySoft, iconFg: AppColors.primary) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("사진 앱에 자동 저장")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("등록 사진을 ‘사진’ 앱 ‘베이비로그’ 앨범에 자동 저장 — 앱을 지워도 사진이 남아요")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Toggle("", isOn: $photoLibBackupOn).labelsHidden()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("사진 앱에 자동 저장")
            .onChange(of: photoLibBackupOn) { _, on in togglePhotoLibBackup(on) }

            Divider().overlay(AppColors.line).padding(.leading, 62)

            // 전체 백업 내보내기
            Button { handleBackupExport() } label: {
                settingsRow(icon: "arrow.up.doc.fill", iconBg: AppColors.primarySoft, iconFg: AppColors.primary, showChevron: true) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(backupBusy ? "준비 중…" : "전체 백업 내보내기")
                            .font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("사진·영상·기록을 파일 하나로. ⚠️ 꼭 iCloud Drive 등 앱 바깥에 저장하세요 — 앱을 지우면 앱 안에 둔 파일은 함께 사라져요.")
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
                        Text("앱 바깥(iCloud Drive 등)에 저장해 둔 백업 파일로 사진·기록을 되살려요")
                            .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.buttonStyle(.plain).disabled(backupBusy).opacity(backupBusy ? 0.5 : 1)
        }
    }

    /// 사진 앱 자동 저장 토글 — 켤 때 권한 요청 후 즉시 기존 사진을 일괄 저장. 거부 시 되돌림.
    private func togglePhotoLibBackup(_ on: Bool) {
        if on {
            Task { @MainActor in
                guard await PhotoLibraryBackup.requestAuthorization() else {
                    photoLibBackupOn = false
                    backupAlert = "‘사진’ 앱 추가 권한이 꺼져 있어요. 설정 > 베이비로그 > 사진에서 ‘추가만’을 허용해 주세요."
                    return
                }
                PhotoLibraryBackup.isEnabled = true
                let n = await PhotoLibraryBackup.sync(refs: store.memoryPhotoRefs())
                backupAlert = "사진 앱 자동 저장을 켰어요. 기존 사진 \(n)장을 ‘베이비로그’ 앨범에 저장했어요."
            }
        } else {
            PhotoLibraryBackup.isEnabled = false
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
            .contentShape(Rectangle())
            .onTapGesture {
                versionTaps += 1
                if versionTaps >= 10 {
                    versionTaps = 0
                    // 운영자 계정(ADMIN_UIDS)으로 로그인한 경우에만 진입 — 일반 로그인 사용자에게
                    // 운영자 UI(개발 탭·모드 토글) 자체를 노출하지 않는다. 데이터 권한은 서버가 최종 강제.
                    if AdminGate.isAdmin { showAdmin = true } else { showAdminLoginHint = true }
                }
            }
            .alert("운영자 모드", isPresented: $showAdminLoginHint) {
                Button("확인", role: .cancel) {}
            } message: { Text("운영자 모드는 등록된 운영자 계정으로 로그인한 경우에만 사용할 수 있어요.") }
            .sheet(isPresented: $showAdmin) { AdminReportsScreen().environmentObject(store) }

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
            let names = Dictionary(store.children.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            Task {
                guard await scheduler.requestAuthorization() else { return }
                let reqs = NotificationScheduler.memoryReminders(
                    diaryEntries: entries, childNames: names, now: Date())
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
            // 오른쪽 '>' 셰브론 제거 — 사용자가 그 부분을 눌러야 실행되는 줄 오인. (showChevron 무시)
        }
        .padding(.horizontal, Spacing.s4)
        // 세로 패딩 추가 — 버튼·세그먼트가 든 행에서 카드가 콘텐츠에 딱 붙던 문제 해결(여백 확보).
        .padding(.vertical, Spacing.s3)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        // 행 전체(빈 여백 포함)를 탭 영역으로 — 텍스트만 눌러야 하던 좁은 터치영역 문제 해결.
        .contentShape(Rectangle())
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
