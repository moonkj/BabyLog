import SwiftUI

enum AppTab: Hashable { case home, record, dongne, budget, profile }
enum AppMode { case baby, pregnancy }

/// 5탭 하단 네비게이션 (기능 8) — iOS 26에서 TabView는 시스템 Liquid Glass 탭바로 렌더.
/// 온보딩 게이트 → 메인. 우하단 빠른 기록 FAB → 빠른기록 시트. 좌하단 모드 전환(임신/육아).
struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("bl_onboarded") private var onboarded = false
    @AppStorage("bl_fab_side") private var fabSide = "right"
    @AppStorage("bl_night_dim") private var nightDim = false
    @State private var tab: AppTab = .home
    @State private var mode: AppMode = .baby
    @State private var showQuickRecord = false
    @State private var showAddChild = false
    @State private var showAddPregnancy = false
    @State private var showSplash = true
    // FAB 자유 위치(길게 눌러 드래그) — 기준 위치에서의 오프셋 영속
    @AppStorage("bl_fab_dx") private var fabDX: Double = 0
    @AppStorage("bl_fab_dy") private var fabDY: Double = 0
    @State private var fabDrag: CGSize = .zero
    @State private var fabDragging = false

    private var fabOnLeft: Bool { fabSide == "left" }

    /// FAB 길게 눌러(0.3s) 드래그로 위치 이동. 화면 밖으로 안 나가게 클램프 후 영속.
    private var fabMoveGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                if case .second(true, let drag) = value {
                    if !fabDragging { fabDragging = true; Haptics.light() }
                    if let drag { fabDrag = drag.translation }
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
                }
                fabDrag = .zero
                fabDragging = false
                Haptics.success()
            }
    }

    var body: some View {
        Group {
            if onboarded || store.hasContent {
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
        // 전역 뱃지 획득 카드 — 어느 화면에서든 표시
        .overlay {
            if let badge = store.pendingBadgeAward {
                BadgeAwardCard(badge: badge) {
                    withAnimation(.easeOut(duration: 0.25)) { store.pendingBadgeAward = nil }
                }
                .transition(.opacity)
                .zIndex(20)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.pendingBadgeAward?.id)
    }

    /// 야간 초저휘도 — 설정 ON 시 22~06시에 은은한 디밍(새벽 수유 배려). 5분마다 시간 재평가.
    @ViewBuilder
    private var nightDimOverlay: some View {
        if nightDim {
            TimelineView(.periodic(from: .now, by: 300)) { ctx in
                let hour = Calendar.current.component(.hour, from: ctx.date)
                let isNight = hour >= 22 || hour < 6
                Color.black
                    .opacity(isNight ? 0.32 : 0)
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
                    if mode == .pregnancy { PregnancyHomeView(onNavigate: { tab = $0 }) } else { HomeTab(onNavigate: { tab = $0 }) }
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

            // 빠른 기록 FAB (홈·기록) — 동네 탭은 팔기/모임 만들기 버튼이 있어 제외
            if tab == .home || tab == .record {
                QuickRecordFAB(mode: mode, onQuickRecord: {
                    Haptics.light()
                    // 아이/임신 미등록이면 빠른기록 대신 등록부터
                    if mode == .baby && store.children.isEmpty {
                        showAddChild = true
                    } else if mode == .pregnancy && store.activePregnancy == nil {
                        showAddPregnancy = true
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
        // 모드 전환 칩 (홈에서만, FAB 반대편) — iOS26 Liquid Glass
        .overlay(alignment: fabOnLeft ? .bottomTrailing : .bottomLeading) {
            if tab == .home {
                modeToggle
                    .padding(fabOnLeft ? .trailing : .leading, Spacing.s5)
                    .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $showAddChild) {
            AddChildSheet().environmentObject(store)
        }
        .sheet(isPresented: $showAddPregnancy) {
            AddPregnancySheet().environmentObject(store)
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
