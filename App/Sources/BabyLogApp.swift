import SwiftUI
import UIKit
import BackgroundTasks

// MARK: - AppDelegate (원격 푸시 토큰 — 실시간 크루 오픈 알림)
final class AppDelegate: NSObject, UIApplicationDelegate {
    static let backupTaskID = "com.vibelab.babylog.icloudbackup"

    // 앱 닫을 때 못 올린 사진을 OS가 충전/유휴 시 마저 올리도록 등록(catch-up).
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backupTaskID, using: nil) { task in
            Self.handleBackupCatchup(task as! BGProcessingTask)
        }
        return true
    }

    /// 백그라운드 사진 업로드 catch-up 예약 — iCloud 자동백업이 켜진 경우만.
    static func scheduleBackupCatchup() {
        guard CloudSyncService.isAvailableInBuild, CloudSyncService.isEnabled else { return }
        let req = BGProcessingTaskRequest(identifier: backupTaskID)
        req.requiresNetworkConnectivity = true
        req.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(req)
    }

    /// OS가 시간을 줄 때 남은 사진을 증분 업로드(앱이 닫혀 있어도 동작). 시간 초과 시 다음 기회에 이어서.
    static func handleBackupCatchup(_ task: BGProcessingTask) {
        scheduleBackupCatchup()   // 연쇄 예약(다음에도 catch-up 가능하게)
        let work = Task {
            await CloudSyncService.shared.pushPhotos()   // 증분 — uploadedKey에 없는 것만
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: "bl_apns_token")   // 동네 잡히면 hood 갱신용 보관
        Task { await CrewBackend.uploadPushToken(hex, hood: NearbyLocationProvider.shared.localityName) }
    }
    func application(_ app: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 푸시 미설정(개발 중 등) — 앱 흐름 영향 없음
    }
}

@main
struct BabyLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AppStore(persistence: .appGroup())
    @ObservedObject private var auth = AuthStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("bl_onboarded") private var onboarded = false

    /// 상실 이벤트 → 임신 알림 자동 차단 구독 (민감영역, 앱 생존 동안 유지)
    private let notifications = NotificationService(scheduler: UNNotificationScheduler())

    init() {
        // 콜드 런치 시 홈은 항상 히어로 화면으로 시작(세션 중 레이아웃 전환은 그대로 동작).
        UserDefaults.standard.set(HomeLayout.hero.rawValue, forKey: "home_layout")
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .tint(AppColors.primary)
                .preferredColorScheme(.light)   // 무조건 라이트(데이) 모드 고정
                // 접근성: 스케일 폰트(AppFont)가 사용자 글씨 설정에 반응하되, 아직 고정 pt가 남은
                // 화면이 깨지지 않도록 상한을 둔다(점진 마이그레이션 중 안전장치). 추후 상향 가능.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .task {
                    store.enableAutoPersist()
                    KeyboardDismissTap.shared.install()   // 전역: 화면 탭 시 키보드 내림(검색·입력 공통)
                    // StoreKit 구독 — 엔타이틀먼트를 클라 게이트(isPro)에 브리지하고 서버 등급도 동기화.
                    StoreManager.shared.onEntitlementChange = { active in store.setSubscriptionActive(active) }
                    StoreManager.shared.start()
                    store.refreshBadgeAwards()   // 첫 실행 시드 / 닫힌 새 획득 감지
                    // 자동 복원은 '온보딩을 이미 마친' 경우에만 launch에서 수행.
                    // 재설치(온보딩 미완)면 안내 화면을 먼저 보여주고, 온보딩 완료 시점에 복원한다(아래 onChange).
                    if onboarded { await maybeAutoRestoreFromCloud() }
                    notifications.start()
                    await flushPendingReports()  // 신고 증거 업로드 — 마켓 탭 재진입에 의존하지 않게
                    await AnalyticsBackend.ping()  // 익명 접속 통계(하루 1회, 관리자 대시보드용)
                    await setupNotifications()
                    await syncPhotoLibrary()     // 사진 앱 자동 저장(켜둔 경우) — 새 사진 보존
                }
                // 온보딩을 마치고 본화면에 진입하는 순간 iCloud 백업을 복원(안내화면을 먼저 보여준 뒤).
                // (등록을 건너뛴 경우에만 복원 — 온보딩에서 새로 등록했으면 isEffectivelyEmpty=false라 보존.)
                .onChange(of: onboarded) { _, done in
                    if done { Task { await maybeAutoRestoreFromCloud() } }
                }
                // 백그라운드 전환 시 즉시 저장 — debounce(0.5s) 대기 중 강제종료로 마지막 기록이 유실되지 않게.
                // 포그라운드 복귀 시 미업로드 신고 재시도(증거 서버 보존).
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        store.persistNow()
                        // 마지막 사용(앱 이탈) 시각 기록 — 다음 실행 시 '오래 미접속' 자동 감지에 쓴다.
                        // (민감영역: 오래 떠나 있던 사용자에게 권유/추억 알림을 자동 완화하기 위함.)
                        UserDefaults.standard.set(Date(), forKey: "bl_last_active_at")
                        // iCloud '자동 백업'이 켜져 있고 CloudKit이 빌드에 활성화된 경우에만
                        // 앱을 닫을 때 스냅샷을 자동 푸시(엔타이틀먼트 없으면 isAvailableInBuild=false → no-op).
                        // ⚠️ 빈 상태는 절대 푸시하지 않는다 — 재설치 직후 복원 전 빈 데이터가 클라우드의
                        //    좋은 백업을 덮어쓰는 치명적 데이터 손실 방지(isEffectivelyEmpty 가드).
                        if CloudSyncService.isAvailableInBuild && CloudSyncService.isEnabled && !store.isEffectivelyEmpty {
                            let snapshot = store.snapshot()
                            Task { await backupToCloudInBackground(snapshot) }
                            // 닫는 30초 안에 못 올린 사진은 OS가 충전/유휴 시 마저 올리도록 예약(catch-up).
                            AppDelegate.scheduleBackupCatchup()
                        }
                        Task { await syncPhotoLibrary() }   // 닫을 때 새 사진을 사진 앱에 저장
                    }
                    else if phase == .active {
                        Task { await flushPendingReports() }
                        Task { await StoreManager.shared.syncNow() }   // 외부 구독 변경 반영(+서버 동기화)
                    }
                }
                // 로그아웃 시 운영자 로컬 Pro 강제(devProOverride)를 해제 — 다른 계정/로그아웃 후
                // 캐시된 Pro UI가 남지 않게(서버는 어차피 실제 구독으로만 등급 부여).
                .onChange(of: auth.isLoggedIn) { _, loggedIn in
                    if !loggedIn { store.devProOverride = false }
                }
        }
    }

    /// 사진 앱 자동 저장 — 켜져 있으면 영구 보존 대상 사진을 사진 앱 앨범에 동기화(이미 저장된 건 건너뜀).
    private func syncPhotoLibrary() async {
        guard PhotoLibraryBackup.isEnabled else { return }
        await PhotoLibraryBackup.sync(refs: store.memoryPhotoRefs())
    }

    /// 앱이 백그라운드로 갈 때 iCloud 백업(기록+사진)을 끝까지 올리도록 실행시간을 확보한다.
    /// 확보하지 않으면 iOS가 곧 앱을 정지시켜 용량 큰 사진 업로드가 잘려 CloudKit에 안 들어간다
    /// (기록 JSON은 작아 먼저 올라가고 사진만 누락되던 원인). 증분 업로드라 다음 백업에서 이어서 올린다.
    @MainActor
    private func backupToCloudInBackground(_ snapshot: PersistableState) async {
        let app = UIApplication.shared
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = app.beginBackgroundTask(withName: "bl-icloud-backup") {
            if taskId != .invalid { app.endBackgroundTask(taskId); taskId = .invalid }
        }
        try? await CloudSyncService.shared.push(snapshot)
        await CloudSyncService.shared.pushPhotos()
        if taskId != .invalid { app.endBackgroundTask(taskId); taskId = .invalid }
    }

    /// 재설치 직후 iCloud(CloudKit) 백업 자동 복원 — 로컬이 비어 있을 때만(기존 데이터 보호).
    /// CloudKit 미활성 빌드(isAvailableInBuild=false)에서는 no-op.
    /// ⚠️ isEnabled(자동백업 토글)로 게이트하지 않는다 — 앱을 지우면 UserDefaults가 초기화돼 토글이
    ///    꺼짐으로 리셋되는데, 재설치 복구가 바로 이 함수의 목적이므로 그 토글에 막히면 안 된다.
    ///    (백업이 없으면 pull이 nil → no-op이라 안전. 푸시/자동백업은 여전히 토글로 게이트.)
    private func maybeAutoRestoreFromCloud() async {
        guard CloudSyncService.isAvailableInBuild else { return }
        // 같은 런치에서 .task와 onChange(onboarded)가 겹쳐 호출돼도 중복 복원 방지(동기 구간서 가드 설정).
        guard !CloudSyncService.autoRestoreInFlight else { return }
        CloudSyncService.autoRestoreInFlight = true
        defer { CloudSyncService.autoRestoreInFlight = false }
        // 전체 사용자 데이터가 비었을 때만 복원(가계부·성장만 입력한 로컬을 덮어쓰지 않게).
        guard store.isEffectivelyEmpty else { return }
        guard await CloudSyncService.shared.accountAvailable() else { return }
        if let state = try? await CloudSyncService.shared.pull() {
            await CloudSyncService.shared.pullPhotos(refs: state.allPhotoRefs)
            // pull은 네트워크라 수백 ms~수 초 걸린다. 그 사이 사용자가 첫 기록을 입력했으면
            // 복원이 그 입력을 덮어쓰므로, restore 직전에 '여전히 비어있는지' 다시 확인한다.
            guard store.isEffectivelyEmpty else { return }
            store.restore(state)
        }
    }

    /// 미업로드 거래 신고(증거)를 서버에 재전송 — 앱 시작/포그라운드 복귀 시점.
    /// (이전엔 마켓 탭 진입 시에만 재시도돼 증거가 사용자 동선에 의존했음.)
    private func flushPendingReports() async {
        guard SupabaseConfig.isConfigured else { return }
        for r in store.pendingReports {
            if await MarketBackend.uploadReport(r) { store.markReportUploaded(r.id) }
        }
    }

    /// 앱 런치 시 알림 권한 요청 + 예방접종 리마인더(D-7/D-1/당일) 등록.
    private func setupNotifications() async {
        let scheduler = UNPendingScheduler()
        // 원격 푸시 토큰은 알림 권한과 무관하게 등록(토큰 확보가 목적). Push 역량 없으면 didFail로 무시.
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        // 온보딩 전엔 시스템 권한 프롬프트를 띄우지 않는다 — 온보딩 4단계(사전 안내 카드)가 먼저.
        guard onboarded else { return }
        guard await scheduler.requestAuthorization() else { return }
        // (제거됨) 무작위 UUID에 걸던 더미 'DTaP 4차' 백신 알림 — 실제 아이와 무관한 가짜 알림이라 삭제.
        // 실제 접종 알림은 추후 아이의 KDCA 스케줄 기반으로 스케줄링한다.

        // "N년 전 오늘" 추억 사진 알림 (월 1회, 실 다이어리 기반)
        // 설정의 '추억 알림' 토글(bl_memory_notif, 기본 ON)이 꺼져 있으면 등록하지 않는다.
        let memoryNotifOn = (UserDefaults.standard.object(forKey: "bl_memory_notif") as? Bool) ?? true
        guard memoryNotifOn else { return }
        // 민감영역(미사용 자동 완화): 오래 미접속한 사용자에겐 추억/권유 알림을 자동으로 줄인다.
        // 사용자가 직접 설정하는 부담을 주지 않기 위함 — 상실 등을 겪고 앱을 떠난 경우의 안전장치.
        let cap = softenedMemoryCap()
        guard cap > 0 else { return }   // 장기 미접속(예: 90일+) → 권유 알림을 보내지 않는다.
        let names = Dictionary(store.children.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let memories = NotificationScheduler.memoryReminders(
            diaryEntries: store.diaryEntries,
            childNames: names,
            now: Date(),
            maxCount: cap
        )
        if !memories.isEmpty { scheduler.schedule(memories) }
    }

    /// 마지막 사용 이후 경과일에 따른 추억 알림 상한(자동 완화).
    ///  ~30일: 12(기본) · 31~90일: 4(절제) · 90일 초과: 0(권유 중단).
    private func softenedMemoryCap() -> Int {
        guard let last = UserDefaults.standard.object(forKey: "bl_last_active_at") as? Date else { return 12 }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        switch days {
        case ..<31:  return 12
        case 31...90: return 4
        default:     return 0
        }
    }
}
