import SwiftUI

enum AppTab: Hashable { case home, record, dongne, budget, profile }
enum AppMode: String { case baby, pregnancy }

/// 5탭 하단 네비게이션 (기능 8) — iOS 26에서 TabView는 시스템 Liquid Glass 탭바로 렌더.
/// 온보딩 게이트 → 메인. 우하단 빠른 기록 FAB → 빠른기록 시트. 좌하단 모드 전환(임신/육아).
struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("bl_onboarded") private var onboarded = false
    @AppStorage("bl_fab_side") private var fabSide = "right"
    @AppStorage("bl_night_dim") private var nightDim = false
    @State private var tab: AppTab = .home
    @AppStorage("bl_app_mode") private var mode: AppMode = .baby   // 세션 간 유지(매번 baby로 리셋되던 문제)
    @AppStorage("bl_mode_initialized") private var modeInitialized = false
    @State private var showQuickRecord = false
    @State private var recordDetent: PresentationDetent = .large   // 기록 시트는 크게 열림(원하면 줄이기)
    @State private var showAddChild = false
    @State private var showAddPregnancy = false
    /// 멈춤/상실 임신만 있는 경우 — 새 임신 등록을 권하지 않고 부드러운 안내(민감영역)
    @State private var showPausedNotice = false
    @State private var showICloudBackupWarn = false   // 앱 진입 1회 — 데이터 있는데 iCloud 미로그인 안내
    @State private var showSplash = true
    // FAB 자유 위치(길게 눌러 드래그) — 기준 위치에서의 오프셋 영속
    @AppStorage("bl_fab_dx") private var fabDX: Double = 0
    @AppStorage("bl_fab_dy") private var fabDY: Double = 0
    /// 화면 밖에 저장된 좌표로 FAB가 사라지는 문제 1회 복구 플래그
    @AppStorage("bl_fab_pos_reset_1") private var fabPosResetDone = false
    @State private var fabDrag: CGSize = .zero
    @State private var fabDragging = false
    @State private var fabSuppressTap = false

    private var fabOnLeft: Bool { fabSide == "left" }

    /// FAB 길게 눌러(0.3s) 드래그로 위치 이동. 화면 밖으로 안 나가게 클램프 후 영속.
    private var fabMoveGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag) = value {
                    if !fabDragging { fabDragging = true; Haptics.light() }
                    if let drag {
                        fabDrag = drag.translation
                        if abs(drag.translation.width) > 6 || abs(drag.translation.height) > 6 {
                            fabSuppressTap = true   // 드래그 중엔 탭 무시 보장
                        }
                    }
                }
            }
            .onEnded { value in
                if case .second(true, let drag?) = value {
                    let b = UIScreen.main.bounds
                    let span = b.width - 100, maxUp = b.height - 240
                    let nx = fabDX + drag.translation.width
                    let ny = fabDY + drag.translation.height
                    fabDX = fabOnLeft ? min(span, max(0, nx)) : min(0, max(-span, nx))
                    fabDY = min(0, max(-maxUp, ny))
                    // 실제로 움직였으면 직후 탭(메뉴 열림) 무시
                    if abs(drag.translation.width) > 6 || abs(drag.translation.height) > 6 {
                        fabSuppressTap = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fabSuppressTap = false }
                    }
                }
                fabDrag = .zero
                fabDragging = false
                Haptics.success()
            }
    }

    var body: some View {
        Group {
            // 안내(온보딩)는 항상 먼저 — iCloud 백업으로 복원된 데이터가 있어도 건너뛰지 않는다.
            // 복원은 온보딩 완료 후 본화면 진입 시점에 수행(BabyLogApp의 onChange(onboarded)).
            if onboarded {
                mainUI
            } else {
                OnboardingView { withAnimation(.easeOut) { onboarded = true } }
            }
        }
        .overlay { nightDimOverlay }
        .overlay {
            if showSplash {
                SeedlingSplashView(onFinish: { showSplash = false })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        // 전역 뱃지 획득 카드 — 윈도우 레벨로 띄워 시트/상세 위에도 항상 보이게 한다.
        // (.overlay는 UIKit 시트 뒤로 가려지고 스크림도 잘렸음 → BadgeOverlayWindow로 이전)
        .onChange(of: store.pendingBadgeAward?.id) { _, _ in presentBadgeIfNeeded() }
        .onAppear { presentBadgeIfNeeded() }
        .task { await checkICloudBackupStatus() }   // 앱 진입 1회 — 미로그인 시 자동백업 경고
        .alert("iCloud 백업이 꺼져 있어요", isPresented: $showICloudBackupWarn) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("지금 iCloud에 로그인되어 있지 않아 소중한 기록이 자동 백업되지 않아요. 기기 ‘설정 > 사용자 이름 > iCloud’에서 로그인하면 안전하게 보관돼요.")
        }
        // 저장 실패 안내(정직 — 무음 실패 금지). 디스크 오류 시 사용자에게 즉시 알림.
        .alert("저장 실패", isPresented: Binding(
            get: { store.lastPersistError != nil },
            set: { if !$0 { store.lastPersistError = nil } }
        )) {
            Button("확인", role: .cancel) { store.lastPersistError = nil }
        } message: { Text(store.lastPersistError ?? "") }
        .alert("기록 불러오기", isPresented: Binding(
            get: { store.loadFailedNotice != nil },
            set: { if !$0 { store.loadFailedNotice = nil } }
        )) {
            Button("확인", role: .cancel) { store.loadFailedNotice = nil }
        } message: { Text(store.loadFailedNotice ?? "") }
    }

    /// pendingBadgeAward 변화에 맞춰 윈도우 카드를 띄우거나 내린다.
    /// 앱 진입 1회 안내 — 백업할 데이터가 있는데 iCloud 미로그인이면 자동백업이 조용히 실패하므로 부드럽게 알림.
    /// (.task는 실행당 1회 → 매 실행 1번만 뜨고 세션 중 반복 안 함. 미로그인이 계속되면 다음 실행에 다시 안내.)
    private func checkICloudBackupStatus() async {
        guard onboarded,
              CloudSyncService.isAvailableInBuild,
              CloudSyncService.isEnabled,
              !store.isEffectivelyEmpty else { return }
        try? await Task.sleep(nanoseconds: 2_000_000_000)   // 스플래시·온보딩 정리 후 표시
        guard !Task.isCancelled else { return }
        let available = await CloudSyncService.shared.accountAvailable()
        if !available { showICloudBackupWarn = true }
    }

    private func presentBadgeIfNeeded() {
        if let badge = store.pendingBadgeAward {
            BadgeOverlayWindow.show(badge) { store.pendingBadgeAward = nil }
        } else {
            BadgeOverlayWindow.hide()
        }
    }

    /// 빠른 기록 진입 — FAB·홈 권유카드 공용. 아이/임신 미등록이면 등록부터 안내.
    private func triggerQuickRecord() {
        Haptics.light()
        if mode == .baby && store.children.isEmpty {
            showAddChild = true
        } else if mode == .pregnancy && store.activePregnancy == nil {
            // 멈춤/상실 임신이 있고 활성 임신이 없으면 새 등록을 권하지 않는다(민감영역).
            if store.pregnancies.contains(where: { $0.status == .paused || $0.status == .loss }) {
                showPausedNotice = true
            } else {
                showAddPregnancy = true
            }
        } else {
            showQuickRecord = true
        }
    }

    /// 야간 초저휘도 — 설정 ON 시 22~06시에 은은한 디밍(새벽 수유 배려). 5분마다 시간 재평가.
    @ViewBuilder
    private var nightDimOverlay: some View {
        if nightDim {
            TimelineView(.periodic(from: .now, by: 300)) { ctx in
                let hour = Calendar.current.component(.hour, from: ctx.date)
                let isNight = hour >= 22 || hour < 6
                // 순검정 대신 따뜻한 다크 톤 — 새벽 수유 시 차갑지 않게(럭셔리 톤 유지).
                Color(hex: 0x282118)
                    .opacity(isNight ? 0.34 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.6), value: isNight)
            }
        }
    }

    private var mainUI: some View {
        ZStack(alignment: fabOnLeft ? .bottomLeading : .bottomTrailing) {
            TabView(selection: $tab) {
                Group {
                    if mode == .pregnancy { PregnancyHomeView(onNavigate: { tab = $0 }) } else { HomeTab(onNavigate: { tab = $0 }, onQuickRecord: { triggerQuickRecord() }) }
                }
                .tabItem { Label("홈", systemImage: "house") }
                .tag(AppTab.home)

                Group {
                    if mode == .pregnancy { PregnancyRecordScreen() } else { RecordScreen() }
                }
                    .tabItem { Label("기록", systemImage: "book") }
                    .tag(AppTab.record)
                DongneTab()
                    .tabItem { Label("동네", systemImage: "mappin.and.ellipse") }
                    .tag(AppTab.dongne)
                BudgetTab()
                    .tabItem { Label("가계부", systemImage: "wallet.bifold") }
                    .tag(AppTab.budget)
                ProfileTab()
                    .tabItem { Label("내정보", systemImage: "person.crop.circle") }
                    .tag(AppTab.profile)
            }
            // 핸드오프 네비 — 라인 스타일 + 세이지 활성색(검정 채움 → 따뜻한 세이지)
            .tint(Color(hex: 0x4E8268))

            // 빠른 기록 FAB (홈·기록) — 동네 탭은 팔기/모임 만들기 버튼이 있어 제외
            if tab == .home || tab == .record {
                QuickRecordFAB(mode: mode, suppressTap: fabSuppressTap,
                               onToggleMode: { withAnimation(.easeOut(duration: 0.25)) { mode = (mode == .baby ? .pregnancy : .baby) } },
                               onQuickRecord: {
                    Haptics.light()
                    // 아이/임신 미등록이면 빠른기록 대신 등록부터
                    if mode == .baby && store.children.isEmpty {
                        showAddChild = true
                    } else if mode == .pregnancy && store.activePregnancy == nil {
                        // 멈춤/상실 임신이 있고 활성 임신이 없으면 새 등록을 권하지 않는다(민감영역).
                        if store.pregnancies.contains(where: { $0.status == .paused || $0.status == .loss }) {
                            showPausedNotice = true
                        } else {
                            showAddPregnancy = true
                        }
                    } else {
                        showQuickRecord = true
                    }
                })
                    .padding(fabOnLeft ? .leading : .trailing, Spacing.s5)
                    .padding(.bottom, 92)
                    .offset(x: fabDX + fabDrag.width, y: fabDY + fabDrag.height)
                    .scaleEffect(fabDragging ? 1.12 : 1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fabDragging)
                    .simultaneousGesture(fabMoveGesture)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // 모드 전환 칩은 각 홈(육아/임신) 상단 타이틀 아래 ModeToggleChip으로 이동.
        .sheet(isPresented: $showAddChild) {
            AddChildSheet().environmentObject(store).nightDimmable()
        }
        .sheet(isPresented: $showAddPregnancy) {
            AddPregnancySheet().environmentObject(store).nightDimmable()
        }
        .alert("기록이 잠시 멈춰 있어요", isPresented: $showPausedNotice) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("기록 탭에서 언제든 다시 시작할 수 있어요.")
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet(mode: mode, onSave: {}, onClose: { showQuickRecord = false })
                .presentationDetents([.medium, .large], selection: $recordDetent)
                .presentationDragIndicator(.visible)
                .nightDimmable()
        }
        .onChange(of: showQuickRecord) { _, shown in if shown { recordDetent = .large } }
        // 빈 타임라인 등에서 '빠른 기록' 요청 신호 → mode에 맞춰 처리
        .onChange(of: store.requestQuickRecord) { _, req in
            if req { store.requestQuickRecord = false; triggerQuickRecord() }
        }
        .onAppear {
            // 최초 1회 모드 기본값: 활성 임신 있고 아이 없으면 임신 모드로(이후엔 사용자 선택 유지)
            if !modeInitialized {
                if store.activePregnancy != nil && store.children.isEmpty { mode = .pregnancy }
                modeInitialized = true
            }
            // 1회 복구: 화면 밖 좌표로 FAB가 안 보이던 문제 → 기본 위치로
            if !fabPosResetDone { fabDX = 0; fabDY = 0; fabPosResetDone = true }
            // 매 로드 안전 보정: 저장 좌표를 항상 화면 안으로 클램프
            let b = UIScreen.main.bounds
            let span = b.width - 100, maxUp = b.height - 240
            fabDX = fabOnLeft ? min(span, max(0, fabDX)) : min(0, max(-span, fabDX))
            fabDY = min(0, max(-maxUp, fabDY))
        }
        // FAB 좌우 변경 시: X 오프셋 부호 규약이 반대편과 달라 저장값이 화면 밖이 됨.
        // 기준 위치(0)로 리셋해 재실행 전까지 사라지는 문제 방지. Y는 화면 안으로 재클램프.
        .onChange(of: fabSide) { _, _ in
            fabDX = 0
            let b = UIScreen.main.bounds
            let maxUp = b.height - 240
            fabDY = min(0, max(-maxUp, fabDY))
        }
    }

}

// (ModeToggleChip 제거 — 육아/임신 전환은 빠른기록 FAB 메뉴로 이동)

// MARK: - 야간 디밍 (시트용)
// SwiftUI .sheet은 별도 레이어로 떠서 루트의 nightDimOverlay를 벗어난다.
// → 새벽 수유 시 빠른기록·아이등록 시트가 풀밝기로 번쩍이지 않게 시트 콘텐츠에 직접 적용.
private struct NightDimmable: ViewModifier {
    @AppStorage("bl_night_dim") private var nightDim = false
    func body(content: Content) -> some View {
        content.overlay {
            if nightDim {
                TimelineView(.periodic(from: .now, by: 300)) { ctx in
                    let h = Calendar.current.component(.hour, from: ctx.date)
                    Color(hex: 0x282118)
                        .opacity((h >= 22 || h < 6) ? 0.34 : 0)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
extension View {
    /// 야간(22–06시) 저휘도 모드일 때 시트 콘텐츠를 따뜻하게 디밍.
    func nightDimmable() -> some View { modifier(NightDimmable()) }
}
