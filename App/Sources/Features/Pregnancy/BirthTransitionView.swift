// Features/Pregnancy/BirthTransitionView.swift
// BabyLog · 출산 전환 시트
// SwiftUI / Foundation only

import SwiftUI
import UIKit

// MARK: - 출산 전환 뷰

/// 임신 기록 → 아이 프로필 전환 시트.
/// `onComplete` 는 부모가 시트 dismiss 처리용으로 연결. 저장은 AppStore.commitBirthTransition 담당.
struct BirthTransitionView: View {

    @EnvironmentObject private var store: AppStore

    /// 전환 완료 후 부모에게 알림
    var onComplete: () -> Void

    // ── 입력 상태 ────────────────────────────────────────────────────
    @State private var childName: String = ""
    @State private var birthDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var nameError: String? = nil
    @State private var transitionError: String? = nil
    @State private var profilePhoto: UIImage? = nil
    @State private var birthWeight: String = ""
    @State private var birthHeight: String = ""
    @State private var gender: Gender? = nil

    // ── 화면 단계 ────────────────────────────────────────────────────
    @State private var step: TransitionStep = .input
    @State private var createdChildName: String = ""

    // ── 환경 ─────────────────────────────────────────────────────────
    @Environment(\.dismiss) private var dismiss

    // ── 태명 (실데이터 우선, 없으면 목업) ───────────────────────────
    private var displayNickname: String {
        store.activePregnancy?.nickname?.isEmpty == false
            ? store.activePregnancy!.nickname!
            : "튼튼이"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.canvas.ignoresSafeArea()

                switch step {
                case .input:
                    inputStep
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .celebration:
                    celebrationStep
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step == .input {
                        Button("아직이에요") { dismiss() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                            .accessibilityLabel("전환 취소하고 돌아가기")
                    }
                }
                ToolbarItem(placement: .principal) {
                    if step == .input {
                        Text("출산 전환")
                            .font(AppFont.title)
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
        }
    }

    // MARK: - 입력 단계

    private var inputStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 상단 일러스트 영역
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFBE6EE), AppColors.primaryTint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                    Text("🤰")
                        .font(.system(size: 48))
                }
                .accessibilityHidden(true)
                .padding(.top, Spacing.s5)
                .padding(.bottom, Spacing.s4)

                // 타이틀
                Text("아기가 태어났나요?")
                    .font(.system(size: 23, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)

                Text("\(displayNickname)의 임신 기록을\n아이 프로필로 이어드릴게요.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, Spacing.s2)
                    .padding(.horizontal, Spacing.s5)

                // 입력 폼
                VStack(spacing: Spacing.s3) {
                    // 아이 이름
                    fieldGroup(label: "아이 이름") {
                        TextField("\(displayNickname) (태명 또는 이름)", text: $childName)
                            .font(AppFont.body)
                            .foregroundStyle(AppColors.ink)
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .stroke(nameError != nil ? AppColors.danger : AppColors.line, lineWidth: 1)
                            }
                            .onChange(of: childName) { _ in
                                nameError = nil
                                transitionError = nil
                            }
                            .submitLabel(.done)
                            .accessibilityLabel("아이 이름 입력칸")
                            .accessibilityHint("태명 \(displayNickname) 또는 실제 이름을 입력하세요")
                    }

                    if let error = nameError {
                        HStack(spacing: Spacing.s1) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 13))
                                .accessibilityHidden(true)
                            Text(error)
                                .font(AppFont.caption)
                        }
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let error = transitionError {
                        HStack(spacing: Spacing.s1) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13))
                                .accessibilityHidden(true)
                            Text(error)
                                .font(AppFont.caption)
                        }
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 실제 생일
                    fieldGroup(label: "실제 생년월일") {
                        Button {
                            withAnimation { showDatePicker.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(AppColors.ink3)
                                    .accessibilityHidden(true)
                                Text(birthDate.formatted(date: .long, time: .omitted))
                                    .font(AppFont.body)
                                    .foregroundStyle(AppColors.ink)
                                    .monospacedDigit()
                                Spacer()
                                Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppColors.ink3)
                            }
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .stroke(AppColors.line, lineWidth: 1)
                            }
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.98))
                        .accessibilityLabel("생년월일: \(birthDate.formatted(date: .long, time: .omitted))")
                        .accessibilityHint("탭하면 날짜 선택")

                        if showDatePicker {
                            DatePicker(
                                "생년월일",
                                selection: $birthDate,
                                in: ...Date(),
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .tint(AppColors.pregnancyPink)
                            .padding(.top, Spacing.s2)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .accessibilityLabel("달력에서 생년월일을 선택하세요")
                        }
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)
                .animation(.easeInOut(duration: 0.22), value: showDatePicker)
                .animation(.easeInOut(duration: 0.2), value: nameError)
                .animation(.easeInOut(duration: 0.2), value: transitionError)

                // 프로필 사진 + 출생 키/몸무게 (아이 프로필로 동기화)
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("프로필 사진 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                    MediaPickerButton(maxImages: 1,
                                      images: Binding(get: { profilePhoto.map { [$0] } ?? [] },
                                                      set: { profilePhoto = $0.first }),
                                      videoURL: .constant(nil)) {
                        ZStack {
                            if let img = profilePhoto {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Circle().fill(AppColors.primaryTint)
                                Image(systemName: "camera.fill").font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(AppColors.pregnancyPink)
                            }
                        }
                        .frame(width: 90, height: 90).clipShape(Circle())
                        .overlay { Circle().strokeBorder(AppColors.line, lineWidth: 1) }
                    }
                    .frame(maxWidth: .infinity)

                    Text("성별 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        .padding(.top, Spacing.s2)
                    HStack(spacing: Spacing.s2) {
                        genderChip(nil, "선택 안 함")
                        genderChip(.boy, "남아")
                        genderChip(.girl, "여아")
                    }

                    Text("출생 정보 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        .padding(.top, Spacing.s2)
                    HStack(spacing: Spacing.s3) {
                        birthMeasureField(label: "키(cm)", placeholder: "50.0", text: $birthHeight)
                        birthMeasureField(label: "몸무게(kg)", placeholder: "3.3", text: $birthWeight)
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)

                // CTA 버튼
                LiquidButton(
                    fill: AppColors.pregnancyPink,
                    cornerRadius: Radius.md
                ) {
                    attemptTransition()
                } label: {
                    Label("아이 프로필로 전환", systemImage: "arrow.right.circle.fill")
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)
                .accessibilityLabel("아이 프로필로 전환하기")
                .accessibilityHint("이름과 생년월일을 확인하고 전환합니다")

                // 안내
                Text("임신 기간 기록과 배 사진은 그대로 보존돼요.")
                    .font(AppFont.micro)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s3)
                    .padding(.bottom, Spacing.s7)
            }
        }
    }

    // MARK: - 축하 단계

    private var celebrationStep: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 아기 아이콘 + 출산 축하 버스트 (§8.3, 상실 흐름은 이 단계에 도달하지 않음)
                ZStack {
                    Circle()
                        .fill(AppColors.primaryTint)
                        .frame(width: 96, height: 96)
                    Text("👶")
                        .font(.system(size: 48))
                }
                .overlay { MilestoneBurst() }
                .accessibilityHidden(true)
                .padding(.top, Spacing.s6)
                .padding(.bottom, Spacing.s4)

                // 축하 메시지
                Text("세상에 온 걸 환영해요")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("'\(createdChildName)'의 태아 시절 기록은\n그대로 보존했어요. 이제 성장 기록으로 함께 이어가요.")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, Spacing.s2)
                    .padding(.horizontal, Spacing.s5)

                // 연속성 안내 카드
                BLCard(flat: true) {
                    VStack(spacing: 0) {
                        ForEach(continuityItems, id: \.title) { item in
                            continuityRow(item: item)
                            if item.title != continuityItems.last?.title {
                                Divider()
                                    .background(AppColors.line)
                                    .padding(.leading, Spacing.s3 + 28)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)

                // 완료 버튼
                LiquidButton(
                    fill: AppColors.primary,
                    cornerRadius: Radius.md
                ) {
                    onComplete()
                    dismiss()
                } label: {
                    Label("성장 기록 시작하기", systemImage: "arrow.right.circle.fill")
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.top, Spacing.s5)
                .accessibilityLabel("성장 기록 시작하기")
                .accessibilityHint("기록 탭으로 이동합니다")

                Spacer(minLength: Spacing.s7)
            }
        }
    }

    private struct ContinuityItem {
        let icon: String
        let title: String
        let subtitle: String
    }

    private var continuityItems: [ContinuityItem] {
        [
            .init(icon: "photo.stack.fill",
                  title: "배 사진 → 성장 사진",
                  subtitle: "끊김 없는 하나의 타임라인"),
            .init(icon: "syringe.fill",
                  title: "예방접종 타임라인",
                  subtitle: "생년월일 기준 자동 생성"),
            .init(icon: "person.2.fill",
                  title: "가족 공유 유지",
                  subtitle: "아빠·조부모 그대로 연결"),
        ]
    }

    private func continuityRow(item: ContinuityItem) -> some View {
        HStack(spacing: Spacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColors.primaryTint)
                    .frame(width: 28, height: 28)
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.primary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(item.subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.s3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.subtitle)")
    }

    // MARK: - 필드 그룹 헬퍼

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
            content()
        }
    }

    private func genderChip(_ value: Gender?, _ label: String) -> some View {
        let selected = gender == value
        return Button {
            Haptics.selection()
            gender = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.white : AppColors.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? AppColors.pregnancyPink : AppColors.surface2,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func birthMeasureField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(AppFont.micro).foregroundStyle(AppColors.ink3)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(AppFont.num(15))
                .padding(.horizontal, Spacing.s3)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
        }
        .accessibilityLabel("\(label) 입력")
    }

    // MARK: - 전환 시도 (검증 + AppStore 연결)

    private func attemptTransition() {
        let trimmed = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { nameError = "이름을 입력해 주세요" }
            return
        }

        // AppStore.activePregnancy가 있으면 실데이터 commitBirthTransition 호출
        if let preg = store.activePregnancy {
            let input = BirthTransitionInput(
                childName: trimmed,
                birthDate: birthDate,
                gender: gender
            )
            let result = store.commitBirthTransition(pregnancyId: preg.id, input: input)
            switch result {
            case .success(let child):
                store.selectedChildId = child.id
                createdChildName = child.name
                // 출산 완료 → 임신 모드에서 육아 모드로 전환
                // (안 하면 홈이 계속 "임신을 등록해보세요"를 보여줌)
                UserDefaults.standard.set(AppMode.baby.rawValue, forKey: "bl_app_mode")
                // 아이 프로필 동기화: 프로필 사진 + 출생 키/몸무게
                if let img = profilePhoto, let ref = PhotoStore.save(img) {
                    store.updateChild(id: child.id, name: child.name,
                                      birthDate: child.birthDate, gender: child.gender,
                                      profileImageRef: .some(ref))
                }
                let h = blDecimal(birthHeight)
                let w = blDecimal(birthWeight)
                if h != nil || w != nil {
                    store.addGrowthRecord(childId: child.id, heightCm: h, weightKg: w,
                                          headCircumferenceCm: nil)
                }
                Haptics.success()
                withAnimation(.easeInOut(duration: 0.35)) {
                    step = .celebration
                }
            case .failure(let error):
                withAnimation {
                    switch error {
                    case .emptyName:
                        nameError = "이름을 입력해 주세요"
                    case .notActive:
                        transitionError = "진행 중인 임신 기록을 찾을 수 없어요"
                    case .birthDateBeforeLMP:
                        transitionError = "출생일이 마지막 생리일보다 이전이에요. 날짜를 다시 확인해 주세요"
                    }
                }
            }
        } else {
            // activePregnancy 없음 — 목업 모드(프리뷰/테스트)에서 동작
            createdChildName = trimmed
            withAnimation(.easeInOut(duration: 0.35)) {
                step = .celebration
            }
        }
    }
}

// MARK: - 화면 단계

private enum TransitionStep: Equatable {
    case input
    case celebration
}

// MARK: - 미리보기

#if DEBUG
#Preview("출산 전환 — 입력") {
    BirthTransitionView { }
        .environmentObject(SampleData.store())
}
#Preview("출산 전환 — 임신 없음") {
    BirthTransitionView { }
        .environmentObject(AppStore())
}
#endif
