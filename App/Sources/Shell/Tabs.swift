import SwiftUI

// MARK: - 홈 (오늘의 한 장면) — 스크린샷 01-home 재현
struct HomeTab: View {

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                header
                childChips
                heroCard
                priorityCard
                nudgeCard
                Color.clear.frame(height: 96)
            }
            .padding(Spacing.s5)
        }
        .background(AppColors.canvas)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("좋은 오후예요 🌤").font(AppFont.caption).foregroundStyle(AppColors.ink3)
                Text("우리 동네 육아").font(.system(size: 24, weight: .heavy)).tracking(-0.5)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Button {} label: {
                Label("응급", systemImage: "cross.case.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(AppColors.danger, in: Capsule())
            }
            .buttonStyle(LiquidPressStyle())
        }
    }

    private var childChips: some View {
        HStack(spacing: 8) {
            chip("지호", on: true)
            chip("하늘", on: false)
            Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.ink3)
                .frame(width: 34, height: 34)
                .background(AppColors.surface, in: Circle())
                .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
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
    }

    private var heroCard: some View {
        PhotoPlaceholder(seed: 1, cornerRadius: Radius.lg)
            .frame(height: 150)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("지호").font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                        Text("D+491 · 16개월")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).frame(height: 22)
                            .background(.black.opacity(0.22), in: Capsule())
                    }
                    Text("드디어 혼자 세 걸음! 너무 대견해 😊")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.95))
                }
                .padding(16)
            }
            .blShadow(.card)
    }

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
                    LiquidButton(fill: AppColors.gold, action: {}) { Text("접종 예약하기") }
                    Button {} label: {
                        Image(systemName: "bell.fill").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColors.gold)
                            .frame(width: 52, height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(LiquidPressStyle())
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

    private var nudgeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.fill").font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("지호의 오늘이 궁금해요").font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("사진 한 장이면 기록 끝 — 2탭이면 돼요").font(AppFont.caption).foregroundStyle(AppColors.ink2)
            }
            Spacer()
            Button {} label: {
                Text("기록").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 38)
                    .background(AppColors.primary, in: Capsule())
            }
            .buttonStyle(LiquidPressStyle())
        }
        .padding(14)
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
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
                        Button { withAnimation(.easeOut(duration: 0.15)) { seg = i } } label: {
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
