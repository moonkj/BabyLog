// MkSellFlowSheet.swift
// BabyLog · Features/Dongne
// 마켓 판매 플로우 3단계 시트 — MarketItemDetail.swift에서 분리
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - MkSellFlowSheet (판매 플로우 3단계)

struct MkSellFlowSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var selectedGrade: MarketItemGrade = .a
    @State private var selectedCategory: MarketCategory = .cloth
    @State private var title: String = ""
    @State private var monthsTag: String = ""
    @State private var photos: [UIImage] = []
    @State private var priceText: String = ""
    @State private var isFree: Bool = false
    @State private var desc: String = ""
    @State private var showComplete = false

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var priceValue: Int { Int(priceText.filter(\.isNumber)) ?? 0 }
    private var canRegister: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var sellCategories: [MarketCategory] { MarketCategory.allCases.filter { $0 != .all } }

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

    // MARK: Step 0 — 사진 + 제목 + 카테고리
    private var sellStep0: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("무엇을 정리할까요?")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(AppColors.ink)

                // 사진 (최대 5장)
                MediaPickerButton(maxImages: 5, images: $photos, videoURL: .constant(nil)) {
                    if let first = photos.first {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: first).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).frame(height: 180).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            BLBadge(tone: .mint, text: "\(photos.count)장", systemIcon: "photo", dot: false)
                                .padding(10)
                        }
                    } else {
                        ZStack {
                            PhotoPlaceholder(seed: 0, cornerRadius: 18)
                                .frame(maxWidth: .infinity).frame(height: 180)
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill").font(.system(size: 30, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("사진 추가 (최대 5장)").font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))

                // 제목
                TextField("제목 (예: 스토케 식사의자)", text: $title)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 14).frame(height: 52)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppColors.line, lineWidth: 1) }

                // 월령 태그
                TextField("월령 태그 (예: 6개월+)", text: $monthsTag)
                    .font(.system(size: 15, weight: .medium))
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppColors.line, lineWidth: 1) }

                // 카테고리
                Text("카테고리").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sellCategories, id: \.self) { cat in
                            Button { selectedCategory = cat } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: cat.systemIcon).font(.system(size: 13, weight: .semibold))
                                    Text(cat.rawValue).font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(selectedCategory == cat ? .white : AppColors.ink2)
                                .padding(.horizontal, 14).frame(height: 36)
                                .background(selectedCategory == cat ? AppColors.ink : AppColors.surface, in: Capsule())
                                .overlay { Capsule().stroke(selectedCategory == cat ? AppColors.ink : AppColors.line, lineWidth: 1) }
                            }
                            .buttonStyle(LiquidPressStyle(scale: 0.96))
                        }
                    }
                }

                LiquidButton(fill: canRegister ? AppColors.primary : AppColors.ink3, action: {
                    guard canRegister else { return }
                    withAnimation { step = 1 }
                }) {
                    Text("다음").font(.system(size: 16, weight: .bold))
                }
                .accessibilityLabel("다음 단계로")
                .padding(.top, 4)
            }
            .padding(.bottom, 20)
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

            // 무료나눔 토글
            Toggle(isOn: $isFree) {
                Text("무료나눔으로 등록")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink)
            }
            .tint(AppColors.primary)

            // 가격 입력
            if !isFree {
                VStack(alignment: .leading, spacing: 8) {
                    Text("가격").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                    HStack(alignment: .center, spacing: 10) {
                        TextField("0", text: $priceText)
                            .keyboardType(.numberPad)
                            .font(AppFont.num(22, weight: .heavy))
                            .foregroundStyle(AppColors.ink)
                        Text("원").font(.system(size: 15, weight: .medium)).foregroundStyle(AppColors.ink2)
                    }
                    .padding(.horizontal, 16).frame(maxWidth: .infinity, minHeight: 56)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
                }
            }

            // 설명
            TextField("설명 (선택)", text: $desc, axis: .vertical)
                .font(.system(size: 14, weight: .regular))
                .lineLimit(2...4)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(AppColors.line, lineWidth: 1) }

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

            // 요약 카드 (실 입력)
            BLCard(padding: 14, flat: true) {
                VStack(alignment: .leading, spacing: 8) {
                    SellSummaryRow(icon: "photo.on.rectangle", label: "사진", value: photos.isEmpty ? "없음" : "\(photos.count)장")
                    SellSummaryRow(icon: "tag.fill", label: "제목", value: title.isEmpty ? "-" : title)
                    SellSummaryRow(icon: selectedCategory.systemIcon, label: "카테고리", value: selectedCategory.rawValue)
                    SellSummaryRow(icon: selectedGrade.systemIcon, label: "등급", value: "\(selectedGrade.rawValue)등급 · \(selectedGrade.label)")
                    SellSummaryRow(icon: "wonsign.circle.fill", label: "가격", value: isFree ? "무료나눔" : "\(priceValue.formatted())원")
                }
            }
            .accessibilityElement(children: .contain)

            LiquidButton(action: { register() }) {
                Text("등록하기")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel("매물 등록하기")
        }
    }

    // 실제 등록 — 사진 로컬 저장 후 store에 추가
    private func register() {
        let refs = photos.compactMap { PhotoStore.save($0) }
        let item = MarketItem(
            title: title.trimmingCharacters(in: .whitespaces),
            category: selectedCategory,
            grade: selectedGrade,
            monthsTag: monthsTag.isEmpty ? "전 월령" : monthsTag,
            price: isFree ? 0 : priceValue,
            originalPrice: nil,
            isFree: isFree,
            hasRecall: false,
            isGraduate: true,
            sellerName: nickname,
            sellerTier: .new,
            distanceText: "내 동네",
            favoriteCount: 0,
            photoSeed: 0,
            description: desc,
            photoRefs: refs,
            mine: true,
            status: .selling
        )
        store.addMarketItem(item)
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showComplete = true }
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
