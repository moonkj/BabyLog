// Features/Pregnancy/BirthTransitionView.swift
// BabyLog · 출산 전환 시트
// SwiftUI / Foundation only
// 팀장 통합 시: onComplete 클로저에서 AppStore.commitBirthTransition 호출

import SwiftUI

// MARK: - 출산 전환 뷰

/// 임신 기록 → 아이 프로필 전환 시트.
/// `onComplete` 는 부모(팀장)가 연결. 여기선 호출만 수행.
/// 목업 태명은 팀장 통합 시 `Pregnancy.nickname` 으로 교체.
struct BirthTransitionView: View {

    /// 전환 완료 후 부모에게 알림 (저장은 AppStore 담당)
    var onComplete: () -> Void

    // ── 입력 상태 ────────────────────────────────────────────────────
    @State private var childName: String = ""
    @State private var birthDate: Date = Date()
    @State private var showDatePicker: Bool = false
    @State private var nameError: String? = nil

    // ── 화면 단계 ────────────────────────────────────────────────────
    @State private var step: TransitionStep = .input

    // ── 목업 태명 (팀장 통합 시 외부 주입) ──────────────────────────
    private let mockNickname: String = "튼튼이"

    // ── 환경 ─────────────────────────────────────────────────────────
    @Environment(\.dismiss) private var dismiss

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

                Text("\(mockNickname)의 임신 기록을\n아이 프로필로 이어드릴게요.")
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
                        TextField("\(mockNickname) (태명 또는 이름)", text: $childName)
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
                            }
                            .submitLabel(.done)
                            .accessibilityLabel("아이 이름 입력칸")
                            .accessibilityHint("태명 \(mockNickname) 또는 실제 이름을 입력하세요")
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
                // 아기 아이콘
                ZStack {
                    Circle()
                        .fill(AppColors.primaryTint)
                        .frame(width: 96, height: 96)
                    Text("👶")
                        .font(.system(size: 48))
                }
                .accessibilityHidden(true)
                .padding(.top, Spacing.s6)
                .padding(.bottom, Spacing.s4)

                // 축하 메시지
                Text("세상에 온 걸 환영해요")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                let trimmedName = childName.trimmingCharacters(in: .whitespacesAndNewlines)
                Text("'\(trimmedName.isEmpty ? mockNickname : trimmedName)'의 태아 시절 기록은\n그대로 보존했어요. 이제 성장 기록으로 함께 이어가요.")
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

    // MARK: - 전환 시도 (검증)

    private func attemptTransition() {
        let trimmed = childName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation { nameError = "이름을 입력해 주세요" }
            return
        }
        // 팀장 통합 시: AppStore.commitBirthTransition 결과로 분기
        withAnimation(.easeInOut(duration: 0.35)) {
            step = .celebration
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
}
#Preview("출산 전환 — 완료") {
    // 축하 단계는 BirthTransitionView를 열고 이름 입력 후 버튼 탭으로 진입
    BirthTransitionView { }
}
#endif
