import SwiftUI

// MARK: - QuickRecordSheet
// 빠른 기록 바텀시트 — 2탭 완료(초경량) ↔ 자세히 펼치기 토글.
// FAB 또는 caller가 .sheet { QuickRecordSheet(...) } 로 진입.
// .presentationDetents([.medium, .large]) 적용 권장.

struct QuickRecordSheet: View {
    var mode: AppMode           // baby / pregnancy (MainTabView에 정의)
    var onSave: () -> Void = {}
    var onClose: () -> Void = {}

    @EnvironmentObject private var store: AppStore

    /// 현재 선택된 아이 이름 (하드코딩 금지 — store 기준)
    private var childName: String {
        if mode == .pregnancy { return store.activePregnancy?.nickname ?? "우리 아기" }
        return store.selectedChild?.name ?? "우리 아기"
    }

    // MARK: Internal state
    @State private var showDetail = false
    @State private var savedOverlay = false

    // 이정표 선택 (다중)
    @State private var selectedMilestones: Set<String> = []

    // 사진 선택
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideoURL: URL? = nil
    @State private var carouselIndex = 0
    @State private var selectedExtraChildIds: Set<UUID> = []
    private var hasMedia: Bool { !selectedImages.isEmpty || selectedVideoURL != nil }

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

    private var childAgeMonths: Int {
        guard let c = store.selectedChild else { return 12 }
        return AgeCalculator.childAgeMonths(birthDate: c.birthDate, asOf: Date()).months
    }

    private var milestones: [MilestoneItem] {
        mode == .pregnancy ? pregnancyMilestones : babyMilestones(months: childAgeMonths)
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
                    siblingSelector
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

    // 사진/동영상 드롭존 — 선택 시 스와이프 캐러셀, 미선택 시 드롭존
    private var photoDropZone: some View {
        let mediaHeight: CGFloat = showDetail ? 300 : 420
        return Group {
            if hasMedia {
                mediaCarousel(height: mediaHeight)
            } else {
                MediaPickerButton(maxImages: 5, images: $selectedImages, videoURL: $selectedVideoURL) {
                    dropZonePlaceholder(height: showDetail ? 150 : 210)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
            }
        }
        .accessibilityLabel(mode == .pregnancy ? "배 사진 추가" : "사진·동영상 추가")
        .accessibilityValue(hasMedia ? "선택됨" : "없음")
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showDetail)
        .animation(.easeInOut(duration: 0.2), value: hasMedia)
    }

    // 선택 미디어 캐러셀 (사진 여러 장 + 동영상, 스와이프)
    private func mediaCarousel(height: CGFloat) -> some View {
        let pageCount = selectedImages.count + (selectedVideoURL != nil ? 1 : 0)
        return ZStack(alignment: .topTrailing) {
            TabView(selection: $carouselIndex) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, img in
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: height).clipped()
                        .tag(idx)
                }
                if let vurl = selectedVideoURL {
                    VideoPreviewView(url: vurl)
                        .frame(maxWidth: .infinity).frame(height: height)
                        .tag(selectedImages.count)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: pageCount > 1 ? .always : .never))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))

            // 변경/삭제
            HStack(spacing: 8) {
                MediaPickerButton(maxImages: 5, images: $selectedImages, videoURL: $selectedVideoURL) {
                    Label("변경", systemImage: "photo.on.rectangle")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).frame(height: 32)
                        .background(.black.opacity(0.45), in: Capsule())
                }
                Button {
                    selectedImages = []; selectedVideoURL = nil; carouselIndex = 0
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .accessibilityLabel("미디어 모두 지우기")
            }
            .padding(10)
        }
    }

    private func dropZonePlaceholder(height: CGFloat) -> some View {
        ZStack {
            PhotoPlaceholder(seed: mode == .pregnancy ? 3 : 1, cornerRadius: Radius.lg)
                .frame(maxWidth: .infinity).frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            VStack(spacing: Spacing.s2) {
                Image(systemName: photoCameraIcon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .accessibilityHidden(true)
                Text("사진·동영상 (최대 5장)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            }
        }
    }

    // 함께 기록할 아이 (형제·자매) — 같이 찍은 사진을 여러 아이에게 동시 기록
    @ViewBuilder
    private var siblingSelector: some View {
        let others = store.children.filter { $0.id != store.selectedChild?.id }
        if mode == .baby, !others.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Text("함께 기록할 아이")
                    .font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                Text("같이 찍은 사진이면 형제·자매에게도 함께 올려요")
                    .font(AppFont.caption).foregroundStyle(AppColors.ink3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s2) {
                        ForEach(others) { child in
                            let on = selectedExtraChildIds.contains(child.id)
                            Button {
                                Haptics.selection()
                                if on { selectedExtraChildIds.remove(child.id) }
                                else { selectedExtraChildIds.insert(child.id) }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.system(size: 13, weight: .bold))
                                    Text(child.name).font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundStyle(on ? Color.white : AppColors.ink2)
                                .padding(.horizontal, 12).frame(height: 40)
                                .background(on ? AppColors.primary : AppColors.surface2, in: Capsule())
                            }
                            .buttonStyle(LiquidPressStyle(scale: 0.96))
                            .accessibilityLabel("\(child.name)에게도 함께 기록")
                            .accessibilityAddTraits(on ? [.isSelected] : [])
                        }
                    }
                }
            }
            .padding(.bottom, Spacing.s5)
        }
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
            .frame(height: 40)
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
                        .foregroundStyle(AppColors.ink2)
                        .padding(.horizontal, 16)
                        .padding(.top, 17)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $memo)
                    .font(AppFont.body)
                    .foregroundStyle(AppColors.ink)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .frame(minHeight: 60)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
            .accessibilityLabel(memoPlaceholder)

            // 키 / 몸무게 입력
            HStack(spacing: Spacing.s3) {
                numericField(label: heightLabel, placeholder: mode == .pregnancy ? "30.0" : "78.5", text: $heightText, unit: "cm")
                numericField(label: weightLabel, placeholder: mode == .pregnancy ? "62.5" : "10.2", text: $weightText, unit: "kg")
            }
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
                        .frame(width: 76, height: 76)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 34))
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

    // 임신 모드 저장: 배 사진 → 활성 임신 배사진 타임라인, 산모 체중 → 체중 기록
    private func savePregnancyRecord() {
        guard let preg = store.activePregnancy else { return }
        let week = AgeCalculator.pregnancyWeeks(lmp: preg.lmpDate, edd: preg.eddDate, asOf: Date())?.weeks ?? 0
        for img in selectedImages {
            if let ref = PhotoStore.save(img) {
                store.addBellyPhoto(pregnancyId: preg.id, week: week, photoRef: ref)
            }
        }
        if showDetail, let w = Double(weightText.trimmingCharacters(in: .whitespaces)) {
            store.addPregnancyWeight(pregnancyId: preg.id, kg: w)
        }
        // 메모 저장 (손실 방지)
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMemo.isEmpty {
            store.addPregnancyMemo(pregnancyId: preg.id, text: trimmedMemo)
        }
    }

    private func handleSave() {
        if mode == .pregnancy {
            // 임신 모드: 배 사진 + 산모 체중을 활성 임신 기록에 저장
            savePregnancyRecord()
        } else if let childId = store.selectedChild?.id {
            // 사진·메모·이정표 중 하나라도 있으면 DiaryEntry 기록
            let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
            let milestoneText = selectedMilestones.isEmpty
                ? nil
                : selectedMilestones.sorted().joined(separator: ", ")
            let hasDiaryContent = hasMedia
                || !trimmedMemo.isEmpty
                || !selectedMilestones.isEmpty
            if hasDiaryContent {
                let content = trimmedMemo.isEmpty ? nil : trimmedMemo
                // 대상 아이들: 현재 아이 + 함께 선택된 형제·자매. 각 아이가 자기 사진 파일을 소유(삭제 안전).
                let targetIds = [childId] + selectedExtraChildIds.filter { $0 != childId }
                for tid in targetIds {
                    let refs = selectedImages.compactMap { PhotoStore.save($0) }
                    let videoFile = selectedVideoURL.flatMap { PhotoStore.saveVideo(from: $0) }
                    store.addDiaryEntry(
                        childId:   tid,
                        content:   content,
                        milestone: milestoneText,
                        photoRef:  refs.first,
                        photoRefs: refs,
                        videoRef:  videoFile
                    )
                }
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
        } else {
            onSave(); onClose(); return
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

// 육아 모드 이정표 — 아이 월령에 맞춰 노출
private func babyMilestones(months: Int) -> [MilestoneItem] {
    let c1 = AppColors.primary, c2 = Color(hex: 0x5B53B0), c3 = Color(hex: 0x3B6FA8)
    let c4 = Color(hex: 0xB45840)
    func mk(_ l: String, _ i: String, _ c: Color) -> MilestoneItem {
        MilestoneItem(label: l, icon: i, iconFill: i, color: c)
    }
    switch months {
    case 0..<4:
        return [mk("첫 웃음", "face.smiling", c1), mk("목 가누기", "figure.stand", c2),
                mk("첫 외출", "stroller", c3), mk("첫 사진", "camera", c4)]
    case 4..<7:
        return [mk("뒤집기", "arrow.2.circlepath", c1), mk("옹알이", "bubble.left", c2),
                mk("이유식 시작", "fork.knife", c3), mk("손 뻗기", "hand.raised", c4)]
    case 7..<10:
        return [mk("혼자 앉기", "figure.seated.side", c1), mk("기어다니기", "figure.walk.motion", c2),
                mk("첫 이앓이", "mouth", c3), mk("까꿍 놀이", "face.smiling", c4)]
    case 10..<13:
        return [mk("잡고 서기", "figure.stand", c1), mk("첫 단어", "bubble.left.fill", c2),
                mk("첫 걸음마", "figure.walk", c3), mk("첫 생일(돌)", "birthday.cake", c4)]
    case 13..<19:
        return [mk("걸음마", "figure.walk", c1), mk("새 단어", "bubble.left.fill", c2),
                mk("컵으로 마시기", "cup.and.saucer", c3), mk("끄적이기", "scribble", c4)]
    case 19..<25:
        return [mk("뛰기", "figure.run", c1), mk("두 단어 문장", "text.bubble", c2),
                mk("숟가락 사용", "fork.knife", c3), mk("신발 신기", "shoe", c4)]
    case 25..<37:
        return [mk("대소변 가리기", "toilet", c1), mk("세 단어 문장", "text.bubble.fill", c2),
                mk("친구와 놀기", "person.2.fill", c3), mk("색칠하기", "paintbrush", c4)]
    default:
        return [mk("어린이집/유치원", "building.2", c1), mk("세발자전거", "bicycle", c2),
                mk("가위질", "scissors", c3), mk("한글 관심", "textformat.abc", c4)]
    }
}

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
    QuickRecordSheet(mode: .baby)
        .presentationDetents([.medium, .large])
        .environmentObject(SampleData.store())
}

#Preview("Pregnancy Mode") {
    QuickRecordSheet(mode: .pregnancy)
        .presentationDetents([.medium, .large])
        .environmentObject(SampleData.store())
}
#endif
