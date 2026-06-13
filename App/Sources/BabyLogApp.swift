import SwiftUI
import UIKit

// MARK: - AppDelegate (원격 푸시 토큰 — 실시간 크루 오픈 알림)
final class AppDelegate: NSObject, UIApplicationDelegate {
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("bl_onboarded") private var onboarded = false

    /// 상실 이벤트 → 임신 알림 자동 차단 구독 (민감영역, 앱 생존 동안 유지)
    private let notifications = NotificationService(scheduler: UNNotificationScheduler())

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .tint(AppColors.primary)
                .preferredColorScheme(.light)   // 무조건 라이트(데이) 모드 고정
                .task {
                    store.enableAutoPersist()
                    store.refreshBadgeAwards()   // 첫 실행 시드 / 닫힌 새 획득 감지
                    notifications.start()
                    await flushPendingReports()  // 신고 증거 업로드 — 마켓 탭 재진입에 의존하지 않게
                    await setupNotifications()
                }
                // 백그라운드 전환 시 즉시 저장 — debounce(0.5s) 대기 중 강제종료로 마지막 기록이 유실되지 않게.
                // 포그라운드 복귀 시 미업로드 신고 재시도(증거 서버 보존).
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background || phase == .inactive {
                        store.persistNow()
                        // iCloud '자동 백업'이 켜져 있고 CloudKit이 빌드에 활성화된 경우에만
                        // 앱을 닫을 때 스냅샷을 자동 푸시(엔타이틀먼트 없으면 isAvailableInBuild=false → no-op).
                        if CloudSyncService.isAvailableInBuild && CloudSyncService.isEnabled {
                            let snapshot = store.snapshot()
                            Task { try? await CloudSyncService.shared.push(snapshot) }
                        }
                    }
                    else if phase == .active { Task { await flushPendingReports() } }
                }
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
        let memories = NotificationScheduler.memoryReminders(
            diaryEntries: store.diaryEntries,
            childName: store.selectedChild?.name ?? "우리 아이",
            now: Date()
        )
        if !memories.isEmpty { scheduler.schedule(memories) }
    }
}
