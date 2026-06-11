import SwiftUI
import UIKit

// MARK: - ProfileScreen

/// 내 정보 탭 루트 화면 (SPEC 기능 7 / design/handoff profile.jsx).
/// ProfileTab 연결은 팀장 담당 — 이 파일은 독립 View만 제공.
struct ProfileScreen: View {

    // MARK: Environment
    @EnvironmentObject private var store: AppStore

    // MARK: Mock State (실제 구현 시 ViewModel / Environment 주입)
    @State private var selectedBadgeCategory: BadgeCatalogItem.BadgeCategory? = nil
    @State private var showProDetail = false
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showSettings = false
    @State private var infoAlert: String? = nil

    // 성별 중립 닉네임 (설정에서 변경 — 맘/파파/양육자)
    @AppStorage("bl_nickname") private var nickname = "양육자님"
    // 닉네임 옆에 장착한 뱃지 (TickLab 스타일)
    @AppStorage("bl_equipped_badge") private var equippedBadgeId = ""
    @State private var detailBadge: BadgeCatalogItem? = nil

    /// 선택 아이 기준 나이 텍스트 (실데이터)
    private var childAgeText: String {
        guard let c = store.selectedChild else { return "아이를 등록해보세요" }
        let m = AgeCalculator.childAgeMonths(birthDate: c.birthDate, asOf: Date()).months
        return "\(c.name) · \(m)개월"
    }

    // 중고 마켓·크루는 백엔드(Supabase) 연동 전이므로 로컬 기준 0 (정직한 신규 상태)
    private let tradeCount   = 0
    private let avgRating    = 0.0
    private let joinedMonths = 0
    private let crewCount    = 0

    // MARK: 실 로컬 활동치 (기록 기반)
    /// 전체 기록 수 (다이어리 + 성장)
    private var totalRecordCount: Int { store.diaryEntries.count + store.growthRecords.count }
    /// 연속 기록일 (오늘 또는 어제까지 이어진 다이어리 streak)
    private var streakDays: Int {
        ProfileStreak.currentStreak(diaryDates: store.diaryEntries.map(\.date))
    }
    /// 획득 뱃지 수
    private var earnedBadgeCount: Int { displayCatalog.filter(\.isEarned).count }

    private var currentTier: Tier {
        TierCalculator.tier(tradeCount: tradeCount, avgRating: avgRating, joinedMonths: joinedMonths)
    }

    private var badgeProgress: Double {
        TierCalculator.progress(tradeCount: tradeCount, currentTier: currentTier)
    }

    private var tradesNeeded: Int {
        TierCalculator.tradesNeededForNext(currentTier: currentTier, tradeCount: tradeCount)
    }

    /// 카탈로그 항목의 isEarned를 store 획득 집합(엔진+마일스톤 단일 소스)으로 덮어쓴 배열.
    private var resolvedCatalog: [BadgeCatalogItem] {
        let earned = store.currentEarnedBadgeIds
        return BadgeCatalogItem.sampleCatalog.map { item in
            var copy = item
            copy.isEarned = earned.contains(item.id)
            return copy
        }
    }

    private func tierRank(_ t: Tier) -> Int { Tier.allCases.firstIndex(of: t) ?? 0 }
    private func tierReached(_ t: Tier) -> Bool { tierRank(currentTier) >= tierRank(t) }
    private func tierCondition(_ t: Tier) -> String {
        switch t {
        case .sprout:       return "가입하면 시작"
        case .warmNeighbor: return "거래 3회 이상"
        case .trusted:      return "거래 10회 이상"
        case .golden:       return "거래 30회+ · 평점 4.5+"
        }
    }

    /// 등급 뱃지 4종 — 다른 뱃지와 동일하게 조건 + 획득/잠금
    private var tierBadges: [BadgeCatalogItem] {
        Tier.allCases.map { t in
            BadgeCatalogItem(id: "tier_\(t.rawValue)", name: t.displayName,
                             condition: tierCondition(t), tone: t.badgeTone,
                             systemIcon: t.systemIcon, category: .tier,
                             isEarned: tierReached(t))
        }
    }

    /// 컬렉션 표시용 전체 목록 (등급 + 수집 뱃지)
    private var displayCatalog: [BadgeCatalogItem] { tierBadges + resolvedCatalog }

    /// 닉네임 옆에 장착된 뱃지 — 기본값은 현재 등급. 장착한(획득) 뱃지가 있으면 그것.
    private var equippedBadge: BadgeCatalogItem {
        if let found = displayCatalog.first(where: { $0.id == equippedBadgeId && $0.isEarned }) {
            return found
        }
        return tierBadges.first { $0.id == "tier_\(currentTier.rawValue)" } ?? tierBadges[0]
    }

    private var filteredBadges: [BadgeCatalogItem] {
        guard let cat = selectedBadgeCategory else { return displayCatalog }
        return displayCatalog.filter { $0.category == cat }
    }

    private let badgeCategories: [BadgeCatalogItem.BadgeCategory?] =
        [nil, .tier, .milestone, .record, .trade, .community, .special]

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BLScreenHeader(title: "내 정보") {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                            .frame(width: 44, height: 44)
                            .background(AppColors.surface, in: Circle())
                            .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
                    }
                    .accessibilityLabel("설정")
                }
                VStack(spacing: Spacing.s4) {
                    profileCard
                    tierProgressCard
                    proUpsellCard
                    badgeCollectionSection
                    privacySection
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, Spacing.s8)
            }
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .overlay {
            if let badge = detailBadge {
                BadgeDetailOverlay(
                    badge: badge,
                    isEquipped: equippedBadgeId == badge.id,
                    onEquip: {
                        equippedBadgeId = (equippedBadgeId == badge.id) ? "" : badge.id
                        Haptics.success()
                    },
                    onClose: { detailBadge = nil }
                )
                .zIndex(10)
            }
        }
        .alert("Pro — 곧 만나요", isPresented: $showProDetail) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("서버 사진 백업·AI 캡션·무제한 카드 등 프리미엄 혜택을 준비 중이에요. 다음 업데이트에서 안내드릴게요.")
        }
        .alert("안내", isPresented: Binding(
            get: { infoAlert != nil },
            set: { if !$0 { infoAlert = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(infoAlert ?? "")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        // 설정 화면 — NavigationStack 외부일 경우를 대비해 .sheet 사용
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsScreen()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("닫기") { showSettings = false }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.ink2)
                        }
                    }
            }
            .environmentObject(store)
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: 0) {
                // 아바타 + 이름 + 티어
                HStack(spacing: Spacing.s4) {
                    avatarView
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: Spacing.s2) {
                            Text(nickname)
                                .font(AppFont.title)
                                .foregroundStyle(AppColors.ink)
                            // 닉네임 옆 단일 칩 — 기본 등급, 장착한 뱃지가 있으면 그것 (아이콘+이름)
                            BLBadge(tone: equippedBadge.tone, text: equippedBadge.name,
                                    systemIcon: equippedBadge.systemIcon, dot: false)
                                .accessibilityLabel("장착한 뱃지: \(equippedBadge.name)")
                        }
                        Text(childAgeText)
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink2)
                    }
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("프로필 편집")
                }

                // 보조 뱃지 줄 (최대 3개 — SPEC 7.4)
                auxiliaryBadges
                    .padding(.top, Spacing.s4)

                Divider()
                    .overlay(AppColors.line)
                    .padding(.top, Spacing.s4)

                // 통계 4분할
                statsRow
                    .padding(.top, Spacing.s4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("프로필 카드")
    }

    // 아바타 원형 (PhotoPlaceholder 재사용)
    private var avatarView: some View {
        ZStack {
            PhotoPlaceholder(seed: 3, cornerRadius: 999)
            Text("🧑")
                .font(.system(size: 28))
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    // 보조 뱃지 (획득한 것만 최대 3개) — BadgeEngine 결과 기준
    private var auxiliaryBadges: some View {
        let earned = resolvedCatalog.filter(\.isEarned).prefix(3)
        return HStack(spacing: Spacing.s2) {
            ForEach(earned) { badge in
                BLBadge(tone: badge.tone, text: badge.name, systemIcon: badge.systemIcon, dot: false)
                    .accessibilityLabel("획득 뱃지: \(badge.name)")
            }
        }
    }

    // 실 로컬 활동 4분할 (기록·뱃지·아이·연속)
    private var statsRow: some View {
        let stats: [(String, String)] = [
            (totalRecordCount.formatted(), "기록"),
            (earnedBadgeCount.formatted(), "뱃지"),
            (store.children.count.formatted(), "아이"),
            ("\(streakDays)일", "연속 기록"),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { idx, stat in
                VStack(spacing: 3) {
                    Text(stat.0)
                        .font(AppFont.num(17))
                        .foregroundStyle(AppColors.ink)
                    Text(stat.1)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stat.1) \(stat.0)")

                if idx < stats.count - 1 {
                    Divider()
                        .overlay(AppColors.line)
                        .frame(height: 32)
                }
            }
        }
    }

    // MARK: - Tier Progress Card

    private var tierProgressCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 헤더
                HStack {
                    if let nextTier = currentTier.next {
                        Text("\(nextTier.displayName)까지")
                            .font(AppFont.subhead)
                            .foregroundStyle(AppColors.ink)
                    } else {
                        Text("최상위 티어 달성!")
                            .font(AppFont.subhead)
                            .foregroundStyle(AppColors.gold)
                    }
                    Spacer()
                    Text("거래 \(tradeCount) / \(TierCalculator.tradeThresholdForNext(currentTier: currentTier))회")
                        .font(AppFont.num(12.5))
                        .foregroundStyle(AppColors.ink3)
                }

                // 진행바
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.surface3)
                            .frame(height: 10)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: currentTier == .golden
                                        ? [AppColors.gold, AppColors.gold]
                                        : [Color(hex: 0xE3B85C), Color(hex: 0xB0832E)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(10, geo.size.width * badgeProgress),
                                height: 10
                            )
                            .animation(.easeOut(duration: 0.6), value: badgeProgress)
                    }
                }
                .frame(height: 10)
                .accessibilityValue("진행률 \(Int(badgeProgress * 100))%")

                // 안내 문구
                if currentTier != .golden {
                    Text("\(tradesNeeded)회만 더 거래하면 \(currentTier.next?.displayName ?? "")로 승급해요")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                        .accessibilityLabel("다음 티어까지 거래 \(tradesNeeded)회 필요")
                } else {
                    Text("동네 최고 신뢰도 양육자로 인정받고 있어요")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.gold)
                }
            }
        }
        .accessibilityLabel("티어 진행 현황")
    }

    // MARK: - Pro Upsell Card

    private var proUpsellCard: some View {
        Button {
            showProDetail = true
        } label: {
            ZStack(alignment: .topTrailing) {
                // 배경 — 라이트 프리미엄(크림+골드)
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFBF3DF), Color(hex: 0xF5E8C8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                            .stroke(AppColors.gold.opacity(0.35), lineWidth: 1)
                    }

                // 장식 아이콘
                Image(systemName: "sparkles")
                    .font(.system(size: 90, weight: .thin))
                    .foregroundStyle(AppColors.gold.opacity(0.28))
                    .offset(x: 10, y: -10)
                    .accessibilityHidden(true)

                // 콘텐츠
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    BLBadge(tone: .amber, text: "BabyLog Pro", systemIcon: "crown.fill", dot: false)

                    Text("사진 무제한 · AI 일지 · 또래 비교")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppColors.ink)

                    // 기능 리스트
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        proFeatureRow(icon: "photo.stack.fill",  label: "사진 무제한 저장",    sub: "무료는 월 200장")
                        proFeatureRow(icon: "sparkle",           label: "AI 일지 캡션 초안",   sub: "사진 보고 자동으로 한 줄")
                        proFeatureRow(icon: "chart.bar.fill",    label: "또래 비교 분석",       sub: "안심 톤, 등수 없이")
                        proFeatureRow(icon: "bag.fill",          label: "매물 등록 무제한",     sub: "무료는 월 5건")
                    }

                    // 요금 비교
                    HStack(spacing: Spacing.s2) {
                        pricePill(label: "월간", price: "3,900원", highlighted: false)
                        pricePill(label: "연간", price: "29,000원", highlighted: true)
                    }

                    // 7일 무료 LiquidButton
                    LiquidButton(fill: AppColors.gold, cornerRadius: Radius.md) {
                        showProDetail = true
                    } label: {
                        HStack(spacing: Spacing.s2) {
                            Image(systemName: "crown.fill")
                                .accessibilityHidden(true)
                            Text("7일 무료로 시작하기")
                        }
                        .foregroundStyle(Color(hex: 0x1C1814))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                    }

                    Text("언제든 해지 가능 · 무료 기능은 계속 무료")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(Spacing.s5)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .accessibilityLabel("BabyLog Pro 업그레이드. 월 3,900원 또는 연 29,000원. 7일 무료 체험 가능.")
        .accessibilityAddTraits(.isButton)
    }

    private func proFeatureRow(icon: String, label: String, sub: String) -> some View {
        HStack(spacing: Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.gold)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(sub)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(sub)")
    }

    private func pricePill(label: String, price: String, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(price)
                .font(AppFont.num(18, weight: .bold))
                .foregroundStyle(AppColors.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s3)
        .background(
            highlighted
                ? AppColors.gold.opacity(0.22)
                : Color.white.opacity(0.55),
            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .stroke(
                    highlighted ? AppColors.gold : Color.white.opacity(0.12),
                    lineWidth: highlighted ? 1.5 : 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(price)")
    }

    // MARK: - Badge Collection Section

    private var badgeCollectionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            let earnedCount = displayCatalog.filter(\.isEarned).count
            let totalCount  = displayCatalog.count

            BLSectionHead(
                eyebrow: "컬렉션",
                title: "내 뱃지 \(earnedCount)/\(totalCount)",
                action: "전체",
                onAction: { selectedBadgeCategory = nil }
            )

            // 카테고리 필터 칩
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s2) {
                    ForEach(badgeCategories, id: \.?.rawValue) { cat in
                        BLChip(
                            text: cat?.rawValue ?? "전체",
                            on: selectedBadgeCategory == cat
                        ) {
                            selectedBadgeCategory = cat
                        }
                        .accessibilityLabel("\(cat?.rawValue ?? "전체") 카테고리 필터")
                        .accessibilityAddTraits(selectedBadgeCategory == cat ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }

            // 3열 그리드
            let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 3)
            LazyVGrid(columns: columns, spacing: Spacing.s2) {
                ForEach(filteredBadges) { badge in
                    BadgeTileView(badge: badge) { detailBadge = badge }
                }
            }
        }
    }

    // MARK: - Privacy Section

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            BLSectionHead(eyebrow: "BABYLOG 원칙", title: "데이터 · 프라이버시")

            BLCard(padding: 0) {
                VStack(spacing: 0) {
                    privacyRow(
                        icon: "person.3.fill",
                        iconBg: Color(hex: 0xE6F1FB),
                        iconFg: Color(hex: 0x3B6FA8),
                        title: "가족 공유",
                        subtitle: "파트너 · 조부모 · 최대 6명",
                        showDivider: true,
                        onTap: {
                            infoAlert = "가족 공유(파트너·조부모 최대 6명)는 곧 제공돼요. iCloud 동기화를 준비 중이에요."
                        }
                    )
                    privacyRow(
                        icon: "shield.fill",
                        iconBg: AppColors.primarySoft,
                        iconFg: AppColors.primary,
                        title: "데이터는 절대 판매하지 않아요",
                        subtitle: "아동 데이터 비매각 — 약속",
                        showDivider: true,
                        onTap: {
                            infoAlert = "BabyLog는 아동 데이터를 절대 외부에 판매하지 않아요. 수익은 구독과 거래 수수료로만 운영하며, 무료 사용자의 데이터도 영구 보존합니다."
                        }
                    )
                    privacyRow(
                        icon: "square.and.arrow.up.fill",
                        iconBg: Color(hex: 0xEEEDFE),
                        iconFg: Color(hex: 0x5B53B0),
                        title: "내 데이터 내보내기",
                        subtitle: "표준 포맷으로 언제든",
                        showDivider: true,
                        onTap: {
                            let state = store.snapshot()
                            if let url = try? DataExporter.exportToTemporaryFile(state) {
                                exportURL = url
                                showShareSheet = true
                            }
                        }
                    )
                    privacyRow(
                        icon: "heart.fill",
                        iconBg: Color(hex: 0xFBEAF0),
                        iconFg: Color(hex: 0xB5478A),
                        title: "양육자 역할 설정",
                        subtitle: "맘 · 파파 · 양육자 중립 — 선택",
                        showDivider: false,
                        onTap: { showSettings = true }
                    )
                }
            }

            // 절대 원칙 고지 (CLAUDE.md — 무광고·데이터 비매각·영구 보존)
            Text("BabyLog는 광고가 없어요. 데이터를 팔지 않고,\n무료 데이터도 영원히 보존합니다.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.s2)
                .accessibilityLabel("BabyLog는 광고 없이, 데이터 비매각, 무료 데이터 영구 보존을 약속합니다.")
        }
    }

    private func privacyRow(
        icon: String,
        iconBg: Color,
        iconFg: Color,
        title: String,
        subtitle: String,
        showDivider: Bool,
        onTap: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.s3) {
                // 아이콘 컨테이너 (44pt — 접근성 최소 탭 영역)
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(iconBg)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(iconFg)
                }
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.s4)
            .frame(minHeight: 64) // 44pt 이상 탭 영역 확보
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            if showDivider {
                Divider()
                    .overlay(AppColors.line)
                    .padding(.leading, 66)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - BadgeTileView

/// 뱃지 그리드 셀 — 획득=컬러, 미획득=잠금·흐림 (SPEC 7.6 수집 욕구 자극)
private struct BadgeTileView: View {
    let badge: BadgeCatalogItem
    var onTap: () -> Void = {}
    @State private var tapped = false

    var body: some View {
        Button {
            Haptics.selection()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { tapped = false }
            onTap()
        } label: {
            VStack(spacing: Spacing.s2) {
                // 아이콘 원
                ZStack {
                    Circle()
                        .fill(badge.isEarned ? Color.white : AppColors.surface3)
                        .frame(width: 44, height: 44)
                    if badge.isEarned {
                        Image(systemName: badge.systemIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(badge.tone.ink)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.ink3)
                    }
                }

                // 뱃지명 (색+아이콘+레이블 3중 인코딩)
                Text(badge.name)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(badge.isEarned ? badge.tone.ink : AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // 조건 설명
                Text(badge.condition)
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, Spacing.s4)
            .padding(.horizontal, Spacing.s2)
            .frame(maxWidth: .infinity)
            .background(badge.isEarned ? badge.tone.bg : AppColors.surface2)
            .overlay {
                if !badge.isEarned {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(AppColors.line2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .badgeShine(badge.isEarned)   // 뱃지 광택 (§8.4)
            .grayscale(badge.isEarned ? 0 : 1)
            .opacity(badge.isEarned ? 1.0 : 0.55)   // 미획득: 흑백+흐림으로 잠금 상태 명확화
            .scaleEffect(tapped ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            badge.isEarned
                ? "획득한 뱃지: \(badge.name). \(badge.condition)"
                : "미획득 뱃지: \(badge.name). 조건: \(badge.condition)"
        )
        .accessibilityAddTraits(badge.isEarned ? [] : .isStaticText)
    }
}

// MARK: - BadgeDetailOverlay (TickLab 스타일 — 회전+확대 등장, 닉네임 장착)

private struct BadgeDetailOverlay: View {
    let badge: BadgeCatalogItem
    let isEquipped: Bool
    let onEquip: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            // 옅은 디밍 — 뒤 뱃지가 비치도록 (TickLab 스타일)
            Color.black.opacity(0.3).ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: Spacing.s5) {
                // 회전+확대 등장하는 큰 뱃지 카드 — 단순 반투명 틴트(블러 없음)라 뒤가 비친다
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill((badge.isEarned ? badge.tone.ink : AppColors.ink3).opacity(0.5))
                    Circle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 180, height: 180)
                    Image(systemName: badge.isEarned ? badge.systemIcon : "lock.fill")
                        .font(.system(size: 84, weight: .bold))
                        .foregroundStyle(.white)
                    VStack {
                        Spacer()
                        Text(badge.name)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.bottom, 28)
                    }
                }
                .frame(width: 250, height: 330)
                .scaleEffect(appeared ? 1 : 0.3)
                .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -200))

                VStack(spacing: Spacing.s2) {
                    Text(badge.name)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.white)
                    Text(badge.condition)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .shadow(color: .black.opacity(0.45), radius: 4, y: 1)

                // 장착 / 잠금 안내
                if badge.isEarned {
                    Button {
                        onEquip()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isEquipped ? "checkmark.seal.fill" : "seal")
                            Text(isEquipped ? "장착 해제" : "닉네임 옆에 장착")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isEquipped ? AppColors.ink : badge.tone.ink)
                        .padding(.horizontal, 22).frame(height: 50)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.96))
                } else {
                    Text("아직 잠겨 있어요 · \(badge.condition)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Button("닫기") { onClose() }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 24).frame(height: 44)
                    .overlay { Capsule().stroke(.white.opacity(0.4), lineWidth: 1.5) }
            }
            .padding(Spacing.s5)
        }
        .onAppear {
            if reduceMotion { appeared = true }
            else { withAnimation(.spring(response: 0.55, dampingFraction: 0.62)) { appeared = true } }
        }
        .accessibilityAddTraits(.isModal)
    }
}

// MARK: - ProfileStreak (연속 기록일 계산 — 순수 함수, QA 테스트 대상)

/// 다이어리 기록일 기반 연속 streak 계산.
/// 오늘 기록이 없어도 어제까지 이어졌다면 streak를 유지한다(죄책감 방지, DESIGN §8.5).
enum ProfileStreak {
    static func currentStreak(diaryDates: [Date],
                              calendar: Calendar = .current,
                              today: Date = Date()) -> Int {
        let days = Set(diaryDates.map { calendar.startOfDay(for: $0) })
        guard !days.isEmpty else { return 0 }

        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
            if !days.contains(cursor) { return 0 }
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}

// MARK: - ShareSheet

/// UIActivityViewController 래퍼 — 데이터 내보내기 공유 시트용
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        ProfileScreen()
    }
    .environmentObject(SampleData.store())
}
#endif
