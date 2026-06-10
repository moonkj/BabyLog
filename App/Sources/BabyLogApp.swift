import SwiftUI

@main
struct BabyLogApp: App {
    @StateObject private var store = AppStore(persistence: .appGroup())

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
                    notifications.start()
                    await setupNotifications()
                }
        }
    }

    /// 앱 런치 시 알림 권한 요청 + 예방접종 리마인더(D-7/D-1/당일) 등록.
    private func setupNotifications() async {
        let scheduler = UNPendingScheduler()
        guard await scheduler.requestAuthorization() else { return }
        let cal = Calendar.current
        guard let soon = cal.date(byAdding: .day, value: 7, to: Date()) else { return }
        let vax = VaccineRecord(id: UUID(), childId: UUID(), vaccineId: "DTaP 4차",
                                scheduledDate: soon, completedDate: nil, hospital: "행복소아과")
        scheduler.schedule(NotificationScheduler.vaccineReminders([vax], now: Date()))
    }
}
