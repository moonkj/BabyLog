// MkSellFlowSheet.swift
// BabyLog · Features/Dongne
// 마켓 판매 플로우 3단계 시트 — MarketItemDetail.swift에서 분리
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MkSellFlowSheet (판매 플로우 3단계)

struct MkSellFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var selectedGrade: MarketItemGrade = .a
    @State private var priceText: String = "95,000"
    @State private var showComplete = false

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule()
                .fill(AppColors.line2)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .accessibilityHidden(true)

            // 단계 인디케이터
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AppColors.ink : AppColors.line2)
                        .frame(width: i == step ? 24 : 8, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: step)
                }
            }
            .accessibilityLabel("단계 \(step + 1) / 3")
            .padding(.bottom, 20)

            if showComplete {
                sellCompleteView
            } else {
                switch step {
                case 0: sellStep0
                case 1: sellStep1
                default: sellStep2
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s5)
        .background(AppColors.canvas)
        .frame(maxHeight: .infinity)
    }

    // MARK: Step 0 — 사진 + AI 분류
    private var sellStep0: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("무엇을 정리할까요?")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            Text("사진을 올리면 AI가 자동 분류해드려요.")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(AppColors.ink2)

            // 사진 영역
            ZStack {
                PhotoPlaceholder(seed: 0, cornerRadius: 18)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("사진 추가 (최소 2장)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .accessibilityLabel("사진 추가 영역. 최소 2장")

            // AI 자동 인식 카드
            BLCard(padding: 13, flat: true) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI 자동 인식")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text("식사 의자 · 6개월+ 로 분류했어요")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AppColors.ink2)
                    }

                    Spacer(minLength: 0)

                    BLBadge(tone: .mint, text: "온디바이스", systemIcon: nil, dot: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.line, lineWidth: 1)
            }
            .accessibilityLabel("AI 자동 인식. 식사 의자 6개월+로 분류했어요. 온디바이스 처리.")

            LiquidButton(action: { withAnimation { step = 1 } }) {
                Text("다음")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("다음 단계로")
        }
    }

    // MARK: Step 1 — 등급 + 가격
    private var sellStep1: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("상태와 가격")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            // 등급 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("상태 등급")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AppColors.ink3)

                HStack(spacing: 8) {
                    ForEach(MarketItemGrade.allCases, id: \.self) { grade in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedGrade = grade
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(grade.rawValue)
                                    .font(.system(size: 17, weight: .heavy))
                                Text(grade.label)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(selectedGrade == grade ? Color.white : AppColors.ink2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                selectedGrade == grade ? AppColors.ink : AppColors.surface,
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(
                                        selectedGrade == grade ? AppColors.ink : AppColors.line,
                                        lineWidth: selectedGrade == grade ? 1.5 : 1
                                    )
                            }
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.95))
                        .accessibilityLabel("\(grade.rawValue)등급 \(grade.label)")
                        .accessibilityAddTraits(selectedGrade == grade ? [.isSelected] : [])
                    }
                }
            }

            // 가격 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("가격 · AI 시세 제안")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AppColors.ink3)

                HStack(alignment: .center, spacing: 10) {
                    Text(priceText)
                        .font(AppFont.num(22, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    Text("원")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppColors.ink2)

                    Spacer(minLength: 0)

                    BLBadge(tone: .mint, text: "비슷한 매물 평균", systemIcon: nil, dot: true)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.line, lineWidth: 1)
                }
                .accessibilityLabel("제안 가격 \(priceText)원. 비슷한 매물 평균 기준.")
            }

            LiquidButton(action: { withAnimation { step = 2 } }) {
                Text("다음")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("다음 단계로")
        }
    }

    // MARK: Step 2 — 등록 완료 보상
    private var sellStep2: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("마지막으로 확인해요")
                .font(.system(size: 19, weight: .heavy))
                .foregroundStyle(AppColors.ink)

            // 요약 카드
            BLCard(padding: 14, flat: true) {
                VStack(alignment: .leading, spacing: 8) {
                    SellSummaryRow(icon: "photo.on.rectangle", label: "사진", value: "2장 첨부됨")
                    SellSummaryRow(icon: selectedGrade.systemIcon, label: "등급", value: "\(selectedGrade.rawValue)등급 · \(selectedGrade.label)")
                    SellSummaryRow(icon: "wonsign.circle.fill", label: "가격", value: "\(priceText)원")
                    SellSummaryRow(icon: "sparkles", label: "AI 분류", value: "식사 의자 · 6개월+")
                }
            }
            .accessibilityElement(children: .contain)

            LiquidButton(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showComplete = true
                }
            }) {
                Text("등록하기")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("매물 등록하기")
        }
    }

    // MARK: 등록 완료 보상
    private var sellCompleteView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)

            ZStack {
                Circle()
                    .fill(AppColors.goldTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppColors.gold)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("매물이 등록됐어요!")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(AppColors.ink)

                Text("동네 이웃에게 알림이 가요.\n빠른 거래를 응원해요 :)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // 보상 뱃지
            BLCard(padding: 13, flat: true) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("첫 매물 등록 뱃지 획득!")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                        Text("따뜻한 이웃이 되어주셔서 감사해요.")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Color(hex: 0xA8813A))
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .accessibilityLabel("첫 매물 등록 뱃지 획득! 따뜻한 이웃이 되어주셔서 감사해요.")

            LiquidButton(action: { dismiss() }) {
                Text("확인")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("닫기")

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SellSummaryRow (헬퍼)

private struct SellSummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(AppColors.ink)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
