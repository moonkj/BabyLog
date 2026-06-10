import SwiftUI

// MARK: - QuickRecordSheet
// 빠른 기록 바텀시트 — 2탭 완료(초경량) ↔ 자세히 펼치기 토글.
// FAB 또는 caller가 .sheet { QuickRecordSheet(...) } 로 진입.
// .presentationDetents([.medium, .large]) 적용 권장.

struct QuickRecordSheet: View {
    var mode: AppMode           // baby / pregnancy (MainTabView에 정의)
    var childName: String = "지호"
    var onSave: () -> Void = {}
    var onClose: () -> Void = {}

    @EnvironmentObject private var store: AppStore

    // MARK: Internal state
    @State private var showDetail = false
    @State private var savedOverlay = false
    @State private var showProInfo = false

    // 이정표 선택 (다중)
    @State private var selectedMilestones: Set<String> = []

    // 사진 선택
    @State private var selectedPhoto: UIImage? = nil

    // 자세히 펼치기 입력
    @State private var memo: String = ""
    @State private var heightText: String = ""
    @State private var weightText: String = ""

    // 저장 완료 순간 카운터 — 선택 아이의 실제 기록(다이어리) 수 (저장 후 호출되어 방금 항목 포함)
    private var momentCount: Int {
        guard let id = store.selectedChild?.id else { return 1 }
        return max(1, store.diaryEntries(for: id).count)
    }

    // MARK: 모드별 콘텐츠
    private var sheetTitle: String {
        mode == .pregnancy ? "임신 기록" : "오늘 기록"
    }

    private var photoPrompt: String {
        mode == .pregnancy ? "배 사진 1장이면 기록 완료" : "사진 1장이면 기록 완료"
    }

    private var photoCameraIcon: String {
        mode == .pregnancy ? "figure.stand" : "camera.fill"
    }

    private var milestones: [MilestoneItem] {
        mode == .pregnancy ? pregnancyMilestones : babyMilestones
    }

    private var modeBadgeTone: BadgeTone {
        showDetail ? .purple : .mint
    }

    private var modeBadgeLabel: String {
        showDetail ? "자세히 모드" : "초경량 · 2탭"
    }

    // 상세 섹션: pregnancy 톤 vs baby 톤
    private var heightLabel: String { mode == .pregnancy ? "자궁저부 (cm)" : "키 (cm)" }
    private var weightLabel: String { mode == .pregnancy ? "산모 몸무게 (kg)" : "몸무게 (kg)" }
    private var memoPlaceholder: String {
        mode == .pregnancy
            ? "태동 느낌, 컨디션 메모 (선택)"
            : "한 줄 메모 (선택)"
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            mainContent
            if savedOverlay {
                saveRewardOverlay
                // 이정표 동반 저장이면 축하 버스트 (§8.3 감정 피크)
                if !selectedMilestones.isEmpty {
                    MilestoneBurst()
                }
            }
        }
        // 애니메이션: 완료 오버레이 진입
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: savedOverlay)
        .alert("AI 캡션 — 곧 제공돼요", isPresented: $showProInfo) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("사진을 보고 캡션 초안을 만들어주는 프리미엄 기능이에요. 다음 업데이트에서 만나요.")
        }
    }

    // MARK: Main scroll content
    private var mainContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                dragHandle
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    photoDropZone
                        .padding(.bottom, Spacing.s4)
                    milestoneRow
                        .padding(.bottom, showDetail ? Spacing.s4 : Spacing.s5)
                    if showDetail {
                        detailSection
                            .padding(.bottom, Spacing.s3)
                    }
                    saveButton
                        .padding(.top, Spacing.s2)
                    toggleDetailButton
                        .padding(.top, Spacing.s1)
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s7)
            }
        }
        .background(AppColors.surface)
    }

    // MARK: - Sub-views

    // 드래그 핸들
    private var dragHandle: some View {
        Capsule()
            .fill(AppColors.line2)
            .frame(width: 40, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // 헤더 행 (타이틀 + 모드 뱃지 + 닫기)
    private var headerRow: some View {
        HStack(alignment: .center) {
            Text(sheetTitle)
                .font(AppFont.title)
                .foregroundStyle(AppColors.ink)
                .accessibilityAddTraits(.isHeader)

            BLBadge(tone: modeBadgeTone, text: modeBadgeLabel, systemIcon: nil, dot: true)
                .accessibilityLabel("모드: \(modeBadgeLabel)")

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppColors.ink3)
                    .frame(width: 44, height: 44)   // 44pt 터치영역
            }
            .accessibilityLabel("닫기")
        }
        .padding(.bottom, Spacing.s4)
    }

    // 사진 드롭존 — PhotoPickerButton으로 실제 사진 선택 연결
    private var photoDropZone: some View {
        let dropHeight: CGFloat = showDetail ? 150 : 210
        return PhotoPickerButton(image: $selectedPhoto) {
            ZStack {
                // 선택된 이미지 있으면 미리보기, 없으면 플레이스홀더
                SelectedPhotoView(
                    image: selectedPhoto,
                    cornerRadius: Radius.lg
                ) {
                    PhotoPlaceholder(seed: mode == .pregnancy ? 3 : 1, cornerRadius: Radius.lg)
                }
                .frame(maxWidth: .infinity)
                .frame(height: dropHeight)

                // 미선택 상태: 드롭존 안내 오버레이
                if selectedPhoto == nil {
                    VStack(spacing: Spacing.s2) {
                        Image(systemName: photoCameraIcon)
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white.opacity(0.95))
                            .accessibilityHidden(true)
                        Text(photoPrompt)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    }
                } else {
                    // 선택 완료 상태: 우하단 교체 힌트
                    Image(systemName: "photo.badge.arrow.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                        .padding(10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .frame(height: dropHeight)
        .accessibilityLabel(mode == .pregnancy ? "배 사진 추가 버튼" : "사진 추가 버튼")
        .accessibilityValue(selectedPhoto != nil ? "사진 선택됨" : "사진 없음")
        .accessibilityHint("탭하여 사진 라이브러리에서 선택합니다")
        .animation(.easeInOut(duration: 0.22), value: showDetail)
        .animation(.easeInOut(duration: 0.18), value: selectedPhoto != nil)
    }

    // 이정표 칩 가로 스크롤
    private var milestoneRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(milestones) { item in
                    milestoneChip(item)
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -Spacing.s5)   // 부모 패딩 상쇄 → 전폭 스크롤
    }

    private func milestoneChip(_ item: MilestoneItem) -> some View {
        let isOn = selectedMilestones.contains(item.label)
        return Button {
            if isOn {
                selectedMilestones.remove(item.label)
            } else {
                selectedMilestones.insert(item.label)
            }
        } label: {
            HStack(spacing: 5) {
                // 색+아이콘+레이블 3중 인코딩 (DESIGN.md §2.2)
                Image(systemName: isOn ? item.iconFill : item.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isOn ? item.color : AppColors.ink3)
                    .accessibilityHidden(true)
                Text(item.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isOn ? Color.white : AppColors.ink2)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(isOn ? item.color : AppColors.surface, in: Capsule())
            .overlay {
                Capsule().stroke(isOn ? item.color : AppColors.line, lineWidth: 1)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityLabel(item.label)
        .accessibilityValue(isOn ? "선택됨" : "선택 안 됨")
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // 자세히 섹션 (메모 + 키/몸무게 + AI 잠금)
    @ViewBuilder
    private var detailSection: some View {
        VStack(spacing: Spacing.s3) {
            // 메모 텍스트필드
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.surface2)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .stroke(AppColors.line, lineWidth: 1)
                    }
                    .frame(minHeight: 60)

                if memo.isEmpty {
                    Text(memoPlaceholder)
                        .font(AppFont.body)
                        .foregroundStyle(AppColors.ink3)
                        .padding(.horizontal, 14)
                        .padding(.top, 13)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $memo)
                    .font(AppFont.body)
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 60)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .accessibilityLabel(memoPlaceholder)

            // 키 / 몸무게 입력
            HStack(spacing: Spacing.s3) {
                numericField(label: heightLabel, placeholder: mode == .pregnancy ? "30.0" : "78.5", text: $heightText, unit: "cm")
                numericField(label: weightLabel, placeholder: mode == .pregnancy ? "62.5" : "10.2", text: $weightText, unit: "kg")
            }

            // AI 캡션 초안 잠금 버튼 (Pro)
            Button {
                Haptics.light()
                showProInfo = true
            } label: {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .accessibilityHidden(true)
                    Text("AI 캡션 초안 만들기")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink2)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Pro")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(AppColors.gold)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(AppColors.goldTint, in: Capsule())
                }
                .padding(.horizontal, Spacing.s4)
                .frame(maxWidth: .infinity, minHeight: 44)   // 44pt 터치영역
                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(AppColors.line2)
                }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.97))
            .accessibilityLabel("AI 캡션 초안 만들기 Pro 기능")
            .accessibilityHint("Pro 플랜에서 사용할 수 있습니다")
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(.easeInOut(duration: 0.25), value: showDetail)
    }

    // 숫자 입력 필드 (키/몸무게)
    private func numericField(label: String, placeholder: String, text: Binding<String>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppFont.micro)
                .foregroundStyle(AppColors.ink3)

            HStack(spacing: 0) {
                TextField(placeholder, text: text)
                    .font(AppFont.num(15))
                    .foregroundStyle(AppColors.ink)
                    .keyboardType(.decimalPad)
                    .padding(.leading, Spacing.s3)
                    .frame(maxWidth: .infinity, minHeight: 44)    // 44pt 터치영역
                Text(unit)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
                    .padding(.trailing, Spacing.s3)
            }
            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .stroke(AppColors.line, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) 입력")
    }

    // 저장 LiquidButton (2탭 완료)
    private var saveButton: some View {
        LiquidButton(action: handleSave) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityHidden(true)
                Text("저장하기")
            }
        }
        .accessibilityLabel("저장하기")
        .accessibilityHint("탭하면 기록이 저장됩니다")
    }

    // 자세히 펼치기 / 간단하게 토글
    private var toggleDetailButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                showDetail.toggle()
            }
        } label: {
            HStack(spacing: Spacing.s1) {
                Text(showDetail ? "간단하게" : "자세히 입력")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: showDetail ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppColors.ink3)
            .frame(maxWidth: .infinity, minHeight: 44)   // 44pt 터치영역
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .accessibilityLabel(showDetail ? "간단하게 보기" : "자세히 입력하기")
    }

    // MARK: 저장 완료 보상 오버레이
    private var saveRewardOverlay: some View {
        ZStack {
            AppColors.surface
                .ignoresSafeArea()

            VStack(spacing: Spacing.s4) {
                // 팝 애니메이션 원형 아이콘
                ZStack {
                    Circle()
                        .fill(AppColors.primaryTint)
                        .frame(width: 84, height: 84)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                }
                .popAnimation()

                Text("\(childName)의 \(momentCount)번째 순간")
                    .font(AppFont.h2)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                Text("소중한 오늘이 타임라인에 담겼어요")
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.s6)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(childName)의 \(momentCount)번째 순간이 저장되었습니다")
    }

    // MARK: - Actions

    private func handleSave() {
        // selectedChild 없으면 저장 스킵하고 바로 닫기
        guard let childId = store.selectedChild?.id else {
            onSave()
            onClose()
            return
        }

        // 사진·메모·이정표 중 하나라도 있으면 DiaryEntry 기록
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let milestoneText = selectedMilestones.isEmpty
            ? nil
            : selectedMilestones.sorted().joined(separator: ", ")
        let hasDiaryContent = selectedPhoto != nil
            || !trimmedMemo.isEmpty
            || !selectedMilestones.isEmpty
        if hasDiaryContent {
            // 사진은 로컬에만 저장 (서버 비전송) → 파일명을 photoRef로 보관
            let photoFile = selectedPhoto.flatMap { PhotoStore.save($0) }
            store.addDiaryEntry(
                childId:   childId,
                content:   trimmedMemo.isEmpty ? nil : trimmedMemo,
                milestone: milestoneText,
                photoRef:  photoFile
            )
        }

        // 자세히 모드에서 키·몸무게 입력값이 하나라도 있으면 GrowthRecord 기록
        if showDetail {
            let heightVal  = Double(heightText.trimmingCharacters(in: .whitespaces))
            let weightVal  = Double(weightText.trimmingCharacters(in: .whitespaces))
            if heightVal != nil || weightVal != nil {
                store.addGrowthRecord(
                    childId:             childId,
                    heightCm:            heightVal,
                    weightKg:            weightVal,
                    headCircumferenceCm: nil
                )
            }
        }

        // 1탭: 저장 버튼 탭 → 보상 오버레이 표시 (+ 성공 햅틱)
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            savedOverlay = true
        }
        // 2탭(1.6s): 오버레이 표시 후 onSave+onClose 호출
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            onSave()
            onClose()
        }
    }
}

// MARK: - Pop animation helper
private extension View {
    func popAnimation() -> some View {
        modifier(PopModifier())
    }
}

private struct PopModifier: ViewModifier {
    @State private var appeared = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Milestone data model
private struct MilestoneItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String       // SF Symbol (outline)
    let iconFill: String   // SF Symbol (fill) — 선택 시
    let color: Color       // 색상 인코딩 (3중 인코딩 §2.2)
}

// 육아 모드 이정표
private let babyMilestones: [MilestoneItem] = [
    MilestoneItem(label: "첫 웃음",      icon: "face.smiling",             iconFill: "face.smiling.inverse",        color: AppColors.primary),
    MilestoneItem(label: "뒤집기",        icon: "arrow.2.circlepath",       iconFill: "arrow.2.circlepath",           color: Color(hex: 0x5B53B0)),
    MilestoneItem(label: "앉기",          icon: "figure.stand",             iconFill: "figure.stand",                 color: Color(hex: 0x3B6FA8)),
    MilestoneItem(label: "첫 걸음마",    icon: "figure.walk",              iconFill: "figure.walk",                  color: Color(hex: 0xB45840)),
    MilestoneItem(label: "첫 단어",      icon: "bubble.left",              iconFill: "bubble.left.fill",             color: Color(hex: 0x98711E)),
    MilestoneItem(label: "이유식 시작",  icon: "fork.knife",               iconFill: "fork.knife",                   color: Color(hex: 0xB5478A)),
]

// 임신 모드 이정표
private let pregnancyMilestones: [MilestoneItem] = [
    MilestoneItem(label: "태동 느낌",    icon: "heart",                    iconFill: "heart.fill",                   color: AppColors.pregnancyPink),
    MilestoneItem(label: "배 사진",       icon: "camera",                   iconFill: "camera.fill",                  color: AppColors.primary),
    MilestoneItem(label: "검진",          icon: "stethoscope",              iconFill: "stethoscope",                   color: Color(hex: 0x3B6FA8)),
    MilestoneItem(label: "컨디션 메모",  icon: "note.text",                iconFill: "note.text",                    color: Color(hex: 0x5B53B0)),
    MilestoneItem(label: "초음파",        icon: "waveform.path.ecg",        iconFill: "waveform.path.ecg",             color: Color(hex: 0x98711E)),
    MilestoneItem(label: "튼살 관리",    icon: "drop",                     iconFill: "drop.fill",                    color: Color(hex: 0xB45840)),
]

// MARK: - Preview
#if DEBUG
#Preview("Baby Mode") {
    QuickRecordSheet(mode: .baby, childName: "지호")
        .presentationDetents([.medium, .large])
        .environmentObject(SampleData.store())
}

#Preview("Pregnancy Mode") {
    QuickRecordSheet(mode: .pregnancy, childName: "아기")
        .presentationDetents([.medium, .large])
        .environmentObject(SampleData.store())
}
#endif
