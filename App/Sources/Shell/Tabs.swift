import SwiftUI

// MARK: - 홈 (오늘의 한 장면) — 스크린샷 01-home 재현
struct HomeTab: View {
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

    private var priorityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("지금 가장 중요해요", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .bold)).foregroundStyle(AppColors.gold)
                    Text("DTaP 4차 접종").font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.ink)
                    Text("지호 · 행복소아과 · 예약 권장").font(AppFont.caption).foregroundStyle(AppColors.ink2)
                }
                Spacer()
                Text("D-4").font(.system(size: 22, weight: .heavy)).foregroundStyle(AppColors.gold)
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
                default:
                    ScrollView {
                        BLCard {
                            VStack(alignment: .leading, spacing: 8) {
                                BLBadge(tone: seg == 1 ? .amber : .blue, text: "준비중")
                                Text(seg == 1 ? "중고 마켓" : "동네 크루")
                                    .font(AppFont.title).foregroundStyle(AppColors.ink)
                                Text(seg == 1 ? "졸업템을 자연스럽게 — v2에서 열려요"
                                              : "비슷한 또래 양육자 매칭 — v3에서 열려요")
                                    .font(AppFont.caption).foregroundStyle(AppColors.ink2)
                            }
                        }
                        .padding(Spacing.s5)
                        Color.clear.frame(height: 96)
                    }
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
    var body: some View {
        TabScaffold(title: "가계부", sub: "지출 · 정부지원금") {
            BLCard {
                VStack(alignment: .leading, spacing: 8) {
                    BLBadge(tone: .coral, text: "D-4", systemIcon: "calendar")
                    Text("아동수당 신청 마감").font(AppFont.title).foregroundStyle(AppColors.ink)
                    Text("월 10만원 · 복지로에서 신청").font(AppFont.caption).foregroundStyle(AppColors.ink2)
                    LiquidButton(action: {}) { Text("신청 방법 보기") }
                }
            }
        }
    }
}

// MARK: - 내정보
struct ProfileTab: View {
    var body: some View {
        TabScaffold(title: "내정보", sub: "프로필 · 뱃지 · 설정") {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack(spacing: 12) {
                    Circle().fill(AppColors.primarySoft).frame(width: 56, height: 56)
                        .overlay { Image(systemName: "person.fill").foregroundStyle(AppColors.primary) }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("김지수").font(AppFont.h2).foregroundStyle(AppColors.ink)
                        BLBadge(tone: .amber, text: "골든 맘", systemIcon: "crown.fill")
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    BLBadge(tone: .purple, text: "안심 거래왕")
                    BLBadge(tone: .mint, text: "나눔 천사")
                    BLBadge(tone: .blue, text: "육아고수")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(cornerRadius: Radius.lg)   // iOS 26 네이티브 Liquid Glass 데모

            BLCard {
                VStack(alignment: .leading, spacing: 6) {
                    Label("데이터 비매각 · 무광고 · 영구 보존", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.primary)
                    Text("사진은 서버에 올리지 않아요. 언제든 내보낼 수 있어요.")
                        .font(AppFont.caption).foregroundStyle(AppColors.ink2)
                }
            }
        }
    }
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
