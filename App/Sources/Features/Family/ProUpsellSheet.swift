// ProUpsellSheet.swift
// BabyLog — 프리 사용자가 가족 공유(좋아요·댓글) 등 Pro 기능을 탭했을 때 뜨는 안내 팝업.
// 정직한 결제(CLAUDE.md): 자동결제 고지 톤·해지 용이·무료 데이터 영구 보존 명시. 다크패턴 없음.
// ⚠️ '시작하기' CTA는 현재 개발용으로 isPro를 켠다 — 출시 시 StoreKit 2 구독 구매로 대체.

import SwiftUI

struct ProUpsellSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var comingSoon = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.s5) {
                // 헤더
                VStack(spacing: Spacing.s3) {
                    ZStack {
                        Circle().fill(AppColors.primarySoft).frame(width: 72, height: 72)
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(AppColors.primary)
                    }
                    .accessibilityHidden(true)
                    Text("가족과 함께, Pro")
                        .font(.system(size: 22, weight: .heavy)).foregroundStyle(AppColors.ink)
                    Text("조부모님도 아이의 순간을 함께 보고,\n하트와 댓글로 마음을 나눠요.")
                        .font(.system(size: 14)).foregroundStyle(AppColors.ink2)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Spacing.s4)

                // 혜택
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    benefit("photo.on.rectangle.angled", "가족 보관함",
                            "기록하면 가족 모두가 보는 피드에 자동 공유")
                    benefit("heart.fill", "하트 · 댓글",
                            "조부모님이 사진에 반응하고 함께 이야기해요")
                    benefit("person.2.badge.plus", "조부모님 초대",
                            "아이폰·안드로이드 어느 쪽이든 함께 봐요")
                    benefit("icloud.and.arrow.up", "풀화질 백업",
                            "원본 화질로 서버에 안전하게 보관")
                }
                .padding(Spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

                // 가격 + 정직 고지(자동 갱신·해지 경로 명시 — App Store 요건 + 정직한 결제 원칙)
                VStack(spacing: 4) {
                    (Text("월 ").font(.system(size: 16, weight: .semibold))
                     + Text("990원").font(.system(size: 22, weight: .heavy)))
                        .foregroundStyle(AppColors.ink)
                    Text("매월 자동 갱신 · 해지 전까지 청구돼요. 해지는 설정 > Apple 계정 > 구독에서 한 번에 가능해요. 무료 데이터는 영구 보존돼요.")
                        .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }

                // CTA
                VStack(spacing: Spacing.s2) {
                    Button {
                        #if DEBUG
                        // 개발용 — 출시 시 StoreKit 2 구매로 대체.
                        store.isPro = true
                        Haptics.success()
                        dismiss()
                        #else
                        // StoreKit 구매 미연결 — 결제 없이 잠금 해제하지 않는다(정직한 결제).
                        comingSoon = true
                        #endif
                    } label: {
                        Text("Pro 시작하기")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }.buttonStyle(LiquidPressStyle(scale: 0.98))
                    Button("나중에") { dismiss() }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink3)
                        .frame(height: 36)
                }
                .padding(.top, Spacing.s2)
            }
            .padding(.horizontal, Spacing.s5).padding(.bottom, Spacing.s6)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .alert("구독 준비 중이에요", isPresented: $comingSoon) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("결제 연동을 준비하고 있어요. 곧 가족 보관함을 만나보실 수 있어요.")
        }
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
