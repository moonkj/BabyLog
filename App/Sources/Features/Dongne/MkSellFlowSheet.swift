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
    @State private var hygiene: Set<String> = []
    @State private var showComplete = false
    @State private var submitting = false
    @State private var alertMessage: String? = nil
    @ObservedObject private var location = NearbyLocationProvider.shared

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var priceValue: Int { Int(priceText.filter(\.isNumber)) ?? 0 }
    private var canRegister: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    /// 가격 단계 통과 조건 — 무료나눔이거나, 유료면 가격 > 0(0원으로 무료처럼 등록되는 것 방지).
    private var canProceedPrice: Bool { isFree || priceValue > 0 }
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
            HStack(spacing: 8) {
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
        .alert("매물 등록", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("확인", role: .cancel) {}
        } message: { Text(alertMessage ?? "") }
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
                            // 원본 비율 유지(scaledToFit) — 잘림 없이 전체 표시
                            Image(uiImage: first).resizable().scaledToFit()
                                .frame(maxWidth: .infinity).frame(maxHeight: 240)
                                .background(AppColors.surface2)
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
        ScrollView(showsIndicators: false) {
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
                            .frame(height: 60)
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

            // 위생 셀프체크 (아동 안전 — 직접 선택)
            VStack(alignment: .leading, spacing: 8) {
                Text("위생 셀프체크 (선택)").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppColors.ink3)
                ForEach(MarketItem.hygieneOptions, id: \.self) { opt in
                    let on = hygiene.contains(opt)
                    Button {
                        Haptics.selection()
                        if on { hygiene.remove(opt) } else { hygiene.insert(opt) }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(on ? AppColors.primary : AppColors.surface2)
                                    .frame(width: 24, height: 24)
                                    .overlay { RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(on ? AppColors.primary : AppColors.line, lineWidth: 1) }
                                if on {
                                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            Text(opt).font(.system(size: 14, weight: .medium)).foregroundStyle(AppColors.ink2)
                            Spacer()
                        }
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.98))
                    .accessibilityLabel(opt)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                }
            }

            LiquidButton(fill: canProceedPrice ? AppColors.primary : AppColors.ink3,
                         action: { guard canProceedPrice else { return }; withAnimation { step = 2 } }) {
                Text(canProceedPrice ? "다음" : "가격을 입력해주세요")
                    .font(.system(size: 16, weight: .bold))
            }
            .disabled(!canProceedPrice)
            .accessibilityLabel("다음 단계로")
        }
        .padding(.bottom, 20)
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
                    SellSummaryRow(icon: "checkmark.shield.fill", label: "위생 체크", value: hygiene.isEmpty ? "선택 안 함" : "\(hygiene.count)개 확인")
                }
            }
            .accessibilityElement(children: .contain)

            LiquidButton(fill: submitting ? AppColors.ink3 : AppColors.primary, action: {
                guard !submitting else { return }
                register()
            }) {
                Text(submitting ? "등록 중…" : "등록하기")
                    .font(.system(size: 16, weight: .bold))
            }
            .disabled(submitting)
            .accessibilityLabel("매물 등록하기")
        }
    }

    // 실제 등록 — 서버 구성 시 Supabase 업로드, 미구성 시 로컬 저장
    private func register() {
        if SupabaseConfig.isConfigured {
            registerToServer()
        } else {
            registerLocal()
        }
    }

    // 서버 등록 — 무료 1매물 게이트 → 업로드 → 로컬 캐시 → 완료 화면
    private func registerToServer() {
        submitting = true
        Task {
            // 무료 한도 확인 (무료 회원 1매물). 네트워크로 개수를 확인 못 하면(nil) '한도 초과'로
            // 단정하지 않고 재시도를 안내한다 — 0개인데도 "1개까지" 오안내가 뜨던 문제 방지.
            let activeCount = await MarketBackend.myActiveListingCount()
            if activeCount == nil {
                await MainActor.run {
                    submitting = false
                    alertMessage = "지금은 연결 상태를 확인하지 못했어요. 잠시 후 다시 시도해 주세요."
                }
                return
            }
            if let c = activeCount, c >= MarketBackend.freeListingLimit {
                await MainActor.run {
                    submitting = false
                    alertMessage = "무료 회원은 매물을 1개까지 올릴 수 있어요. 기존 매물을 판매완료하거나 삭제한 뒤 다시 등록해 주세요."
                }
                return
            }

            let hood = store.selectedHood ?? location.localityName ?? ""
            // 위치 미확보 시 서버 등록이 실패하므로 시도하지 않고 안내(CrewCreateSheet와 동일 가드).
            guard !hood.isEmpty, hood != "우리 동네" else {
                await MainActor.run {
                    submitting = false
                    alertMessage = "위치를 확인하고 있어요. 잠시 후 다시 시도해 주세요."
                }
                return
            }
            // 사진은 서버 업로드 + 로컬 캐시 둘 다 보존(photoRefs는 즉시 표시용 로컬 캐시).
            let item = MarketItem(
                title: title.trimmingCharacters(in: .whitespaces),
                category: selectedCategory,
                grade: selectedGrade,
                monthsTag: monthsTag.isEmpty ? "전 월령" : monthsTag,
                price: isFree ? 0 : priceValue,
                originalPrice: nil,
                isFree: isFree,
                hasRecall: false,
                isGraduate: false,   // '동네 졸업템'은 판매자가 선택해야 — 자동 부여 금지(정직)
                sellerName: nickname,
                sellerTier: .new,
                distanceText: "내 동네",
                favoriteCount: 0,
                photoSeed: 0,
                description: desc,
                photoRefs: photos.compactMap { PhotoStore.save($0) },
                mine: true,
                status: .selling,
                hygieneChecks: MarketItem.hygieneOptions.filter { hygiene.contains($0) }
            )

            let newID = await MarketBackend.createItem(hood: hood, item: item, photos: photos)
            await MainActor.run {
                submitting = false
                if let newID {
                    // 로컬 store에는 '서버 id'로 추가 — 클라 UUID로 넣으면 서버 row와 불일치해
                    // 유령 매물(뱃지 오트리거·사진 고아·상태변경 0행)이 된다. id를 맞춰 정합 유지.
                    var stored = item; stored.id = newID
                    store.addMarketItem(stored)
                    Haptics.success()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showComplete = true }
                } else {
                    alertMessage = "매물을 등록하지 못했어요. 잠시 후 다시 시도해 주세요."
                }
            }
        }
    }

    // 로컬 등록 — 사진 로컬 저장 후 store에 추가(서버 미구성 폴백)
    private func registerLocal() {
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
            isGraduate: false,   // '동네 졸업템' 자동 부여 금지 — 판매자 선택 항목
            sellerName: nickname,
            sellerTier: .new,
            distanceText: "내 동네",
            favoriteCount: 0,
            photoSeed: 0,
            description: desc,
            photoRefs: refs,
            mine: true,
            status: .selling,
            hygieneChecks: MarketItem.hygieneOptions.filter { hygiene.contains($0) }
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

            // 뱃지 축하는 전역 윈도우 카드(BadgeOverlayWindow)가 '첫 매물 등록' 시 1회만 띄운다.
            // 여기서 하드코딩하면 2번째·3번째 등록에도 "첫 매물 등록 뱃지 획득!"이 거짓으로 떠서 제거.

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
