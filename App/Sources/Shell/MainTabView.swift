import SwiftUI

enum AppTab: Hashable { case home, record, dongne, budget, profile }
enum AppMode { case baby, pregnancy }

/// 5탭 하단 네비게이션 (기능 8) — iOS 26에서 TabView는 시스템 Liquid Glass 탭바로 렌더.
/// 우하단 빠른 기록 FAB는 홈·기록·동네 탭에서만 노출 (중앙 탭바 버튼 미채택).
struct MainTabView: View {
    @State private var tab: AppTab = .home
    @State private var mode: AppMode = .baby

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                HomeTab()
                    .tabItem { Label("홈", systemImage: "house.fill") }
                    .tag(AppTab.home)
                RecordScreen()
                    .tabItem { Label("기록", systemImage: "book.closed.fill") }
                    .tag(AppTab.record)
                DongneTab()
                    .tabItem { Label("동네", systemImage: "mappin.and.ellipse") }
                    .tag(AppTab.dongne)
                BudgetTab()
                    .tabItem { Label("가계부", systemImage: "wonsign.circle.fill") }
                    .tag(AppTab.budget)
                ProfileTab()
                    .tabItem { Label("내정보", systemImage: "person.crop.circle.fill") }
                    .tag(AppTab.profile)
            }
            .tint(AppColors.primary)

            if tab == .home || tab == .record || tab == .dongne {
                QuickRecordFAB(mode: mode)
                    .padding(.trailing, Spacing.s5)
                    .padding(.bottom, 92)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
