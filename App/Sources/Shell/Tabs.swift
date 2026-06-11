import SwiftUI
import UIKit

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

    var icon: String {
        switch self {
        case .hero:      return "photo.fill"
        case .dashboard: return "square.grid.2x2.fill"
        case .timeline:  return "list.bullet.rectangle.portrait.fill"
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
    @State private var editingChild: Child? = nil

    // MARK: 선택 아이 상태 — nil이면 children.first를 사용
    @State private var selectedChildId: UUID? = nil

    /// 현재 선택된 아이. selectedChildId가 없으면 첫 번째 아이.
    private var selectedChild: Child? {
        if let id = selectedChildId {
            return store.children.first(where: { $0.id == id })
        }
        return store.children.first
    }

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
    /// 선택 아이의 가장 최근 사진 (감정 진입점 — 홈 히어로)
    private var heroPhoto: UIImage? {
        guard let id = selectedChild?.id else { return nil }
        let withPhoto = store.diaryEntries(for: id).first { $0.photoRef != nil }
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

    // MARK: Priority Engine — 목업 입력 (PriorityEngine 연결)
    /// scheduledDate가 오늘로부터 4일 뒤인 미완료 VaccineRecord 1건
    private static let mockVaccines: [VaccineRecord] = {
        let fourDaysLater = Calendar.current.date(byAdding: .day, value: 4, to: Date()) ?? Date()
        return [
            VaccineRecord(
                id: UUID(),
                childId: UUID(),
                vaccineId: "DTaP 4차",
                scheduledDate: fourDaysLater,
                completedDate: nil,
                hospital: "행복소아과"
            )
        ]
    }()

    private var priorityItem: PriorityItem? {
        PriorityEngine.topPriority(
            vaccines: Self.mockVaccines,
            subsidies: [],
            hasRecentRecord: false,
            now: Date()
        )
    }

    // MARK: 레이아웃 상태 — AppStorage로 앱 재시작 후에도 보존
    @AppStorage("home_layout") private var layoutRaw: String = HomeLayout.hero.rawValue

    private var currentLayout: HomeLayout {
        HomeLayout(rawValue: layoutRaw) ?? .hero
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                header
                childChips
                layoutContent
                Color.clear.frame(height: 96)
            }
            .padding(Spacing.s5)
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
                Text("좋은 오후예요 🌤").font(AppFont.caption).foregroundStyle(AppColors.ink3)
                Text("우리 동네 육아").font(.system(size: 24, weight: .heavy)).tracking(-0.5)
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

    // MARK: 레이아웃 전환 메뉴
    private var layoutMenu: some View {
        Menu {
            ForEach(HomeLayout.allCases, id: \.rawValue) { layout in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        layoutRaw = layout.rawValue
                    }
                } label: {
                    Label(layout.label, systemImage: layout.icon)
                }
                .accessibilityLabel("레이아웃 \(layout.label)으로 전환")
            }
        } label: {
            Image(systemName: currentLayout.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 44, height: 44)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                }
                .blShadow(.chip)
        }
        .accessibilityLabel("홈 레이아웃 변경. 현재: \(currentLayout.label)")
    }

    // MARK: - 다자녀 칩
    private var childChips: some View {
        HStack(spacing: 8) {
            ForEach(store.children) { child in
                let isSelected = child.id == (selectedChild?.id)
                chip(child.name, on: isSelected)
                    .onTapGesture {
                        if child.id == selectedChild?.id {
                            editingChild = child   // 이미 선택된 아이 다시 탭 → 정보 수정
                        } else {
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.15)) {
                                selectedChildId = child.id
                            }
                        }
                    }
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
            }
            .buttonStyle(LiquidPressStyle(scale: 0.92))
            .accessibilityLabel("아이 추가")
        }
    }

    private func chip(_ name: String, on: Bool) -> some View {
        HStack(spacing: 6) {
            Text("👶").font(.system(size: 14))
            Text(name).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(on ? AppColors.ink : AppColors.ink2)
        .padding(.horizontal, 12).frame(height: 34)
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
            .frame(height: 188)
            .frame(maxWidth: .infinity)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: UnitPoint(x: 0.5, y: 0.4),
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

    // MARK: - 우선순위 카드 (PriorityEngine 연결 — A·B·C 공용)
    @ViewBuilder
    private var priorityCard: some View {
        if let item = priorityItem {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
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
                Text("기록").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 38)
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

    // MARK: 또래 이야기 카드
    private var peerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("오늘의 또래 이야기", systemImage: "sparkles")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(Color(hex: 0x5B53B0))
            Text("16개월 아이는 이 시기에 한 단어 어휘가 폭발적으로 늘어나요. '맘마', '아빠' 외에 새 단어를 시도한다면 대화로 격려해주세요.")
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(AppColors.ink)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0xEDEBFB), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .blShadow(.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("또래 이야기: 16개월 아이는 이 시기에 한 단어 어휘가 폭발적으로 늘어나요")
    }

    // MARK: 1년 전 오늘 카드
    private var memoryCard: some View {
        HStack(spacing: 0) {
            PhotoPlaceholder(seed: 3, cornerRadius: 0)
                .frame(width: 100)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                BLBadge(tone: .pink, text: "1년 전 오늘", systemIcon: "clock")
                Text(memoryEntry?.content ?? memoryEntry?.milestone ?? "소중한 순간을 남긴 날 🥰")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .lineSpacing(2)
                    .lineLimit(2)
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
                columns: [GridItem(.flexible(), spacing: Spacing.s3), GridItem(.flexible(), spacing: Spacing.s3)],
                spacing: Spacing.s3
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
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(childName).font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
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
            action: { onNavigate(.record) }
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
            action: { onNavigate(.record) }
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
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                    Spacer()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("기록하기").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                    Text("오늘 순간 남기기").font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
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
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(iconColor)
                    Spacer()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AppFont.num(15, weight: .heavy)).foregroundStyle(AppColors.ink)
                    Text(sub).font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
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
                    title: "아직 기록이 없어요",
                    message: "오른쪽 아래 버튼으로 오늘의 순간을 남겨보세요."
                )
            } else {
                VStack(spacing: 10) {
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
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(tone.bg)
                                .frame(width: 54, height: 54)
                            Image(systemName: icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(tone.ink)
                        }
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
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
    private let segs = ["주변", "마켓", "크루"]

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("동네").font(.system(size: 24, weight: .heavy)).foregroundStyle(AppColors.ink)
                        Label("서울 마포구 망원동", systemImage: "mappin")
                            .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                    }
                    Spacer()
                    Button { showEmergency = true } label: {
                        Label("응급", systemImage: "cross.case.fill")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 14).frame(height: 38)
                            .background(AppColors.danger, in: Capsule())
                    }
                    .buttonStyle(LiquidPressStyle())
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)

                HStack(spacing: 4) {
                    ForEach(segs.indices, id: \.self) { i in
                        Button {
                            guard seg != i else { return }
                            Haptics.selection()
                            withAnimation(.easeOut(duration: 0.15)) { seg = i }
                        } label: {
                            Text(segs[i]).font(.system(size: 14, weight: .bold))
                                .foregroundStyle(seg == i ? .white : AppColors.ink2)
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(seg == i ? AppColors.ink : AppColors.surface,
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.97))
                    }
                }
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
