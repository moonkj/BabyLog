// ProUpsellSheet.swift
// BabyLog — Pro 구독 안내·구매 시트. 가족 공유(좋아요·댓글)·마켓 다중판매 등 Pro 기능 진입점.
// 정직한 결제(CLAUDE.md): 자동결제 고지 톤·해지 용이·무료 데이터 영구 보존 명시. 다크패턴 없음.
// 실제 결제는 StoreManager(StoreKit 2). App Store Connect에 자동구독 상품 등록 시 가격이 실시간 반영된다.

import SwiftUI
import StoreKit

struct ProUpsellSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sk = StoreManager.shared
    @ObservedObject private var auth = AuthStore.shared
    @State private var notice: String?
    // 단일 시트 라우팅(로그인/개인정보처리방침) — 한 뷰에 .sheet 둘 이상이면 누락 위험.
    @State private var modal: Modal?
    private enum Modal: String, Identifiable { case login, privacy; var id: String { rawValue } }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s5) {
                header
                benefits
                pricing
                cta
            }
            .padding(.horizontal, Spacing.s5).padding(.bottom, Spacing.s6)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .task { if !sk.loaded { await sk.loadProducts() } }
        .onChange(of: store.isPro) { _, pro in if pro { Haptics.success(); dismiss() } }
        .sheet(item: $modal) { m in
            switch m {
            case .login:
                AppleLoginSheet(message: "구독은 로그인 후 이용할 수 있어요.") {}
            case .privacy:
                NavigationStack {
                    PrivacyPolicyScreen()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("닫기") { modal = nil }
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppColors.ink2)
                            }
                        }
                }
            }
        }
        .alert("구독", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(notice ?? "") }
    }

    // MARK: 헤더
    private var header: some View {
        VStack(spacing: Spacing.s3) {
            ZStack {
                Circle().fill(AppColors.primarySoft).frame(width: 72, height: 72)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 34, weight: .semibold)).foregroundStyle(AppColors.primary)
            }
            .accessibilityHidden(true)
            Text("가족과 함께, Pro")
                .font(.system(size: 22, weight: .heavy)).foregroundStyle(AppColors.ink)
            Text("조부모님과 가족이 아이의 순간을 함께 보고,\n하트와 댓글로 마음을 나눠요.")
                .font(.system(size: 14)).foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.s4)
    }

    // MARK: 혜택
    private var benefits: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            benefit("photo.on.rectangle.angled", "가족 보관함", "기록하면 가족 모두가 보는 피드에 자동 공유")
            benefit("heart.fill", "하트 · 댓글", "조부모님이 사진에 반응하고 함께 이야기해요")
            benefit("person.2.badge.plus", "조부모님과 가족 초대", "아이폰·안드로이드 어느 쪽이든 함께 봐요 (최대 8명)")
            benefit("rectangle.on.rectangle.angled", "성장 보드 여러 개", "테마별·시기별로 마음껏 — 아이당 최대 100개")
            benefit("icloud.and.arrow.up", "풀화질 백업", "원본 화질로 서버에 안전하게 보관")
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    // MARK: 가격(실시간 — 미등록/오프라인 시 안내 가격으로 폴백)
    private var pricing: some View {
        VStack(spacing: 5) {
            (Text("월 ").font(.system(size: 16, weight: .semibold))
             + Text(monthlyPriceText).font(.system(size: 22, weight: .heavy))).foregroundStyle(AppColors.ink)
            HStack(spacing: 6) {
                (Text("연 ").font(.system(size: 14, weight: .semibold))
                 + Text(yearlyPriceText).font(.system(size: 17, weight: .heavy))).foregroundStyle(AppColors.ink2)
                if let d = yearlyDiscountText {
                    Text(d)
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 8).frame(height: 22)
                        .background(AppColors.primary, in: Capsule())
                }
            }
            Text("자동 갱신, 해지 전까지 청구돼요. 해지는 설정 > Apple 계정 > 구독에서 한 번에 가능해요. 무료 데이터는 영구 보존돼요.")
                .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    // 월·연 표시 가격(상품 로드 시 실가격, 아니면 안내가).
    private var monthlyPriceText: String { sk.monthly?.displayPrice ?? "990원" }
    private var yearlyPriceText: String { sk.yearly?.displayPrice ?? "9,900원" }

    /// 연 구독 할인율 — 월×12 대비 연 가격. 상품 미로드 시 안내가(990×12 vs 9,900 ≈ 17%) 폴백.
    private var yearlyDiscountText: String? {
        guard let m = sk.monthly, let y = sk.yearly else { return "17% 할인" }
        let monthlyYear = m.price * 12
        guard monthlyYear > 0 else { return nil }
        let ratio = (monthlyYear - y.price) / monthlyYear
        let pct = NSDecimalNumber(decimal: ratio * 100).doubleValue
        guard pct >= 1 else { return nil }
        return "\(Int(pct.rounded()))% 할인"
    }

    // MARK: CTA
    private var cta: some View {
        VStack(spacing: Spacing.s2) {
            // 연 구독 우선(혜택 큼). 상품 미로드 시 비활성 + 안내.
            planButton(title: "연 구독으로 시작", subtitle: yearlySubtitle, product: sk.yearly, prominent: true)
            planButton(title: "월 구독으로 시작", subtitle: monthlySubtitle, product: sk.monthly, prominent: false)

            Button { Task { await sk.restore(); if !store.isPro { notice = sk.lastError ?? "복원할 구독이 없어요." } } } label: {
                Text("구매 복원").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(AppColors.ink2)
                    .frame(height: 36)
            }
            .disabled(sk.purchasing)

            // App Store 요건(3.1.2) — 자동구독 화면에 이용약관·개인정보처리방침 '탭 가능한' 링크.
            HStack(spacing: Spacing.s3) {
                Link("이용약관(EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·").foregroundStyle(AppColors.ink3)
                Button("개인정보처리방침") { modal = .privacy }
            }
            .font(.system(size: 11.5, weight: .semibold)).foregroundStyle(AppColors.ink3)

            Button("나중에") { dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink3).frame(height: 36)
        }
        .padding(.top, Spacing.s2)
    }

    private var yearlySubtitle: String {
        let base = "\(yearlyPriceText) / 년"
        if let d = yearlyDiscountText { return "\(base) · \(d)" }
        return base
    }
    private var monthlySubtitle: String { "\(monthlyPriceText) / 월" }

    @ViewBuilder
    private func planButton(title: String, subtitle: String, product: Product?, prominent: Bool) -> some View {
        Button {
            // 로그인 필수 — appAccountToken(uid) 바인딩이 있어야 서버가 구독을 인정한다.
            // 비로그인 구매는 서버 검증이 영구 실패하므로 먼저 로그인을 받는다.
            guard auth.userId != nil else { modal = .login; return }
            guard let product else { notice = "지금은 구독을 시작할 수 없어요. 잠시 후 다시 시도해 주세요."; return }
            Task {
                let ok = await sk.purchase(product)
                if !ok, let e = sk.lastError { notice = e }   // 취소는 lastError 없음 → 조용히
            }
        } label: {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 16, weight: .heavy))
                Text(subtitle).font(.system(size: 12, weight: .semibold)).opacity(0.9)
            }
            // 글씨는 검정(ink)으로 가독성 확보 — 연(추천)은 프라이머리 틴트, 월은 밝은 회색 배경.
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                prominent ? AnyShapeStyle(AppColors.primarySoft) : AnyShapeStyle(AppColors.surface2),
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke((prominent ? AppColors.primary : AppColors.ink).opacity(prominent ? 0.55 : 0.18),
                            lineWidth: prominent ? 1.8 : 1.2)
            }
            .blShadow(.chip)
            .overlay {
                if sk.purchasing { ProgressView().tint(AppColors.ink) }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
        .disabled(sk.purchasing)
        .opacity((product == nil && sk.loaded) ? 0.55 : 1)
    }

    private func benefit(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColors.primary)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text(desc).font(.system(size: 13)).foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
