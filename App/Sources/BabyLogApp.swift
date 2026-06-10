import SwiftUI

@main
struct BabyLogApp: App {
    @StateObject private var store = AppStore(persistence: LocalPersistence())

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(store)
                .tint(AppColors.primary)
                .task {
                    store.enableAutoPersist()
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
