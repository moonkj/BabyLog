import SwiftUI
import UIKit

// MARK: - HomeIconBadge (홈 리딩 아이콘 — 그라데이션 스퀴클, 앱아이콘 톤)
//
// 평면 단색 SF Symbol을 입체감 있는 squircle 배지로 격상한다.
// 대각 그라데이션 + 상단 하이라이트 + 헤어라인 + 부드러운 컬러 섀도우로
// '기본 아이콘' 느낌을 없애고 카드 위계의 시각적 앵커를 만든다.
struct HomeIconBadge: View {
    let symbol: String
    /// 기준 색(강조색). 이 색으로 그라데이션·섀도우를 파생한다.
    let tint: Color
    var size: CGFloat = 46
    /// 채움 스타일 — solid(컬러 배경+흰 심볼) / soft(연한 배경+컬러 심볼)
    var soft: Bool = false

    private var corner: CGFloat { size * 0.30 }

    var body: some View {
        ZStack {
            if soft {
                // 연한 틴트 배경 + 컬러 심볼 (밝은 카드 위 부드러운 변형)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.20), tint.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                symbolView(color: tint)
            } else {
                // 컬러 그라데이션 배경 + 흰 심볼 (강한 앵커)
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.86), tint],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                // 상단 광택 하이라이트
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.30), Color.white.opacity(0.0)],
                            startPoint: .top, endPoint: .center
                        )
                    )
                symbolView(color: .white)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(soft ? 0.0 : 0.28), lineWidth: 0.6)
        }
        .shadow(color: tint.opacity(soft ? 0.18 : 0.34), radius: size * 0.16, x: 0, y: size * 0.09)
        .accessibilityHidden(true)
    }

    private func symbolView(color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }
}

// MARK: - 홈 레이아웃 라인 아이콘(핸드오프 home_layout_icons_handoff/svg)

/// 히어로(사진프레임+얼굴) · 대시보드(2×2 타일) · 타임라인(점 연결) 라인 글리프. 24×24 viewBox.
struct HomeLayoutGlyph: Shape {
    let layout: HomeLayout
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var p = Path()
        switch layout {
        case .hero:
            p.addRoundedRect(in: CGRect(x: 3.5 * s, y: 4.5 * s, width: 17 * s, height: 15 * s),
                             cornerSize: CGSize(width: 3 * s, height: 3 * s))
            p.addEllipse(in: CGRect(x: (12 - 2.4) * s, y: (10 - 2.4) * s, width: 4.8 * s, height: 4.8 * s))
            p.move(to: P(6, 18.5))
            p.addCurve(to: P(12, 14.5), control1: P(7, 15.9), control2: P(9.2, 14.5))
            p.addCurve(to: P(18, 18.5), control1: P(14.8, 14.5), control2: P(17, 15.9))
        case .dashboard:
            for (x, y) in [(4.0, 4.0), (13.0, 4.0), (4.0, 13.0), (13.0, 13.0)] {
                p.addRoundedRect(in: CGRect(x: x * s, y: y * s, width: 7 * s, height: 7 * s),
                                 cornerSize: CGSize(width: 2 * s, height: 2 * s))
            }
        }
        return p
    }
}

/// 레이아웃 라인 아이콘 뷰(stroke).
struct HomeLayoutIcon: View {
    let layout: HomeLayout
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var body: some View {
        HomeLayoutGlyph(layout: layout)
            .stroke(color, style: StrokeStyle(lineWidth: max(1.6, size * 0.08), lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - 홈 레이아웃 열거형
enum HomeLayout: String, CaseIterable {
    case hero      = "hero"
    case dashboard = "dashboard"
    // 타임라인 레이아웃 제거 — 기록 탭에 동일 타임라인이 있어 중복이었다.

    var label: String {
        switch self {
        case .hero:      return "히어로"
        case .dashboard: return "대시보드"
        }
    }

    /// 시스템 메뉴 아이템용 SF 심볼(메뉴는 커스텀 도형 렌더 불가). 버튼은 HomeLayoutIcon 사용.
    var icon: String {
        switch self {
        case .hero:      return "person.crop.rectangle"
        case .dashboard: return "square.grid.2x2"
        }
    }
}

// MARK: - 홈 (오늘의 한 장면) — 스크린샷 01-home 재현
struct HomeTab: View {

    // MARK: AppStore — 실데이터
    @EnvironmentObject private var store: AppStore

    /// 홈 카드(요약·진입점) 탭 시 해당 탭으로 이동시키는 콜백. MainTabView가 주입.
    var onNavigate: (AppTab) -> Void = { _ in }
    /// 빠른 기록(사진 등록 시트) 바로 열기 콜백. MainTabView가 주입(FAB와 동일 동작).
    var onQuickRecord: () -> Void = {}
    @State private var showEmergency = false
    @State private var showAddChild = false
    @State private var showLayoutMenu = false
    @State private var editingChild: Child? = nil
    @State private var showPeerTip = false
    @State private var showNoMemory = false
    @State private var memoryViewerPhoto: UIImage? = nil

    /// 현재 선택된 아이 — store 전역 선택을 단일 소스로 사용(모든 탭과 동기화).
    private var selectedChild: Child? { store.selectedChild }

    // MARK: 실데이터 요약 값
    /// 이번 달 육아비 (store 영속 지출)
    private var monthlyBudgetTotal: Int {
        BudgetSummary.monthlyTotal(store.expenses, in: Date())
    }
    /// 선택 아이의 전체 기록 수 (다이어리 + 성장)
    private var recordCount: Int {
        guard let id = selectedChild?.id else { return 0 }
        return store.diaryEntries(for: id).count + store.growthRecords(for: id).count
    }
    /// 시간대 인사
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "좋은 아침이에요 ☀️"
        case 12..<17: return "좋은 오후예요 🌤"
        case 17..<21: return "좋은 저녁이에요 🌆"
        default:      return "편안한 밤이에요 🌙"
        }
    }

    /// 선택 아이 대표 사진 — 프로필 사진 우선, 없으면 최근 기록 사진 (감정 진입점)
    private var heroPhoto: UIImage? {
        guard let child = selectedChild else { return nil }
        if let profile = PhotoStore.image(child.profileImageRef) { return profile }
        let withPhoto = store.diaryEntries(for: child.id).first { $0.photoRef != nil }
        return PhotoStore.image(withPhoto?.photoRef)
    }
    /// 금액 축약 표기 (만원/원)
    private func amountShort(_ amount: Int) -> String {
        guard amount > 0 else { return "0원" }
        if amount >= 10_000 {
            let man = Double(amount) / 10_000
            return man == man.rounded() ? "\(Int(man))만원" : String(format: "%.1f만원", man)
        }
        return "\(amount)원"
    }

    // MARK: Priority Engine — 실데이터(아이 생년월일 기반 표준 접종 일정)
    // ⚠️ vaccineId는 반드시 VaccineScheduleProviding 카탈로그와 동일 문자열을 사용한다.
    //    (접종 완료 키 = "childId|vaccineId" — Record 탭 완료가 홈 우선순위에 반영되려면 id 일치 필수)
    private struct StdVaccine { let month: Int; let id: String }
    /// 질병관리청 표준 예방접종 일정(참조) — 월령 기준. id는 provider 카탈로그와 일치.
    private static let standardVaccines: [StdVaccine] = [
        .init(month: 0,  id: "BCG"),     .init(month: 0,  id: "HepB-1"),
        .init(month: 1,  id: "HepB-2"),  .init(month: 2,  id: "DTaP-1"),
        .init(month: 2,  id: "IPV-1"),   .init(month: 2,  id: "Hib-1"),
        .init(month: 2,  id: "PCV-1"),   .init(month: 4,  id: "DTaP-2"),
        .init(month: 6,  id: "DTaP-3"),  .init(month: 12, id: "MMR-1"),
        .init(month: 12, id: "Varicella"), .init(month: 15, id: "DTaP-4"),
    ]

    /// 선택 아이의 미완료 표준 접종(실제 생년월일로 예정일 계산)
    private var upcomingVaccines: [VaccineRecord] {
        guard let c = selectedChild else { return [] }
        let cal = Calendar.current
        return Self.standardVaccines.compactMap { v in
            guard !store.isVaccineDone(childId: c.id, vaccineId: v.id),
                  let date = cal.date(byAdding: .month, value: v.month, to: c.birthDate) else { return nil }
            return VaccineRecord(id: UUID(), childId: c.id, vaccineId: v.id,
                                 scheduledDate: date, completedDate: nil,
                                 hospital: store.vaccineHospital(childId: c.id, vaccineId: v.id))
        }
    }

    /// 두 날짜의 자정(startOfDay) 기준 일수 차 — '1년 전 오늘 ±3일' 판정 공용 헬퍼.
    /// raw 타임스탬프로 dateComponents를 비교하면 윈도가 비대칭(최대 ±3일23시간)이 되고
    /// memoryEntry와 판정이 어긋나므로, 두 판정 모두 이 헬퍼로 통일한다.
    private func memoryDayDiff(_ a: Date, _ b: Date, _ cal: Calendar = .current) -> Int {
        cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? .max
    }

    private var priorityItem: PriorityItem? {
        let cid = selectedChild?.id
        let hasToday: Bool = {
            guard let cid else { return false }
            return store.diaryEntries(for: cid).contains { Calendar.current.isDateInToday($0.date) }
        }()
        // 약 1년 전(±3일) 실제 기록이 있을 때만 '추억' 카드 — 없으면 거짓 추억을 띄우지 않는다.
        // (memoryEntry와 동일하게 startOfDay 기준 day-diff + 최근접 .min 선택으로 판정 통일)
        let yearAgoId: String? = {
            guard let cid else { return nil }
            let cal = Calendar.current
            guard let target = cal.date(byAdding: .year, value: -1, to: Date()) else { return nil }
            return store.diaryEntries(for: cid)
                .filter { abs(memoryDayDiff($0.date, target, cal)) <= 3 }
                .min { abs(memoryDayDiff($0.date, target, cal)) < abs(memoryDayDiff($1.date, target, cal)) }?
                .id.uuidString
        }()
        return PriorityEngine.topPriority(
            vaccines: upcomingVaccines,
            subsidies: [],   // 지원금 카드는 가계부 탭 전담 — 홈 우선순위에선 의도적 비활성
            hasRecentRecord: hasToday,
            yearAgoMemoryId: yearAgoId,
            now: Date()
        )
    }

    // MARK: 레이아웃 상태 — AppStorage로 앱 재시작 후에도 보존
    @AppStorage("home_layout") private var layoutRaw: String = HomeLayout.hero.rawValue

    private var currentLayout: HomeLayout {
        HomeLayout(rawValue: layoutRaw) ?? .hero
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 + 아이 칩은 ScrollView 밖 고정 — 매초 갱신(생애시계)에 탭이 가로채이지 않게,
            // 그리고 아이 전환/추가가 항상 닿게.
            VStack(alignment: .leading, spacing: Spacing.s4) {
                header
                childChips
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s4)
            .padding(.bottom, Spacing.s3)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    layoutContent
                        .id(currentLayout)
                        .transition(.opacity)
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s1)
            }
            .animation(.easeInOut(duration: 0.2), value: currentLayout)
        }
        .background(AppColors.canvas)
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyScreen(onClose: { showEmergency = false })
        }
        .sheet(isPresented: $showAddChild) {
            AddChildSheet().environmentObject(store)
        }
        .sheet(item: $editingChild) { child in
            AddChildSheet(editing: child).environmentObject(store)
        }
        .alert(peerAgeMonths.map { "\($0)개월 또래 이야기" } ?? "또래 이야기",
               isPresented: $showPeerTip) {
            Button("확인", role: .cancel) {}
        } message: { Text(peerTip) }
        .alert("1년 전 오늘", isPresented: $showNoMemory) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("아직 1년 전 오늘의 기록이 없어요. 오늘의 순간을 남기면 내년에 다시 만나요.")
        }
        .fullScreenCover(isPresented: Binding(
            get: { memoryViewerPhoto != nil },
            set: { if !$0 { memoryViewerPhoto = nil } }
        )) {
            if let img = memoryViewerPhoto {
                FullScreenPhotoView(image: img, onClose: { memoryViewerPhoto = nil })
            }
        }
    }

    // 1년 전 오늘 타일 동작: 사진 있으면 전체보기, 없으면 안내
    private func openMemory() {
        if let img = PhotoStore.image(memoryEntry?.photoRef) {
            memoryViewerPhoto = img
        } else if memoryEntry != nil {
            onNavigate(.record)
        } else {
            showNoMemory = true
        }
    }

    // MARK: 레이아웃별 콘텐츠
    @ViewBuilder
    private var layoutContent: some View {
        switch currentLayout {
        case .hero:
            heroLayout
        case .dashboard:
            dashboardLayout
        }
    }

    // MARK: - 공통 헤더
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.ink3)
                Text("베이비로그").font(.system(size: 28, weight: .heavy)).tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            // 레이아웃 전환 메뉴
            layoutMenu
            // 응급 버튼
            Button { Haptics.light(); showEmergency = true } label: {
                Label("응급", systemImage: "cross.case.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 44)
                    .background(AppColors.danger, in: Capsule())
            }
            .buttonStyle(LiquidPressStyle())
            .accessibilityLabel("응급 메뉴 열기")
        }
    }

    // MARK: 레이아웃 전환 메뉴 (커스텀 팝오버 — 핸드오프 라인 글리프 사용)
    private var layoutMenu: some View {
        Button {
            Haptics.light()
            showLayoutMenu = true
        } label: {
            HomeLayoutIcon(layout: currentLayout, color: MotionIconPalette.green, size: 22)
                .frame(width: 44, height: 44)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                }
                .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("홈 레이아웃 변경. 현재: \(currentLayout.label)")
        .popover(isPresented: $showLayoutMenu) {
            VStack(spacing: 2) {
                ForEach(HomeLayout.allCases, id: \.rawValue) { layout in
                    let selected = layout == currentLayout
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { layoutRaw = layout.rawValue }
                        showLayoutMenu = false
                    } label: {
                        HStack(spacing: 12) {
                            HomeLayoutIcon(layout: layout,
                                           color: selected ? AppColors.gold : Color(hex: 0x3F6B55),
                                           size: 22)
                            Text(layout.label)
                                .font(.system(size: 15, weight: selected ? .bold : .medium))
                                .foregroundStyle(selected ? AppColors.gold : AppColors.ink)
                            Spacer(minLength: 12)
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AppColors.gold)
                            }
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(selected ? AppColors.goldTint : Color.clear,
                                    in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("레이아웃 \(layout.label)\(selected ? ", 현재 선택됨" : "")")
                }
            }
            .padding(8)
            .frame(width: 220)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - 다자녀 칩
    private var childChips: some View {
        HStack(spacing: 8) {
            ForEach(store.children) { child in
                let isSelected = child.id == store.selectedChild?.id
                Button {
                    if isSelected {
                        editingChild = child   // 이미 선택된 아이 다시 탭 → 정보 수정
                    } else {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.15)) {
                            store.selectedChildId = child.id   // 전역 선택(모든 탭 동기화)
                        }
                    }
                } label: {
                    chip(child: child, on: isSelected)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .contextMenu {
                    Button { editingChild = child } label: {
                        Label("아이 정보 수정", systemImage: "pencil")
                    }
                }
            }
            Button {
                Haptics.light()
                showAddChild = true
            } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.ink3)
                    .frame(width: 34, height: 34)
                    .background(AppColors.surface, in: Circle())
                    .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LiquidPressStyle(scale: 0.92))
            .accessibilityLabel("아이 추가")
        }
    }

    private func chip(child: Child, on: Bool) -> some View {
        HStack(spacing: 6) {
            // 이모지(👶) 대체 — 보들머리 아바타(사진 있으면 썸네일)
            ChildAvatar(child: child, size: 24)
                .padding(.leading, -2)
            Text(child.name).font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(on ? AppColors.ink : AppColors.ink2)
        .padding(.horizontal, 12).frame(height: 34)
        .frame(maxWidth: 130)
        .background(on ? AppColors.surface : AppColors.surface2, in: Capsule())
        .overlay { Capsule().stroke(on ? AppColors.primary.opacity(0.4) : AppColors.line, lineWidth: 1) }
        .accessibilityLabel("\(child.name) 선택\(on ? ", 현재 선택됨" : "")")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: ═══════════════════════════════════
    // MARK: A — 히어로 레이아웃 (기본)
    // MARK: ═══════════════════════════════════
    private var heroLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            heroCard
            // 단순 '기록 권유'는 아래 nudgeCard가 담당 — 금색 '지금 가장 중요해요' 카드는
            // 접종·지원금·추억 등 진짜 우선순위일 때만(중복·과장 제거).
            if showsHeroPriority { priorityCard }
            nudgeCard
            peerCard
            if memoryEntry != nil { memoryCard }
        }
    }

    /// 금색 우선순위 카드 노출 여부 — 단순 기록 권유(.recordNudge)는 제외.
    private var showsHeroPriority: Bool {
        guard let kind = priorityItem?.kind else { return false }
        return kind != .recordNudge
    }

    /// 1년 전 오늘(±3일)의 다이어리 기록 — 있으면 추억 카드 노출
    /// (yearAgoMemoryId와 같은 startOfDay 기반 day-diff 헬퍼 + 최근접 .min 선택으로 통일 —
    ///  두 곳의 판정/선택이 어긋나 카드와 우선순위가 다른 기록을 가리키던 문제 방지)
    private var memoryEntry: DiaryEntry? {
        guard let cid = selectedChild?.id else { return nil }
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .year, value: -1, to: Date()) else { return nil }
        return store.diaryEntries(for: cid)
            .filter { abs(memoryDayDiff($0.date, target, cal)) <= 3 }
            .min { abs(memoryDayDiff($0.date, target, cal)) < abs(memoryDayDiff($1.date, target, cal)) }
    }

    private var heroCard: some View {
        let childName: String
        let dPlusLabel: String
        let accessLabel: String
        if let child = selectedChild {
            let now = Date()
            let dPlus = AgeCalculator.dPlusDays(birthDate: child.birthDate, asOf: now)
            let age = AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: now)
            childName = child.name
            dPlusLabel = "D+\(dPlus) · \(age.months)개월"
            accessLabel = "\(child.name) 최근 사진. D+\(dPlus), \(age.months)개월"
        } else {
            childName = "우리 아기"
            dPlusLabel = ""
            accessLabel = "아직 등록된 아이가 없어요"
        }

        return Group {
            if let img = heroPhoto {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                PhotoPlaceholder(seed: 1, cornerRadius: Radius.lg)
            }
        }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.width - Spacing.s5 * 2)   // 1:1 정사각형(좌우 여백 제외)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                LinearGradient(
                    // 밝은 사진 위에서도 이름·D+day가 항상 읽히도록 하단을 다단계로 강하게.
                    colors: [.clear, .clear, .black.opacity(0.35), .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(childName).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                        if !dPlusLabel.isEmpty {
                            // 생애 시계 ★ — 상시 시그니처 모션 (DESIGN.md §8.2)
                            LifeClockView(size: 18, hand: AppColors.gold, ring: .white)
                            Text(dPlusLabel)
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 8).frame(height: 22)
                                .background(.black.opacity(0.22), in: Capsule())
                        }
                    }
                    if selectedChild == nil {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill").font(.system(size: 14, weight: .bold))
                            Text("아이 등록하고 성장 기록 시작하기")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 34)
                        .background(AppColors.primary, in: Capsule())
                    }
                }
                .padding(16)
            }
            // 사진을 주인공으로 — 흰 매트 액자 테두리 + 따뜻한 깊은 그림자.
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
            }
            .blShadow(.card)
            .contentShape(Rectangle())
            .onTapGesture { if selectedChild == nil { showAddChild = true } }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessLabel)
            .accessibilityAddTraits(selectedChild == nil ? .isButton : [])
            .accessibilityHint(selectedChild == nil ? "탭하면 아이를 등록합니다" : "")
    }

    /// 우선순위 종류별 CTA 라벨 — 종류에 맞는 행동 카피.
    private func priorityActionLabel(_ kind: PriorityKind) -> String {
        switch kind {
        case .vaccine:     return "접종 확인하기"
        case .recordNudge: return "기록 남기기"
        case .memory:      return "추억 보기"
        case .subsidy:     return "지원금 보기"
        case .emergency:   return "응급 정보"
        }
    }

    /// 우선순위 종류별 라우팅 — 전용 내비 훅이 없으면 가장 가까운 탭으로 이동.
    private func priorityAction(_ kind: PriorityKind) {
        switch kind {
        case .vaccine, .recordNudge, .memory, .emergency:
            onNavigate(.record)
        case .subsidy:
            onNavigate(.budget)
        }
    }

    /// 우선순위 종류별 대표 아이콘 (시각적 무게용 리딩 아이콘).
    private func priorityIcon(_ kind: PriorityKind) -> String {
        switch kind {
        case .emergency:    return "cross.case.fill"
        case .vaccine:      return "syringe.fill"
        case .subsidy:      return "won.sign.circle.fill"
        case .recordNudge:  return "camera.fill"
        case .memory:       return "clock.fill"
        }
    }

    // MARK: - 우선순위 카드 (PriorityEngine 연결 — A·B·C 공용)
    @ViewBuilder
    private var priorityCard: some View {
        if let item = priorityItem {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    // 시각적 무게를 위한 리딩 아이콘 — 그라데이션 스퀴클 배지
                    HomeIconBadge(symbol: priorityIcon(item.kind), tint: AppColors.gold, size: 46)
                    VStack(alignment: .leading, spacing: 6) {
                        Label("지금 가장 중요해요", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.gold)
                        Text(item.title)
                            .font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                        Text(item.subtitle)
                            .font(AppFont.caption).foregroundStyle(AppColors.ink2)
                    }
                    Spacer()
                    if let dDay = item.dDay {
                        Text("D-\(dDay)")
                            .font(.system(size: 22, weight: .heavy)).foregroundStyle(AppColors.gold)
                            .accessibilityLabel("디데이 \(dDay)일 전")
                    }
                }
                // CTA 단일 버튼 — 종(알람) 버튼은 실제 리마인더 기능이 없어 같은 동작을 중복하던
                // 가짜 버튼이라 제거(정직 원칙). 리마인더가 필요하면 별도 기능으로.
                LiquidButton(fill: AppColors.gold, action: { priorityAction(item.kind) }) {
                    Text(priorityActionLabel(item.kind))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .blShadow(.card)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("우선순위 카드: \(item.title). \(item.subtitle)")
        }
    }

    // MARK: 우선순위 카드 — compact (대시보드용)
    @ViewBuilder
    private var priorityCardCompact: some View {
        if let item = priorityItem {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("지금 가장 중요해요", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.gold)
                    Text(item.title)
                        .font(.system(size: 15, weight: .heavy)).foregroundStyle(AppColors.ink)
                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink2)
                        .lineLimit(1)
                }
                Spacer()
                if let dDay = item.dDay {
                    VStack(spacing: 0) {
                        Text("D-\(dDay)")
                            .font(.system(size: 26, weight: .heavy)).foregroundStyle(AppColors.gold)
                        Button { onNavigate(.record) } label: {
                            Text("확인").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(AppColors.gold, in: Capsule())
                        }
                        .buttonStyle(LiquidPressStyle())
                        .accessibilityLabel("접종 일정 확인하기")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("디데이 \(dDay)일 전")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .blShadow(.card)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("우선순위: \(item.title). \(item.subtitle)")
        }
    }

    // MARK: 기록 권유 카드
    private var nudgeCard: some View {
        let name = selectedChild?.name ?? "우리 아기"
        return HStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name)의 오늘이 궁금해요").font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("사진 한 장이면 기록 끝 — 2탭이면 돼요").font(AppFont.caption).foregroundStyle(AppColors.ink2)
            }
            Spacer()
            Button { onQuickRecord() } label: {
                Text("기록").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(height: 44)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(LiquidPressStyle())
            .accessibilityLabel("기록하기")
            .accessibilityHint("사진 등록 화면을 바로 엽니다")
        }
        .padding(14)
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name)의 오늘이 궁금해요. 사진 한 장이면 기록 끝")
    }

    // MARK: 또래 이야기 카드 (실 월령 기반)
    private var peerAgeMonths: Int? {
        guard let c = selectedChild else { return nil }
        return AgeCalculator.childAgeMonths(birthDate: c.birthDate, asOf: Date()).months
    }
    private var peerTip: String {
        guard let m = peerAgeMonths else {
            return "아이를 등록하면 월령에 맞는 또래 발달 이야기를 알려드려요."
        }
        switch m {
        case 0..<3:   return "신생아 시기엔 하루 대부분을 잠으로 보내요. 수유·기저귀 패턴을 기록해두면 리듬이 보여요."
        case 3..<6:   return "목 가누기가 시작되는 시기예요. 뒤집기와 배밀이를 연습하며 시야가 넓어져요."
        case 6..<9:   return "이유식을 시작하는 시기예요. 혼자 앉기 시작하고 낯가림이 나타날 수 있어요."
        case 9..<12:  return "잡고 서기·기어다니기가 활발해져요. 첫 단어가 나오기도 하는 시기예요."
        case 12..<18: return "걸음마와 첫 단어가 늘어나는 시기예요. '맘마', '아빠' 외 새 단어를 시도하면 대화로 격려해주세요."
        case 18..<24: return "두 단어를 잇는 짧은 문장이 시작돼요. 자기 주장이 강해지는 자연스러운 시기예요."
        default:      return "상상 놀이와 어휘가 폭발적으로 늘어요. 함께 그림책을 읽으면 표현이 풍부해져요."
        }
    }
    private var peerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let m = peerAgeMonths {
                BLBadge(tone: .purple, text: "\(m)개월")
            }
            Label(peerAgeMonths.map { "\($0)개월 또래 이야기" } ?? "또래 이야기", systemImage: "sparkles")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color(hex: 0x5B53B0))
            Text(peerTip)
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(AppColors.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEDEBFB), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .blShadow(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("또래 이야기: \(peerTip)")
    }

    // MARK: 1년 전 오늘 카드
    private var memoryCard: some View {
        Button {
            openMemory()
        } label: {
            HStack(spacing: 0) {
                // 실제 추억 사진 노출 — 없을 때만 플레이스홀더로 폴백
                Group {
                    if let img = PhotoStore.image(memoryEntry?.photoRef) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        PhotoPlaceholder(seed: 3, cornerRadius: 0)
                    }
                }
                .frame(width: 100, height: 100)
                .clipped()
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    BLBadge(tone: .pink, text: "1년 전 오늘", systemIcon: "clock.badge")
                    Text(memoryEntry?.content ?? memoryEntry?.milestone ?? "소중한 순간을 남긴 날 🥰")
                        .font(AppFont.callout)
                        .foregroundStyle(AppColors.ink)
                        .lineSpacing(2)
                        .lineLimit(1)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .blShadow(.card)
        }
        .buttonStyle(LiquidPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("1년 전 오늘: \(memoryEntry?.content ?? memoryEntry?.milestone ?? "소중한 순간")")
        .accessibilityHint("탭하면 추억을 돌아봐요")
    }

    // MARK: ═══════════════════════════════════
    // MARK: B — 대시보드 레이아웃 (2열 타일 그리드)
    // MARK: ═══════════════════════════════════
    private var dashboardLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            // compact 헤더 (아이 아바타 + 이름 + 월령)
            dashboardChildHeader
            // 우선순위 카드 compact — PriorityEngine 연결 유지
            priorityCardCompact
            // 2열 타일 그리드
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Spacing.s4), GridItem(.flexible(), spacing: Spacing.s4)],
                spacing: Spacing.s4
            ) {
                dashTileBudget
                dashTilePeer
                dashTileMemory
                dashTileRecord
                dashTileNudge
            }
        }
    }

    private var dashboardChildHeader: some View {
        let childName: String
        let statLine: String
        let accessLabel: String
        if let child = selectedChild {
            let now = Date()
            let dPlus = AgeCalculator.dPlusDays(birthDate: child.birthDate, asOf: now)
            let age = AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: now)
            childName = child.name
            statLine = "D+\(dPlus) · \(age.months)개월"
            accessLabel = "\(child.name). D+\(dPlus), \(age.months)개월"
        } else {
            childName = "우리 아기"
            statLine = "아이를 등록해주세요"
            accessLabel = "등록된 아이가 없어요"
        }

        return HStack(spacing: 12) {
            Group {
                if let img = heroPhoto {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    PhotoPlaceholder(seed: 2, cornerRadius: Radius.md)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(childName).font(.system(size: 24, weight: .heavy)).foregroundStyle(AppColors.ink)
                Text(statLine)
                    .font(AppFont.num(13)).foregroundStyle(AppColors.ink2)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessLabel)
    }

    private var dashTileBudget: some View {
        dashTile(
            icon: "creditcard.fill",
            iconColor: Color(hex: 0x3B6FA8),
            bg: AppColors.surface,
            title: amountShort(monthlyBudgetTotal),
            sub: "이번 달 육아비",
            accessLabel: "가계부 타일: 이번 달 육아비 \(amountShort(monthlyBudgetTotal))",
            action: { onNavigate(.budget) }
        )
    }

    private var dashTilePeer: some View {
        dashTile(
            icon: "person.2.fill",
            iconColor: Color(hex: 0x2E7A5C),
            bg: AppColors.surface,
            title: "또래 이야기",
            sub: "오늘의 발달 팁",
            accessLabel: "또래 이야기 타일: 오늘의 발달 팁",
            action: { showPeerTip = true }
        )
    }

    private var dashTileMemory: some View {
        dashTile(
            icon: "clock.fill",
            iconColor: Color(hex: 0xB5478A),
            bg: AppColors.surface,
            title: "1년 전 오늘",
            sub: "추억 돌아보기",
            accessLabel: "추억 타일: 1년 전 오늘",
            action: { openMemory() }
        )
    }

    private var dashTileRecord: some View {
        dashTile(
            icon: "camera.fill",
            iconColor: AppColors.primary,
            bg: AppColors.surface,
            title: "\(recordCount)개",
            sub: "전체 기록",
            accessLabel: "기록 타일: \(recordCount)개 기록",
            action: { onNavigate(.record) }
        )
    }

    private var dashTileNudge: some View {
        Button { onNavigate(.record) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HomeIconBadge(symbol: "plus", tint: AppColors.primary, size: 44)
                    Spacer()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("기록하기").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                    Text("오늘 순간 남기기").font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.primary.opacity(0.2), lineWidth: 1)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle())
        .accessibilityLabel("기록하기 타일: 오늘 순간 남기기")
    }

    private func dashTile(
        icon: String,
        iconColor: Color,
        bg: Color,
        title: String,
        sub: String,
        accessLabel: String,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HomeIconBadge(symbol: icon, tint: iconColor, size: 44)
                    Spacer()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppFont.num(15, weight: .heavy)).foregroundStyle(AppColors.ink)
                    Text(sub).font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(bg, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .blShadow(.card)
        }
        .buttonStyle(LiquidPressStyle())
        .accessibilityLabel(accessLabel)
    }

}

// MARK: - 동네 (주변/마켓/크루 세그먼트)
struct DongneTab: View {
    @EnvironmentObject private var store: AppStore
    @State private var seg = 0
    @State private var showEmergency = false
    @State private var showHoodManage = false
    @ObservedObject private var location = NearbyLocationProvider.shared

    /// 세그먼트 구성 — 마켓은 피처 플래그(AppFeatures.market) ON일 때만 노출.
    private enum DongneSeg { case nearby, market, crew
        var title: String { self == .nearby ? "주변" : (self == .market ? "마켓" : "크루") }
        var glyph: NavGlyph { self == .nearby ? .nearby : (self == .market ? .market : .crew) }
    }
    private var segItems: [DongneSeg] {
        AppFeatures.market ? [.nearby, .market, .crew] : [.nearby, .crew]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isNearbySeg ? "내 주변 · 위치 기반" : "내 동네 기반")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.ink3)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("동네").font(.system(size: 28, weight: .heavy)).tracking(-0.4).foregroundStyle(AppColors.ink)
                            if isNearbySeg {
                                // 주변·응급: 실시간 GPS 행정동(역지오코딩)
                                if let loc = location.localityName {
                                    HStack(spacing: 4) {
                                        LocationPinIcon(color: MotionIconPalette.green, size: 17)
                                        Text(loc).font(.system(size: 13.5, weight: .bold))
                                            .foregroundStyle(AppColors.ink2).lineLimit(1)
                                    }
                                    .accessibilityLabel("현재 위치 \(loc)")
                                }
                            } else {
                                hoodSwitcher   // 마켓·크루: 내 동네 선택/추가(GPS 자동추적 안 함)
                            }
                        }
                    }
                    Spacer()
                    Button { Haptics.light(); showEmergency = true } label: {
                        Label("응급", systemImage: "cross.case.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).frame(height: 44)
                            .background(AppColors.danger, in: Capsule())
                    }
                    .buttonStyle(LiquidPressStyle())
                    .accessibilityLabel("응급 메뉴 열기")
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s4)

                HStack(spacing: 4) {
                    ForEach(segItems.indices, id: \.self) { i in
                        Button {
                            guard seg != i else { return }
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.18)) { seg = i }
                        } label: {
                            HStack(spacing: 5) {
                                NavLineIcon(glyph: segItems[i].glyph,
                                            color: seg == i ? Color.white : NavPalette.inactive,
                                            size: 18, bold: seg == i)
                                Text(segItems[i].title).font(.system(size: 14.5, weight: .bold))
                            }
                            .foregroundStyle(seg == i ? .white : AppColors.ink2)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background {
                                if seg == i {
                                    Capsule().fill(Color(hex: 0x4E8268)).blShadow(.chip)  // 세이지그린 선택
                                }
                            }
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.97))
                    }
                }
                .padding(4)
                .background(AppColors.surface2, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                .padding(.horizontal, Spacing.s5)

                switch segItems[min(seg, segItems.count - 1)] {
                case .nearby:
                    NearbyScreen()
                case .market:
                    MarketScreen()
                case .crew:
                    CrewScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppColors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { location.start() }   // 주변 라벨 + '현재 위치 추가' 인증용 GPS 확보
            // 크루 자동 카운트·알림은 '내 동네'(선택) 기준 — 지나가는 동네에 자동 등록 안 함(스팸 방지)
            .onChange(of: store.selectedHood) { _, hood in
                if let hood { Task { await CrewBackend.syncNeighborhood(hood: hood) } }
            }
            .task { if let hood = store.selectedHood { await CrewBackend.syncNeighborhood(hood: hood) } }
            .fullScreenCover(isPresented: $showEmergency) {
                EmergencyScreen(onClose: { showEmergency = false })
            }
            .sheet(isPresented: $showHoodManage) { hoodManageSheet }
        }
    }

    private var currentSeg: DongneSeg { segItems[min(seg, segItems.count - 1)] }
    private var isNearbySeg: Bool { currentSeg == .nearby }

    // 내 동네 스위처(마켓·크루) — 선택 전환 + 현재 위치로 추가(인증) + 관리
    private var hoodSwitcher: some View {
        Menu {
            ForEach(Array(store.myNeighborhoods.enumerated()), id: \.offset) { idx, h in
                Button { store.selectNeighborhood(idx); Haptics.selection() } label: {
                    Label(h, systemImage: idx == store.selectedHoodIndex ? "checkmark" : "mappin.circle")
                }
            }
            if store.myNeighborhoods.count < 2, let gps = location.localityName,
               !store.myNeighborhoods.contains(gps) {
                Divider()
                Button { store.addNeighborhood(gps); Haptics.success() } label: {
                    Label("현재 위치 ‘\(gps)’ 추가", systemImage: "plus.circle")
                }
            }
            if !store.myNeighborhoods.isEmpty {
                Divider()
                Button { showHoodManage = true } label: { Label("동네 관리", systemImage: "slider.horizontal.3") }
            }
        } label: {
            HStack(spacing: 4) {
                LocationPinIcon(color: MotionIconPalette.green, size: 17)
                Text(store.selectedHood ?? "내 동네 설정")
                    .font(.system(size: 13.5, weight: .bold)).foregroundStyle(AppColors.ink2).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityLabel("내 동네 \(store.selectedHood ?? "미설정"). 탭하면 전환·추가")
    }

    private var hoodManageSheet: some View {
        NavigationStack {
            List {
                Section("내 동네 (최대 2개)") {
                    ForEach(Array(store.myNeighborhoods.enumerated()), id: \.offset) { idx, h in
                        HStack(spacing: 8) {
                            LocationPinIcon(color: MotionIconPalette.green, size: 16)
                            Text(h).font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.ink)
                            if idx == store.selectedHoodIndex {
                                Spacer()
                                Text("사용 중").font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { store.selectNeighborhood(idx) }
                    }
                    .onDelete { idx in if let i = idx.first { store.removeNeighborhood(at: i) } }
                    if store.myNeighborhoods.count < 2 {
                        if let gps = location.localityName, !store.myNeighborhoods.contains(gps) {
                            Button { store.addNeighborhood(gps); Haptics.success() } label: {
                                Label("현재 위치 ‘\(gps)’ 추가", systemImage: "plus.circle.fill")
                            }
                        } else {
                            Text("동네를 추가하려면 그 동네에 있을 때 추가하세요 (위치 인증).")
                                .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                        }
                    }
                }
                Section {
                    Text("마켓·크루는 내 동네 기준으로 보여요. 주변·응급은 현재 위치를 따릅니다.")
                        .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                }
            }
            .navigationTitle("내 동네")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { showHoodManage = false } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - 가계부
struct BudgetTab: View {
    var body: some View { BudgetScreen() }
}

// MARK: - 내정보
struct ProfileTab: View {
    var body: some View { ProfileScreen() }
}

// MARK: - Preview
#if DEBUG
#Preview("홈 탭") {
    HomeTab()
        .environmentObject(SampleData.store())
}
#endif

// MARK: - 공용 탭 스캐폴드
struct TabScaffold<Content: View>: View {
    var title: String
    var sub: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sub).font(AppFont.caption).foregroundStyle(AppColors.ink3)
                    Text(title).font(.system(size: 24, weight: .heavy)).foregroundStyle(AppColors.ink)
                }
                content()
                Color.clear.frame(height: 96)
            }
            .padding(Spacing.s5)
        }
        .background(AppColors.canvas)
    }
}
