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
        case .timeline:
            p.addEllipse(in: CGRect(x: (6 - 2) * s, y: (7 - 2) * s, width: 4 * s, height: 4 * s))
            p.addEllipse(in: CGRect(x: (6 - 2) * s, y: (17 - 2) * s, width: 4 * s, height: 4 * s))
            p.move(to: P(6, 9));  p.addLine(to: P(6, 15))
            p.move(to: P(11, 7)); p.addLine(to: P(19, 7))
            p.move(to: P(11, 17)); p.addLine(to: P(19, 17))
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
    case timeline  = "timeline"

    var label: String {
        switch self {
        case .hero:      return "히어로"
        case .dashboard: return "대시보드"
        case .timeline:  return "타임라인"
        }
    }

    /// 시스템 메뉴 아이템용 SF 심볼(메뉴는 커스텀 도형 렌더 불가). 버튼은 HomeLayoutIcon 사용.
    var icon: String {
        switch self {
        case .hero:      return "person.crop.rectangle"
        case .dashboard: return "square.grid.2x2"
        case .timeline:  return "list.bullet"
        }
    }
}

// MARK: - 홈 (오늘의 한 장면) — 스크린샷 01-home 재현
struct HomeTab: View {

    // MARK: AppStore — 실데이터
    @EnvironmentObject private var store: AppStore

    /// 홈 카드(요약·진입점) 탭 시 해당 탭으로 이동시키는 콜백. MainTabView가 주입.
    var onNavigate: (AppTab) -> Void = { _ in }
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

    // MARK: 홈 타임라인 실데이터
    struct HomeRecentItem: Identifiable {
        let id: UUID
        let badge: String?
        let caption: String
        let date: Date
        let tone: BadgeTone
        let icon: String?
        var photoRef: String? = nil
    }

    /// 선택 아이의 최근 기록(다이어리+성장) 최신순 최대 5건
    private var recentHomeRecords: [HomeRecentItem] {
        guard let cid = selectedChild?.id else { return [] }
        let diaries = store.diaryEntries(for: cid).map { e in
            HomeRecentItem(
                id: e.id,
                badge: e.milestone,
                caption: e.content ?? (e.recordType == "photo" ? "사진을 남겼어요" : "오늘의 기록"),
                date: e.date,
                tone: e.milestone != nil ? .amber : .mint,
                icon: e.recordType == "photo" ? nil : "text.alignleft",
                photoRef: e.photoRef
            )
        }
        let growth = store.growthRecords(for: cid).map { g in
            HomeRecentItem(id: g.id, badge: nil, caption: growthCaption(g),
                           date: g.date, tone: .blue, icon: "ruler")
        }
        return Array((diaries + growth).sorted { $0.date > $1.date }.prefix(5))
    }

    private func growthCaption(_ g: GrowthRecord) -> String {
        var parts: [String] = []
        if let h = g.heightCm { parts.append("키 \(formatMeasure(h))cm") }
        if let w = g.weightKg { parts.append("몸무게 \(formatMeasure(w))kg") }
        if let hc = g.headCircumferenceCm { parts.append("머리둘레 \(formatMeasure(hc))cm") }
        return parts.isEmpty ? "성장 기록" : parts.joined(separator: " · ")
    }

    private func formatMeasure(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "오늘" }
        if cal.isDateInYesterday(date) { return "어제" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                      to: cal.startOfDay(for: Date())).day ?? 0
        if days < 7 { return "\(days)일 전" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f.string(from: date)
    }

    // MARK: Priority Engine — 실데이터(아이 생년월일 기반 표준 접종 일정)
    private struct StdVaccine { let month: Int; let name: String }
    /// 질병관리청 표준 예방접종 일정(참조) — 월령 기준.
    private static let standardVaccines: [StdVaccine] = [
        .init(month: 2,  name: "DTaP 1차"),  .init(month: 4,  name: "DTaP 2차"),
        .init(month: 6,  name: "DTaP 3차"),  .init(month: 12, name: "MMR 1차"),
        .init(month: 12, name: "수두"),      .init(month: 12, name: "일본뇌염 1차"),
        .init(month: 15, name: "DTaP 4차"),  .init(month: 18, name: "일본뇌염 2차"),
        .init(month: 24, name: "일본뇌염 3차"), .init(month: 48, name: "DTaP 5차"),
    ]

    /// 선택 아이의 미완료 표준 접종(실제 생년월일로 예정일 계산)
    private var upcomingVaccines: [VaccineRecord] {
        guard let c = selectedChild else { return [] }
        let cal = Calendar.current
        return Self.standardVaccines.compactMap { v in
            guard !store.isVaccineDone(childId: c.id, vaccineId: v.name),
                  let date = cal.date(byAdding: .month, value: v.month, to: c.birthDate) else { return nil }
            return VaccineRecord(id: UUID(), childId: c.id, vaccineId: v.name,
                                 scheduledDate: date, completedDate: nil,
                                 hospital: store.vaccineHospital(childId: c.id, vaccineId: v.name))
        }
    }

    private var priorityItem: PriorityItem? {
        let hasToday: Bool = {
            guard let cid = selectedChild?.id else { return false }
            return store.diaryEntries(for: cid).contains { Calendar.current.isDateInToday($0.date) }
        }()
        return PriorityEngine.topPriority(
            vaccines: upcomingVaccines,
            subsidies: [],
            hasRecentRecord: hasToday,
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
        case .timeline:
            timelineLayout
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
                    chip(child.name, on: isSelected)
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

    private func chip(_ name: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Text("👶").font(.system(size: 14))
            Text(name).font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundStyle(on ? AppColors.ink : AppColors.ink2)
        .padding(.horizontal, 12).frame(height: 34)
        .frame(maxWidth: 130)
        .background(on ? AppColors.surface : AppColors.surface2, in: Capsule())
        .overlay { Capsule().stroke(on ? AppColors.primary.opacity(0.4) : AppColors.line, lineWidth: 1) }
        .accessibilityLabel("\(name) 선택\(on ? ", 현재 선택됨" : "")")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    // MARK: ═══════════════════════════════════
    // MARK: A — 히어로 레이아웃 (기본)
    // MARK: ═══════════════════════════════════
    private var heroLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            heroCard
            priorityCard
            nudgeCard
            peerCard
            if memoryEntry != nil { memoryCard }
        }
    }

    /// 1년 전 오늘(±3일)의 다이어리 기록 — 있으면 추억 카드 노출
    private var memoryEntry: DiaryEntry? {
        guard let cid = selectedChild?.id else { return nil }
        let cal = Calendar.current
        guard let target = cal.date(byAdding: .year, value: -1, to: Date()) else { return nil }
        let targetDay = cal.startOfDay(for: target)
        return store.diaryEntries(for: cid).first { entry in
            let d = cal.dateComponents([.day], from: cal.startOfDay(for: entry.date), to: targetDay).day ?? 99
            return abs(d) <= 3
        }
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
                        Text("아이를 등록하면 성장 기록이 시작돼요")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(16)
            }
            .blShadow(.card)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessLabel)
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
                HStack(spacing: 10) {
                    LiquidButton(fill: AppColors.gold, action: { onNavigate(.record) }) { Text("접종 확인하기") }
                    Button { onNavigate(.record) } label: {
                        Image(systemName: "bell.fill").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                            .frame(width: 52, height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(LiquidPressStyle())
                    .accessibilityLabel("접종 일정 보기")
                    .fixedSize()
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
            Button { onNavigate(.record) } label: {
                Text("기록").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 18).frame(height: 44)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(LiquidPressStyle())
            .accessibilityLabel("기록하기")
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
        HStack(spacing: 0) {
            PhotoPlaceholder(seed: 3, cornerRadius: 0)
                .frame(width: 100)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("1년 전 오늘: \(memoryEntry?.content ?? memoryEntry?.milestone ?? "소중한 순간")")
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

    // MARK: ═══════════════════════════════════
    // MARK: C — 타임라인 레이아웃 (인라인 리스트)
    // MARK: ═══════════════════════════════════
    private var timelineLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            // compact 헤더 재사용
            dashboardChildHeader
            // 우선순위 카드 compact — PriorityEngine 연결 유지
            priorityCardCompact
            // 또래 이야기
            peerCard
            // 최근 기록 섹션 — 선택 아이의 실 기록
            BLSectionHead(title: "최근 기록", action: "전체", onAction: { onNavigate(.record) })
            if recentHomeRecords.isEmpty {
                BLEmptyState(
                    icon: "camera.fill",
                    title: "첫 순간을 담아볼까요?",
                    message: "사진이 여기 차곡차곡 쌓일 거예요."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(recentHomeRecords.enumerated()), id: \.element.id) { idx, item in
                        timelineRecord(seed: idx + 1, badge: item.badge, caption: item.caption,
                                       day: relativeDay(item.date), tone: item.tone, icon: item.icon,
                                       photoRef: item.photoRef)
                    }
                }
            }
        }
    }

    private func timelineRecord(
        seed: Int,
        badge: String?,
        caption: String,
        day: String,
        tone: BadgeTone,
        icon: String?,
        photoRef: String? = nil
    ) -> some View {
        Button { onNavigate(.record) } label: {
            HStack(spacing: 12) {
                Group {
                    if let photo = PhotoStore.image(photoRef) {
                        Image(uiImage: photo)
                            .resizable().scaledToFill()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    } else if let icon {
                        HomeIconBadge(symbol: icon, tint: tone.ink, size: 54)
                    } else {
                        PhotoPlaceholder(seed: seed, cornerRadius: 11)
                            .frame(width: 54, height: 54)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    if let badge {
                        BLBadge(tone: tone, text: badge)
                    }
                    Text(caption)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(day)
                        .font(AppFont.micro)
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .accessibilityLabel("\(day): \(caption)\(badge != nil ? ", \(badge!)" : "")")
    }
}

// MARK: - 기록
struct RecordTab: View {
    var body: some View {
        TabScaffold(title: "기록", sub: "아이 타임라인") {
            HStack(spacing: 8) {
                ForEach(["타임라인", "성장차트", "예방접종"], id: \.self) { s in
                    Text(s).font(.system(size: 14, weight: .bold))
                        .foregroundStyle(s == "타임라인" ? .white : AppColors.ink2)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(s == "타임라인" ? AppColors.ink : AppColors.surface,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .blShadow(s == "타임라인" ? .chip : .chip)
                }
            }
            BLCard {
                VStack(alignment: .leading, spacing: 8) {
                    BLBadge(tone: .amber, text: "첫 걸음마", systemIcon: "figure.walk")
                    Text("임신부터 성장까지 끊김 없는 타임라인").font(AppFont.body).foregroundStyle(AppColors.ink2)
                }
            }
        }
    }
}

// MARK: - 동네 (주변/마켓/크루 세그먼트)
struct DongneTab: View {
    @State private var seg = 0
    @State private var showEmergency = false
    @ObservedObject private var location = NearbyLocationProvider.shared
    private let segs = ["주변", "마켓", "크루"]
    private let segIcons = ["mappin.and.ellipse", "tag.fill", "person.3.fill"]

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("내 주변 · 위치 기반")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.ink3)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("동네").font(.system(size: 28, weight: .heavy)).tracking(-0.4).foregroundStyle(AppColors.ink)
                            // 현재 행정동(동/읍/면/리) — 역지오코딩 결과
                            if let loc = location.localityName {
                                HStack(spacing: 4) {
                                    LocationPinIcon(color: MotionIconPalette.green, size: 17)
                                    Text(loc)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundStyle(AppColors.ink2)
                                        .lineLimit(1)
                                }
                                .accessibilityLabel("현재 위치 \(loc)")
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
                    ForEach(segs.indices, id: \.self) { i in
                        Button {
                            guard seg != i else { return }
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.18)) { seg = i }
                        } label: {
                            HStack(spacing: 5) {
                                let segGlyphs: [NavGlyph] = [.nearby, .market, .crew]
                                NavLineIcon(glyph: segGlyphs[i],
                                            color: seg == i ? Color.white : NavPalette.inactive,
                                            size: 18, bold: seg == i)
                                Text(segs[i]).font(.system(size: 14.5, weight: .bold))
                            }
                            .foregroundStyle(seg == i ? .white : AppColors.ink2)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background {
                                if seg == i {
                                    Capsule().fill(AppColors.ink).blShadow(.chip)
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

                switch seg {
                case 0:
                    NearbyScreen()
                case 1:
                    MarketScreen()
                default:
                    CrewScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppColors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { location.start() }   // 위치 라벨이 세그먼트와 무관하게 채워지도록
            .fullScreenCover(isPresented: $showEmergency) {
                EmergencyScreen(onClose: { showEmergency = false })
            }
        }
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
