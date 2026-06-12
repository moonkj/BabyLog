// OnboardingLoginSheet.swift
// BabyLog · 온보딩 "이미 계정이 있어요" → Apple 로그인 시트

import SwiftUI

struct OnboardingLoginSheet: View {
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var failed = false

    var body: some View {
        VStack(spacing: Spacing.s4) {
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            VStack(spacing: Spacing.s2) {
                Text("다시 오신 걸 환영해요")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                Text("Apple로 로그인하면 다른 기기에서도\n내 글·모임이 그대로 이어져요.")
                    .font(AppFont.subhead)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if failed {
                Text("로그인에 실패했어요. 잠시 후 다시 시도해 주세요.")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.danger)
            }

            Spacer(minLength: 0)

            AppleSignInButton { ok in
                if ok { dismiss(); onDone() } else { failed = true }
            }
            .padding(.horizontal, Spacing.s5)

            Button("나중에 할게요") { dismiss() }
                .font(AppFont.subhead)
                .foregroundStyle(AppColors.ink3)
                .frame(minHeight: 44)
                .padding(.bottom, Spacing.s4)
        }
        .padding(.horizontal, Spacing.s4)
        .background(AppColors.canvas.ignoresSafeArea())
    }
}
