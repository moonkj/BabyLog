import SwiftUI
import PhotosUI

// MARK: - QuickRecordSheet
// 빠른 기록 바텀시트 — 2탭 완료(초경량) ↔ 자세히 펼치기 토글.
// FAB 또는 caller가 .sheet { QuickRecordSheet(...) } 로 진입.
// .presentationDetents([.medium, .large]) 적용 권장.

struct QuickRecordSheet: View {
    var mode: AppMode           // baby / pregnancy (MainTabView에 정의)
    var onSave: () -> Void = {}
    var onClose: () -> Void = {}

    @EnvironmentObject private var store: AppStore

    // MARK: Internal state
    @State private var showDetail = false
    @State private var savedOverlay = false
    /// 아무 것도 입력하지 않고 저장을 누르면 표시하는 안내 (성공 위장 금지 — 정직)
    @State private var showEmptyHint = false

    // 이정표 선택 (다중)
    @State private var selectedMilestones: Set<String> = []
    // 직접 입력한 이정표(이 기록 세션) + 입력 알럿 상태
    @State private var customMilestones: [String] = []
    @State private var showCustomMilestoneInput = false
    @State private var customMilestoneText = ""

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

    // 저장 완료 순간 — 실제 저장한 대상의 카운터·이름을 저장 시점에 캡처해 표시.
    // (selectedChild를 무조건 세면 형제·자매 저장/임신 모드에서 잘못된 수가 나옴.)
    @State private var savedMomentCount = 1
    @State private var savedDisplayName = "우리 아기"

    // 가족(조부모) 공유 — 저장 직후 공유 앨범에 추가할지 선택(마지막 선택 기억). 육아 모드 + 미디어 있을 때만.
    @AppStorage("bl_quickshare_family") private var shareToFamily = false
    @State private var showFamilyShare = false
    @State private var pendingShareURLs: [URL] = []
    @State private var showProUpsell = false   // 프리에서 가족공유 탭 시 Pro 안내

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
        // 가족 공유 시트 — 저장 직후 '공유 앨범에 추가'. 닫히면 기록 시트도 닫는다.
        .sheet(isPresented: $showFamilyShare, onDismiss: { onSave(); onClose() }) {
            QuickFamilyShareSheet(activityItems: pendingShareURLs)
        }
        // 프리에서 '가족과 공유' 탭 → Pro 안내 팝업.
        .sheet(isPresented: $showProUpsell) {
            ProUpsellSheet().environmentObject(store)
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
                    siblingSelector
                    if showDetail {
                        detailSection
                            .padding(.bottom, Spacing.s3)
                    }
                    familyShareToggle
                    saveButton
                        .padding(.top, Spacing.s2)
                    if showEmptyHint {
                        emptyHintRow
                            .padding(.top, Spacing.s2)
                    }
                    toggleDetailButton
                        .padding(.top, Spacing.s1)
                }
                .padding(.horizontal, Spacing.s5)
                .padding(.bottom, Spacing.s7)
            }
        }
        .background(AppColors.surface)
        // 사용자가 무언가 입력하면 안내를 즉시 해제 (더 이상 빈 저장이 아님)
        .onChange(of: hasMedia) { _ in clearEmptyHintIfNeeded() }
        .onChange(of: memo) { _ in clearEmptyHintIfNeeded() }
        .onChange(of: selectedMilestones) { _ in clearEmptyHintIfNeeded() }
        .onChange(of: heightText) { _ in clearEmptyHintIfNeeded() }
        .onChange(of: weightText) { _ in clearEmptyHintIfNeeded() }
    }

    private func clearEmptyHintIfNeeded() {
        guard showEmptyHint else { return }
        withAnimation(.easeInOut(duration: 0.2)) { showEmptyHint = false }
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

    // 임신 모드는 동영상을 받지 않는다(배사진 타임라인은 사진 전용 — 동영상 무단 누락 방지).
    private var allowsVideo: Bool { mode != .pregnancy }

    // 사진/동영상 드롭존 — 선택 시 스와이프 캐러셀, 미선택 시 드롭존
    @ViewBuilder
    private var photoDropZone: some View {
        let mediaHeight: CGFloat = showDetail ? 300 : 420
        Group {
            if hasMedia {
                mediaCarousel(height: mediaHeight)
            } else if allowsVideo {
                MediaPickerButton(maxImages: 5, images: $selectedImages, videoURL: $selectedVideoURL) {
                    dropZonePlaceholder(height: showDetail ? 150 : 210)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
            } else {
                // 임신 모드: 사진 전용 피커(동영상 미노출 → 무단 누락 없음)
                PhotosOnlyPickerButton(maxImages: 5, images: $selectedImages) {
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
                Group {
                    if allowsVideo {
                        MediaPickerButton(maxImages: 5, images: $selectedImages, videoURL: $selectedVideoURL) {
                            changeMediaLabel
                        }
                    } else {
                        PhotosOnlyPickerButton(maxImages: 5, images: $selectedImages) {
                            changeMediaLabel
                        }
                    }
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

    // "변경" 버튼 라벨 (사진/미디어 피커 공용)
    private var changeMediaLabel: some View {
        Label("변경", systemImage: "photo.on.rectangle")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).frame(height: 32)
            .background(.black.opacity(0.45), in: Capsule())
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
                VStack(spacing: 3) {
                    Text(photoPrompt)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(mode == .pregnancy ? "사진 (최대 5장)" : "사진·동영상 (최대 5장)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
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

    // 이정표 칩 가로 스크롤 (나이대 추천 + 직접 입력한 것 + '직접 입력' 추가 칩)
    private var milestoneRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(milestones) { item in
                    milestoneChip(item)
                }
                ForEach(customMilestones, id: \.self) { label in
                    milestoneChip(MilestoneItem(label: label, icon: "tag", iconFill: "tag.fill",
                                                color: Color(hex: 0x2E8B7A)))
                }
                addCustomChip
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.vertical, 2)
        }
        .padding(.horizontal, -Spacing.s5)   // 부모 패딩 상쇄 → 전폭 스크롤
        .alert("이정표 직접 입력", isPresented: $showCustomMilestoneInput) {
            TextField("예: 첫 김밥, 할머니댁 방문", text: $customMilestoneText)
            Button("추가") { addCustomMilestone() }
            Button("취소", role: .cancel) { customMilestoneText = "" }
        } message: { Text("이 기록에 붙일 이정표를 입력하세요.") }
    }

    // '직접 입력' 칩 — 점선 테두리로 추천 칩과 구분
    private var addCustomChip: some View {
        Button { Haptics.light(); showCustomMilestoneInput = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("직접 입력").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(AppColors.primary)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(AppColors.surface, in: Capsule())
            .overlay {
                Capsule().stroke(AppColors.primary.opacity(0.55),
                                 style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityLabel("이정표 직접 입력")
    }

    private func addCustomMilestone() {
        let t = customMilestoneText.trimmingCharacters(in: .whitespacesAndNewlines)
        customMilestoneText = ""
        guard !t.isEmpty else { return }
        if !customMilestones.contains(t), !milestones.contains(where: { $0.label == t }) {
            customMilestones.append(t)
        }
        selectedMilestones.insert(t)
        Haptics.success()
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

    /// Pro 가족 피드가 켜져 있고 로그인 상태인지 — 자동 게시 분기 기준.
    private var proFeedActive: Bool { store.isPro && AuthStore.shared.isLoggedIn }
    /// 가족 공유 토글 사용 가능 여부(=Pro). 프리는 비활성 + 탭 시 안내 팝업.
    private var familyShareEnabled: Bool { store.isPro }

    // 가족(조부모) 공유 토글 — 육아 모드 + 미디어 있을 때만.
    //  · Pro: 활성 — 저장 시 가족 피드에 자동 게시(기본 ON).
    //  · 프리: 비활성(회색) — 탭하면 Pro 안내 팝업.
    @ViewBuilder
    private var familyShareToggle: some View {
        if mode == .baby, hasMedia {
            HStack(spacing: Spacing.s3) {
                Image(systemName: familyShareEnabled ? "person.2.fill" : "lock.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(familyShareEnabled ? Color(hex: 0xB5478A) : AppColors.ink3)
                    .frame(width: 34, height: 34)
                    .background((familyShareEnabled ? Color(hex: 0xFBEAF0) : AppColors.surface3),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text("가족과 공유")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(familyShareEnabled ? AppColors.ink : AppColors.ink2)
                        if !familyShareEnabled {
                            Text("Pro").font(.system(size: 10, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(AppColors.primary, in: Capsule())
                        }
                    }
                    Text(familyShareEnabled
                         ? (proFeedActive ? "가족 보관함에 자동 게시 (하트·댓글로 함께)" : "로그인하면 가족과 함께 봐요")
                         : "조부모님과 함께 보고 하트·댓글 — Pro에서 열려요")
                        .font(.system(size: 12, weight: .regular)).foregroundStyle(AppColors.ink3)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $shareToFamily).labelsHidden().tint(AppColors.primary)
                    .disabled(!familyShareEnabled)
            }
            // Pro(로그인)면 기본 ON — "기록하면 가족과 자동 공유". 사용자가 끄면 그 기록만 비공개.
            .onAppear {
                if proFeedActive, !UserDefaults.standard.bool(forKey: "bl_quickshare_family_proinit") {
                    shareToFamily = true
                    UserDefaults.standard.set(true, forKey: "bl_quickshare_family_proinit")
                }
            }
            // 프리: 행 전체 탭 → Pro 안내 팝업(토글 자체는 비활성).
            .contentShape(Rectangle())
            .onTapGesture { if !familyShareEnabled { Haptics.light(); showProUpsell = true } }
            .padding(.horizontal, Spacing.s3).padding(.vertical, Spacing.s2)
            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .padding(.top, Spacing.s3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(familyShareEnabled
                ? "가족과 공유. \(shareToFamily ? "켜짐" : "꺼짐")"
                : "가족과 공유. Pro 기능. 탭하면 안내를 봅니다.")
            .accessibilityAddTraits(familyShareEnabled ? .isToggle : .isButton)
        }
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

    // 입력 없이 저장 시 부드러운 안내 (성공 위장 대신 — 정직 원칙)
    private var emptyHintRow: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text(mode == .pregnancy ? "배 사진이나 메모를 추가해 주세요" : "사진이나 메모를 추가해 주세요")
                .font(AppFont.caption)
                .foregroundStyle(AppColors.ink2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s2)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
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
            // 앱 아이콘·스플래시와 같은 크림 라디얼 — 기록이 담기는 순간에 브랜드 세계관 재등장.
            RadialGradient(gradient: Gradient(colors: [AppColors.brandCreamHi, AppColors.brandCreamLo]),
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: Spacing.s4) {
                // 흰 원판 + 금색 링(아이콘과 동일) 안에 하트 — 팝 애니메이션
                ZStack {
                    Circle().fill(Color.white).frame(width: 80, height: 80)
                    Circle()
                        .stroke(LinearGradient(colors: [AppColors.brandRingTop, AppColors.brandRingBot],
                                               startPoint: .top, endPoint: .bottom), lineWidth: 2.5)
                        .frame(width: 80, height: 80)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                }
                .popAnimation()

                Text("\(savedDisplayName)의 \(savedMomentCount)번째 순간")
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
        .accessibilityLabel("\(savedDisplayName)의 \(savedMomentCount)번째 순간이 저장되었습니다")
    }

    // MARK: - Actions

    // 임신 모드 저장: 배 사진 → 활성 임신 배사진 타임라인, 산모 체중 → 체중 기록.
    // 반환값: 실제로 무언가 저장되었으면 true (성공 위장 방지용).
    @discardableResult
    private func savePregnancyRecord() -> Bool {
        guard let preg = store.activePregnancy else { return false }
        var savedAnything = false
        let week = AgeCalculator.pregnancyWeeks(lmp: preg.lmpDate, edd: preg.eddDate, asOf: Date())?.weeks ?? 0
        for img in selectedImages {
            if let ref = PhotoStore.save(img) {
                store.addBellyPhoto(pregnancyId: preg.id, week: week, photoRef: ref)
                savedAnything = true
            }
        }
        if let w = blDecimal(weightText), w > 0 {
            store.addPregnancyWeight(pregnancyId: preg.id, kg: w)
            savedAnything = true
        }
        // 메모 저장 (손실 방지) — 선택한 이정표가 있으면 메모 앞에 합쳐 함께 보존
        let trimmedMemo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let milestoneText = selectedMilestones.isEmpty
            ? nil
            : selectedMilestones.sorted().joined(separator: ", ")
        let combinedMemo: String? = {
            switch (milestoneText, trimmedMemo.isEmpty) {
            case let (ms?, false): return "\(ms) · \(trimmedMemo)"
            case let (ms?, true):  return ms
            case (nil, false):     return trimmedMemo
            case (nil, true):      return nil
            }
        }()
        if let combinedMemo {
            store.addPregnancyMemo(pregnancyId: preg.id, text: combinedMemo)
            savedAnything = true
        }
        return savedAnything
    }

    private func handleSave() {
        // 이 저장으로 실제 무언가가 기록되었는지 추적 (성공 위장 금지 — 정직 원칙)
        var didSave = false
        // Pro 가족 피드 자동 공유용 캡처(육아 모드 + 사진 + 공유 ON + 로그인일 때만 채움)
        var feedImages: [UIImage] = []
        var feedCaption: String? = nil
        var feedChild: String? = nil
        var feedPostId: String? = nil   // 기록 entry.id == 피드 post id (양쪽 연결)

        if mode == .pregnancy {
            // 임신 모드: 배 사진 + 산모 체중을 활성 임신 기록에 저장
            didSave = savePregnancyRecord()
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
                var shareURLs: [URL] = []
                var firstEntryId: UUID? = nil   // 가족 피드 포스트 id로 연결(기록↔피드 동일 id)
                for tid in targetIds {
                    let refs = selectedImages.compactMap { PhotoStore.save($0) }
                    let videoFile = selectedVideoURL.flatMap { PhotoStore.saveVideo(from: $0) }
                    // 사진 저장이 모두 실패(디스크 오류 등)하고 메모·이정표도 없으면 빈 기록을
                    // 만들지 않는다 — 성공 위장·쓰레기 기록 방지(정직 원칙).
                    guard content != nil || milestoneText != nil || !refs.isEmpty || videoFile != nil else { continue }
                    // 가족 공유용 파일 URL은 첫 번째 아이 사본 기준으로 1세트만 수집(중복 공유 방지)
                    if shareURLs.isEmpty {
                        shareURLs = refs.map { PhotoStore.photosDirectory.appendingPathComponent($0) }
                        if let vf = videoFile { shareURLs.append(PhotoStore.photosDirectory.appendingPathComponent(vf)) }
                    }
                    let newId = store.addDiaryEntry(
                        childId:   tid,
                        content:   content,
                        milestone: milestoneText,
                        photoRef:  refs.first,
                        photoRefs: refs,
                        videoRef:  videoFile
                    )
                    if firstEntryId == nil { firstEntryId = newId }
                    didSave = true
                }
                pendingShareURLs = (shareToFamily && hasMedia) ? shareURLs : []
                // Pro + 로그인 + 사진 공유 ON → 이 기록의 사진을 가족 피드(서버)로 자동 게시할 준비.
                // 피드 포스트 id = 기록 entry.id → 타임라인 카드가 같은 id로 가족 하트·댓글을 불러옴.
                if shareToFamily, !selectedImages.isEmpty, store.isPro,
                   AuthStore.shared.isLoggedIn, let linkId = firstEntryId {
                    feedImages = selectedImages
                    feedChild = store.selectedChild?.name
                    feedPostId = linkId.uuidString
                    store.markFeedShared(linkId.uuidString)   // 즉시 '공유 중' 표시(업로드 완료 전)
                    feedCaption = {
                        switch (milestoneText, trimmedMemo.isEmpty) {
                        case let (ms?, false): return "\(ms) · \(trimmedMemo)"
                        case let (ms?, true):  return ms
                        case (nil, false):     return trimmedMemo
                        case (nil, true):      return nil
                        }
                    }()
                }
            }
            // 키·몸무게 입력값이 하나라도 있으면 GrowthRecord 기록
            // (showDetail 여부가 아니라 실제 입력 여부로 판단 — 상세를 접어도 입력값 누락 없음)
            let heightVal = blDecimal(heightText)
            let weightVal = blDecimal(weightText)
            if heightVal != nil || weightVal != nil {
                store.addGrowthRecord(
                    childId:             childId,
                    heightCm:            heightVal,
                    weightKg:            weightVal,
                    headCircumferenceCm: nil
                )
                didSave = true
            }
        } else {
            onSave(); onClose(); return
        }

        // 아무 것도 입력하지 않았으면 성공 피드백을 위장하지 않고 부드럽게 안내 (정직)
        guard didSave else {
            Haptics.warning()
            withAnimation(.easeInOut(duration: 0.2)) {
                showEmptyHint = true
            }
            return
        }

        // 실제 저장한 대상 기준으로 보상 오버레이 문구를 캡처 (selectedChild 고정 카운트 버그 방지)
        if mode == .pregnancy {
            savedDisplayName = store.activePregnancy?.nickname ?? "우리 아기"
            if let pid = store.activePregnancy?.id {
                savedMomentCount = max(1, store.bellyPhotos(pregnancyId: pid).count)
            } else {
                savedMomentCount = 1
            }
        } else if let target = store.selectedChild {
            savedDisplayName = target.name
            savedMomentCount = max(1, store.diaryEntries(for: target.id).count)
        }

        // 1탭: 저장 버튼 탭 → 보상 오버레이 표시 (+ 성공 햅틱)
        Haptics.success()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
            savedOverlay = true
        }
        // 2탭(1.6s): 오버레이 표시 후 —
        //  · Pro(로그인): 이 기록 사진을 가족 피드(서버)로 백그라운드 자동 게시 → 바로 닫기.
        //  · 무료: 기존 iCloud 공유 앨범 시트.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            if !feedImages.isEmpty {
                let imgs = feedImages, cap = feedCaption, child = feedChild, pid = feedPostId
                Task {
                    let ok = await FamilyFeedBackend.shareRecordToFamily(postId: pid, images: imgs, caption: cap, childLabel: child)
                    await MainActor.run {
                        if ok { store.familyFeedVersion += 1 }                 // 타임라인 가족 반응 재로드
                        else if let pid { store.unmarkFeedShared(pid) }        // 실패 시 '공유 중' 해제 → 버튼 복귀
                    }
                }
                onSave()
                onClose()
            } else if mode == .baby, shareToFamily, !pendingShareURLs.isEmpty {
                showFamilyShare = true   // 닫기는 공유 시트 onDismiss에서
            } else {
                onSave()
                onClose()
            }
        }
    }
}

// MARK: - 사진 전용 피커 버튼 (임신 모드 — 동영상 미노출)
// 임신 배사진 타임라인은 사진만 저장하므로, 동영상을 아예 선택지에 노출하지 않아
// 사용자가 고른 동영상이 조용히 누락되는 일을 원천 차단한다.
private struct PhotosOnlyPickerButton<Label: View>: View {
    var maxImages: Int = 5
    @Binding var images: [UIImage]
    @ViewBuilder var label: () -> Label

    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(
            selection: $items,
            maxSelectionCount: maxImages,
            matching: .images,
            photoLibrary: .shared()
        ) {
            label()
        }
        .onChange(of: items) { _, newItems in
            Task { await load(newItems) }
        }
    }

    private func load(_ newItems: [PhotosPickerItem]) async {
        var imgs: [UIImage] = []
        for item in newItems where imgs.count < maxImages {
            if let data = try? await item.loadTransferable(type: Data.self),
               let ui = await blDownsample(data: data) {
                imgs.append(ui)
            }
        }
        let finalImgs = imgs
        await MainActor.run { images = finalImgs }
    }
}

// MARK: - 가족 공유 시트 (저장 직후 '공유 앨범에 추가')
private struct QuickFamilyShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
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

// 육아 모드 이정표 — 아이 월령에 맞춰 노출(나이대별 다양하게 + '직접 입력'은 칩에서 별도 제공)
private func babyMilestones(months: Int) -> [MilestoneItem] {
    let palette = [AppColors.primary, Color(hex: 0x5B53B0), Color(hex: 0x3B6FA8),
                   Color(hex: 0xB45840), Color(hex: 0x2E8B7A), Color(hex: 0x98711E)]
    func make(_ pairs: [(String, String)]) -> [MilestoneItem] {
        pairs.enumerated().map { idx, p in
            MilestoneItem(label: p.0, icon: p.1, iconFill: p.1, color: palette[idx % palette.count])
        }
    }
    switch months {
    case 0..<4:
        return make([("첫 웃음", "face.smiling"), ("눈맞춤", "eye"), ("목 가누기", "figure.stand"),
                     ("배냇짓", "sparkles"), ("첫 외출", "stroller"), ("첫 목욕", "drop"),
                     ("첫 예방접종", "cross.case"), ("손 빨기", "hand.raised"), ("첫 사진", "camera"),
                     ("백일", "birthday.cake")])
    case 4..<7:
        return make([("뒤집기", "arrow.2.circlepath"), ("옹알이", "bubble.left"), ("이유식 시작", "fork.knife"),
                     ("손 뻗기", "hand.raised"), ("발 잡기", "figure.seated.side"), ("첫 이앓이", "mouth"),
                     ("소리내 웃기", "speaker.wave.2"), ("장난감 쥐기", "cube"), ("까꿍 반응", "face.smiling"),
                     ("첫 외식", "fork.knife.circle")])
    case 7..<10:
        return make([("혼자 앉기", "figure.seated.side"), ("기어다니기", "figure.walk.motion"), ("첫 이", "mouth"),
                     ("짝짜꿍", "hands.clap"), ("까꿍 놀이", "face.smiling"), ("손가락 음식", "fork.knife"),
                     ("이름에 반응", "ear"), ("물건 옮기기", "hand.raised"), ("낯가림", "face.dashed"),
                     ("잡고 서기 시도", "figure.stand")])
    case 10..<13:
        return make([("잡고 서기", "figure.stand"), ("첫 단어", "bubble.left.fill"), ("첫 걸음마", "figure.walk"),
                     ("박수", "hands.clap"), ("빠이빠이", "hand.wave"), ("컵 잡기", "cup.and.saucer"),
                     ("가리키기", "hand.point.up"), ("혼자 서기", "figure.stand"), ("첫 신발", "shoe"),
                     ("첫 생일(돌)", "birthday.cake")])
    case 13..<19:
        return make([("걸음마", "figure.walk"), ("새 단어", "bubble.left.fill"), ("컵으로 마시기", "cup.and.saucer"),
                     ("끄적이기", "scribble"), ("계단 오르기", "figure.stairs"), ("블록 쌓기", "cube"),
                     ("숟가락 시도", "fork.knife"), ("그림책 보기", "book"), ("춤추기", "music.note"),
                     ("신체 부위 알기", "figure.stand")])
    case 19..<25:
        return make([("뛰기", "figure.run"), ("두 단어 문장", "text.bubble"), ("숟가락 사용", "fork.knife"),
                     ("신발 신기", "shoe"), ("공 차기", "soccerball"), ("색칠 시도", "paintbrush"),
                     ("양치 시도", "mouth"), ("이름 말하기", "person"), ("계단 내려가기", "figure.stairs"),
                     ("옷 벗기", "tshirt")])
    case 25..<37:
        return make([("대소변 가리기", "toilet"), ("세 단어 문장", "text.bubble.fill"), ("친구와 놀기", "person.2.fill"),
                     ("색칠하기", "paintbrush"), ("점프", "figure.run"), ("가위질 시도", "scissors"),
                     ("숫자 세기", "number"), ("색깔 알기", "paintpalette"), ("혼자 옷 입기", "tshirt"),
                     ("세발자전거", "bicycle")])
    default:
        return make([("어린이집/유치원", "building.2"), ("세발자전거", "bicycle"), ("가위질", "scissors"),
                     ("한글 관심", "textformat.abc"), ("숫자 쓰기", "number"), ("그림 그리기", "paintbrush"),
                     ("줄넘기", "figure.jumprope"), ("친구 사귀기", "person.2.fill"), ("노래 부르기", "music.mic"),
                     ("질문 많아짐", "questionmark.bubble"), ("혼자 화장실", "toilet"), ("받아쓰기", "pencil.and.outline")])
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
    MilestoneItem(label: "태명 짓기",    icon: "sparkles",                 iconFill: "sparkles",                     color: Color(hex: 0x2E8B7A)),
    MilestoneItem(label: "태교 음악",    icon: "music.note",               iconFill: "music.note",                   color: AppColors.pregnancyPink),
    MilestoneItem(label: "출산 준비물",  icon: "bag",                      iconFill: "bag.fill",                     color: Color(hex: 0x3B6FA8)),
    MilestoneItem(label: "부모 교실",    icon: "person.2",                 iconFill: "person.2.fill",                color: Color(hex: 0x5B53B0)),
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
