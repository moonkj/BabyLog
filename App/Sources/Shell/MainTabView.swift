import SwiftUI

enum AppTab: Hashable { case home, record, dongne, budget, profile }
enum AppMode { case baby, pregnancy }

/// 5탭 하단 네비게이션 (기능 8) — iOS 26에서 TabView는 시스템 Liquid Glass 탭바로 렌더.
/// 온보딩 게이트 → 메인. 우하단 빠른 기록 FAB → 빠른기록 시트. 좌하단 모드 전환(임신/육아).
struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("bl_onboarded") private var onboarded = false
    @AppStorage("bl_fab_side") private var fabSide = "right"
    @State private var tab: AppTab = .home
    @State private var mode: AppMode = .baby
    @State private var showQuickRecord = false

    private var fabOnLeft: Bool { fabSide == "left" }

    var body: some View {
        Group {
            if onboarded || store.hasContent {
                mainUI
            } else {
                OnboardingView { withAnimation(.easeOut) { onboarded = true } }
            }
        }
    }

    private var mainUI: some View {
        ZStack(alignment: fabOnLeft ? .bottomLeading : .bottomTrailing) {
            TabView(selection: $tab) {
                Group {
                    if mode == .pregnancy { PregnancyHomeView() } else { HomeTab(onNavigate: { tab = $0 }) }
                }
                .tabItem { Label("홈", systemImage: "house.fill") }
                .tag(AppTab.home)

                Group {
                    if mode == .pregnancy { PregnancyRecordScreen() } else { RecordScreen() }
                }
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

            // 빠른 기록 FAB (홈·기록·동네) — 위치는 설정(bl_fab_side, 한손 조작)
            if tab == .home || tab == .record || tab == .dongne {
                QuickRecordFAB(mode: mode, onQuickRecord: { Haptics.light(); showQuickRecord = true })
                    .padding(fabOnLeft ? .leading : .trailing, Spacing.s5)
                    .padding(.bottom, 92)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        // 모드 전환 칩 (홈에서만, FAB 반대편) — iOS26 Liquid Glass
        .overlay(alignment: fabOnLeft ? .bottomTrailing : .bottomLeading) {
            if tab == .home {
                modeToggle
                    .padding(fabOnLeft ? .trailing : .leading, Spacing.s5)
                    .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet(mode: mode, onSave: {}, onClose: { showQuickRecord = false })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var modeToggle: some View {
        Button {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.25)) { mode = (mode == .baby ? .pregnancy : .baby) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode == .baby ? "figure.and.child.holdinghands" : "figure.2.and.child.holdinghands")
                    .font(.system(size: 12, weight: .bold))
                Text(mode == .baby ? "육아" : "임신")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(mode == .baby ? AppColors.primary : AppColors.pregnancyPink)
            .padding(.horizontal, 12).frame(height: 34)
            .liquidGlass(cornerRadius: Radius.pill)
        }
        .accessibilityLabel(mode == .baby ? "육아 모드, 탭하면 임신 모드로 전환" : "임신 모드, 탭하면 육아 모드로 전환")
    }
}
