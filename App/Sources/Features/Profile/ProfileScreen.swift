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

    // 샘플 프로필 데이터 (ViewModel 교체 전 하드코딩)
    private let tradeCount   = 18
    private let avgRating    = 4.8
    private let joinedMonths = 5
    private let crewCount    = 3
    private let responseRate = 91
    // 성별 중립 닉네임 (맘/파파는 설정에서 선택)
    private let nickname     = "지호님"
    private let childAge     = "16개월 아이"
    private let region       = "서울 마포구"

    // MARK: BadgeEngine — 목업 활동치
    /// BadgeEngine으로 획득 뱃지 Set 결정 (ViewModel 교체 전 목업 입력)
    private let mockRecordCount     = 5   // 기록 시작 조건 충족
    private let mockConsecutiveDays = 0   // streak_30 미충족
    private let mockTradeCount      = 18  // sharing_angel(3+) 충족, trade_50 미충족
    private let mockCrewMeetings    = 1   // first_crew 충족
    private let mockPostLikes       = 42  // info_master(500+) 미충족

    private var engineEarnedBadgeIds: Set<String> {
        BadgeEngine.earnedBadges(
            recordCount:     mockRecordCount,
            consecutiveDays: mockConsecutiveDays,
            tradeCount:      mockTradeCount,
            crewMeetings:    mockCrewMeetings,
            postLikes:       mockPostLikes
        )
    }

    private var currentTier: Tier {
        TierCalculator.tier(tradeCount: tradeCount, avgRating: avgRating, joinedMonths: joinedMonths)
    }

    private var badgeProgress: Double {
        TierCalculator.progress(tradeCount: tradeCount, currentTier: currentTier)
    }

    private var tradesNeeded: Int {
        TierCalculator.tradesNeededForNext(currentTier: currentTier, tradeCount: tradeCount)
    }

    /// 카탈로그 항목의 isEarned를 BadgeEngine 결과로 덮어쓴 배열을 반환합니다.
    private var resolvedCatalog: [BadgeCatalogItem] {
        let earned = engineEarnedBadgeIds
        return BadgeCatalogItem.sampleCatalog.map { item in
            var copy = item
            copy.isEarned = earned.contains(item.id)
            return copy
        }
    }

    private var filteredBadges: [BadgeCatalogItem] {
        guard let cat = selectedBadgeCategory else { return resolvedCatalog }
        return resolvedCatalog.filter { $0.category == cat }
    }

    private let badgeCategories: [BadgeCatalogItem.BadgeCategory?] =
        [nil, .trade, .record, .community, .special]

    // MARK: Body

    var body: some View {
        ScrollView {
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
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationTitle("내 정보")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // 설정 진입 (팀장 연결)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                }
                .frame(width: 44, height: 44)
                .accessibilityLabel("설정")
            }
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
                            tierBadge
                        }
                        Text("\(childAge) · \(region) · 가입 \(joinedMonths)개월")
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink2)
                    }
                    Spacer()
                    Button {
                        // 프로필 편집 (팀장 연결)
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

    // 티어 뱃지 (색 + 아이콘 + 레이블 3중)
    private var tierBadge: some View {
        BLBadge(
            tone: currentTier.badgeTone,
            text: currentTier.displayName,
            systemIcon: currentTier.systemIcon,
            dot: false
        )
        .accessibilityLabel("티어: \(currentTier.displayName)")
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

    // 거래·평점·크루·응답률 4분할
    private var statsRow: some View {
        let stats: [(String, String)] = [
            (tradeCount.formatted(), "거래"),
            (String(format: "%.1f", avgRating), "평점"),
            (crewCount.formatted(), "크루"),
            ("\(responseRate)%", "응답률"),
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
                // 배경 — 다크 카드
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x2A2520), Color(hex: 0x1C1814)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 장식 아이콘
                Image(systemName: "sparkles")
                    .font(.system(size: 90, weight: .thin))
                    .foregroundStyle(AppColors.gold.opacity(0.18))
                    .offset(x: 10, y: -10)
                    .accessibilityHidden(true)

                // 콘텐츠
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    BLBadge(tone: .amber, text: "BabyLog Pro", systemIcon: "crown.fill", dot: false)

                    Text("사진 무제한 · AI 일지 · 또래 비교")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.white)

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
                        // 구독 시작 (팀장 연결)
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
                    .foregroundStyle(Color.white)
                Text(sub)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(sub)")
    }

    private func pricePill(label: String, price: String, highlighted: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(price)
                .font(AppFont.num(18, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s3)
        .background(
            highlighted
                ? AppColors.gold.opacity(0.15)
                : Color.white.opacity(0.06),
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
            let earnedCount = resolvedCatalog.filter(\.isEarned).count
            let totalCount  = resolvedCatalog.count

            BLSectionHead(
                eyebrow: "COLLECTION",
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
                    BadgeTileView(badge: badge)
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
                        showDivider: true
                    )
                    privacyRow(
                        icon: "shield.fill",
                        iconBg: AppColors.primarySoft,
                        iconFg: AppColors.primary,
                        title: "데이터는 절대 판매하지 않아요",
                        subtitle: "아동 데이터 비매각 — 약속",
                        showDivider: true
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
                        showDivider: false
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
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
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
    @State private var tapped = false

    var body: some View {
        Button {
            guard badge.isEarned else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tapped = false }
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
            .opacity(badge.isEarned ? 1.0 : 0.65)
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
