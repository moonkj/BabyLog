// ShareCardView.swift
// BabyLog · 성장 카드 공유 에디터 (기능 2.4)
// Swift5 / iOS 17 / SwiftUI + UIKit
// 새 파일 전용 — 기존 파일 무수정

import SwiftUI
import UIKit
import Photos

// MARK: - Supporting Types

/// 공유 시트 표시용 — UIImage를 Identifiable로 감싸 .sheet(item:)에서 렌더 완료본만 표시.
struct ShareImageItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 카드 비율 옵션
enum CardAspect: String, CaseIterable {
    case fourFive = "4:5"
    case oneOne   = "1:1"
    case nineSixteen = "9:16"

    var ratio: CGFloat {
        switch self {
        case .fourFive:    return 4.0 / 5.0
        case .oneOne:      return 1.0
        case .nineSixteen: return 9.0 / 16.0
        }
    }
}

/// 데이터 오버레이 위치
enum DataPosition: String, CaseIterable {
    case bottomLeft  = "좌하"
    case bottomRight = "우하"
    case topLeft     = "좌상"
    case bottomCenter = "중하"
    case none        = "없음"
}

/// 표시할 데이터 필드 집합
struct ShareCardFields {
    var height:     Bool = true
    var weight:     Bool = true
    var monthAge:   Bool = true
    var percentile: Bool = false
    var milestone:  Bool = false
}

// MARK: - ViewModel

@MainActor
final class ShareCardViewModel: ObservableObject {
    // 편집 대상
    let child: Child
    let record: GrowthRecord?
    let milestoneText: String?

    // 컨트롤 상태
    @Published var aspect: CardAspect = .fourFive
    @Published var position: DataPosition = .bottomLeft
    @Published var fields: ShareCardFields = ShareCardFields()
    // 얼굴 가리기 토글 제거(off 고정). 워터마크는 토글 제거 + **항상 ON**(BabyLog 로고 무조건 표시 — 사용자 요청 2026-06-15).
    @Published var faceBlur: Bool = false
    @Published var watermark: Bool = true

    // 배경 사진 (로컬 전용 — 서버 미전송, CLAUDE.md 절대원칙)
    @Published var backgroundPhoto: UIImage? = nil

    init(child: Child, record: GrowthRecord? = nil, milestoneText: String? = nil) {
        self.child = child
        self.record = record
        self.milestoneText = milestoneText
    }

    // MARK: - Computed Helpers

    var monthAge: Int {
        // 앱 전역과 동일 기준(AgeCalculator) — 월 경계에서 기록/홈 화면과 'N개월'이 어긋나지 않게.
        AgeCalculator.childAgeMonths(birthDate: child.birthDate, asOf: Date()).months
    }

    var dDay: Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.day], from: child.birthDate, to: Date())
        return max(0, (comps.day ?? 0) + 1)
    }

    var heightText: String? {
        guard let h = record?.heightCm else { return nil }
        return String(format: "%.1f cm", h)
    }

    var weightText: String? {
        guard let w = record?.weightKg else { return nil }
        return String(format: "%.2f kg", w)
    }

    // MARK: - ImageRenderer

    /// WYSIWYG 카드 뷰를 UIImage로 렌더 (scale = 3x, 미리보기와 동일 콘텐츠).
    /// 얼굴 블러·워터마크·위치·필드 설정 모두 반영됨.
    func renderCard() -> UIImage? {
        let cardWidth: CGFloat = 1080
        let cardHeight: CGFloat = cardWidth / aspect.ratio
        let card = ShareCardCanvas(vm: self)
            .frame(width: cardWidth, height: cardHeight)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Main View

struct ShareCardView: View {
    @StateObject private var vm: ShareCardViewModel

    init(child: Child, record: GrowthRecord? = nil, milestoneText: String? = nil) {
        _vm = StateObject(wrappedValue: ShareCardViewModel(
            child: child,
            record: record,
            milestoneText: milestoneText
        ))
    }

    // 공유 시트 — item 기반(렌더 완료 후 표시: 첫 탭 흰 화면 방지)
    @State private var shareItem: ShareImageItem? = nil
    // 사진 저장 결과 알림
    @State private var saveMessage: String? = nil
    // 렌더 실패 알림
    @State private var showRenderError = false

    // 배경 사진 선택 (vm.backgroundPhoto와 동기)
    // PhotoPickerButton의 @Binding을 vm.backgroundPhoto에 직접 연결하기 위한 래퍼
    private var backgroundPhotoBinding: Binding<UIImage?> {
        Binding(
            get: { vm.backgroundPhoto },
            set: { vm.backgroundPhoto = $0 }
        )
    }

    private let editorBg = AppColors.canvas
    private let previewWidth: CGFloat = 300

    var body: some View {
        ZStack {
            editorBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── 미리보기 ──────────────────────────────────────────────
                    previewSection

                    // ── 컨트롤 패널 ──────────────────────────────────────────
                    controlsSection
                        .padding(.horizontal, Spacing.s5)

                    // ── 한 줄: 저장(폭 크게) + 공유(폭 작게), 높이 동일 ──────────
                    HStack(spacing: Spacing.s3) {
                        saveButton              // 폭 가변(넓게)
                        shareButton             // 폭 고정(좁게)
                    }
                    .padding(.horizontal, Spacing.s5)
                    .padding(.top, Spacing.s5)
                    .padding(.bottom, Spacing.s9)
                }
            }
        }
        .navigationTitle("성장 카드")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareActivityView(image: item.image)
        }
        .alert("공유 카드", isPresented: $showRenderError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("카드를 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        .alert("사진 저장", isPresented: Binding(
            get: { saveMessage != nil }, set: { if !$0 { saveMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: { Text(saveMessage ?? "") }
    }

    // MARK: - Sections

    private var previewSection: some View {
        let h = previewWidth / vm.aspect.ratio
        return VStack(spacing: Spacing.s4) {
            // 카드 미리보기 (편집 캔버스 — 얇은 테두리로 영역 명확화)
            ShareCardCanvas(vm: vm)
                .frame(width: previewWidth, height: h)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .strokeBorder(AppColors.line, lineWidth: 1)
                }
                .blShadow(.card)
                .animation(.easeInOut(duration: 0.2), value: vm.aspect)

            // 배경 사진 변경 버튼 (PhotoPickerButton 연결)
            PhotoPickerButton(image: backgroundPhotoBinding) {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: vm.backgroundPhoto == nil
                          ? "photo.on.rectangle.angled"
                          : "photo.badge.arrow.down.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(vm.backgroundPhoto == nil ? "배경 사진 선택" : "배경 사진 변경")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(vm.backgroundPhoto == nil
                                 ? AppColors.ink2
                                 : AppColors.primary)
                .padding(.horizontal, Spacing.s5)
                .frame(height: 44)   // 44pt 터치영역
                .background(
                    vm.backgroundPhoto == nil
                        ? AppColors.surface2
                        : AppColors.primary.opacity(0.12),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            vm.backgroundPhoto == nil
                                ? AppColors.line
                                : AppColors.primary.opacity(0.4),
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.96))
            .accessibilityLabel(vm.backgroundPhoto == nil ? "배경 사진 선택" : "배경 사진 변경")
            .accessibilityHint("탭하여 사진 라이브러리에서 카드 배경 사진을 선택합니다")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s5)
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            // 비율
            DarkControlGroup(label: "비율") {
                ForEach(CardAspect.allCases, id: \.self) { a in
                    DarkChip(text: a.rawValue, isOn: vm.aspect == a) {
                        withAnimation(.easeOut(duration: 0.15)) { vm.aspect = a }
                    }
                }
            }

            // 데이터 위치
            DarkControlGroup(label: "데이터 위치") {
                ForEach(DataPosition.allCases, id: \.self) { p in
                    DarkChip(text: p.rawValue, isOn: vm.position == p) {
                        withAnimation(.easeOut(duration: 0.15)) { vm.position = p }
                    }
                }
            }

            // 표시할 데이터
            DarkControlGroup(label: "표시할 데이터") {
                DarkChip(text: "키", isOn: vm.fields.height) {
                    vm.fields.height.toggle()
                }
                DarkChip(text: "몸무게", isOn: vm.fields.weight) {
                    vm.fields.weight.toggle()
                }
                DarkChip(text: "월령·D+day", isOn: vm.fields.monthAge) {
                    vm.fields.monthAge.toggle()
                }
                // '또래 백분위' 칩 제거 — 실제 백분위 데이터가 없어 카드에 가짜 '상위 N%'가 찍히던 문제(정직·또래비교 원칙).
                //   실데이터(WHO 밴드 기반) 연동 시 안심 톤으로 복원.
                // '이정표' 칩 제거(사용자 요청, 2026-06-15).
            }
        }
    }


    /// 사진으로 저장 — 주 동작(폭 넓게, 높이 52).
    private var saveButton: some View {
        LiquidButton(fill: AppColors.primary, action: handleSaveToPhotos) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18, weight: .bold))
                Text("사진으로 저장")
                    .font(.system(size: 16.5, weight: .bold))
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
    }

    /// 공유하기 — 보조 동작(폭 좁게, 높이 52로 동일).
    private var shareButton: some View {
        Button(action: handleShare) {
            HStack(spacing: 6) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text("공유")
                    .font(.system(size: 14.5, weight: .semibold))
            }
            .foregroundStyle(AppColors.ink2)
            .frame(width: 96, height: 52)
            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
    }

    // MARK: - Actions

    private func handleShare() {
        if let img = vm.renderCard() {
            shareItem = ShareImageItem(image: img)   // .sheet(item:) → 렌더 완료본만 표시(첫 탭 흰 화면 방지)
        } else {
            Haptics.warning()
            showRenderError = true
        }
    }

    /// 카드를 사진 앱에 저장(addOnly 권한). 성공·실패·권한거부를 알림으로 안내.
    private func handleSaveToPhotos() {
        guard let img = vm.renderCard() else { Haptics.warning(); showRenderError = true; return }
        Task {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                await MainActor.run { saveMessage = "사진 저장 권한이 필요해요. 설정 → BabyLog → 사진에서 허용해 주세요." }
                return
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                }
                await MainActor.run { Haptics.success(); saveMessage = "사진 앱에 저장했어요." }
            } catch {
                await MainActor.run { Haptics.warning(); saveMessage = "저장하지 못했어요. 잠시 후 다시 시도해 주세요." }
            }
        }
    }
}

// MARK: - UIActivityViewController Wrapper

/// 팀장이 연결할 공유 시트 (여기선 UIImage 전달용 래퍼만 제공)
struct ShareActivityView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#if DEBUG
#Preview("ShareCard — 4:5") {
    let child = Child(
        name: "아인",
        birthDate: Calendar.current.date(byAdding: .month, value: -8, to: Date()) ?? Date(),
        gender: .girl
    )
    let record = GrowthRecord(
        childId: child.id,
        date: Date(),
        heightCm: 68.5,
        weightKg: 8.12
    )
    NavigationStack {
        ShareCardView(child: child, record: record, milestoneText: "첫 걸음마")
    }
}

#Preview("ShareCard — 1:1 · 블러") {
    let child = Child(
        name: "준서",
        birthDate: Calendar.current.date(byAdding: .month, value: -14, to: Date()) ?? Date(),
        gender: .boy
    )
    NavigationStack {
        ShareCardView(child: child, milestoneText: nil)
    }
}
#endif
