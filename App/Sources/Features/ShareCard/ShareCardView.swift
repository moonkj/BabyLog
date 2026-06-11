// ShareCardView.swift
// BabyLog · 성장 카드 공유 에디터 (기능 2.4)
// Swift5 / iOS 17 / SwiftUI + UIKit
// 새 파일 전용 — 기존 파일 무수정

import SwiftUI
import UIKit

// MARK: - Supporting Types

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
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.month], from: child.birthDate, to: Date())
        return max(0, comps.month ?? 0)
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

    // 공유 시트
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false
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

                    // ── 공유 버튼 ─────────────────────────────────────────────
                    shareButton
                        .padding(.horizontal, Spacing.s5)
                        .padding(.top, Spacing.s5)

                    viralCaption
                        .padding(.bottom, Spacing.s9)
                }
            }
        }
        .navigationTitle("성장 카드")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareActivityView(image: img)
            }
        }
        .alert("공유 카드", isPresented: $showRenderError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("카드를 만들지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        let h = previewWidth / vm.aspect.ratio
        return VStack(spacing: Spacing.s4) {
            // 카드 미리보기
            ZStack {
                ShareCardCanvas(vm: vm)
                    .frame(width: previewWidth, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                    .blShadow(.card)
            }

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
                DarkChip(text: "또래 백분위", isOn: vm.fields.percentile) {
                    vm.fields.percentile.toggle()
                }
                DarkChip(text: "이정표", isOn: vm.fields.milestone) {
                    vm.fields.milestone.toggle()
                }
            }

            // 프라이버시
            privacySection
        }
    }

    private var privacySection: some View {
        VStack(spacing: 0) {
            DarkToggleRow(
                label: "얼굴 가리기",
                subtitle: "블러로 비공개",
                systemIcon: "person.crop.circle.badge.xmark",
                isOn: $vm.faceBlur
            )

            Divider()
                .background(AppColors.line)
                .padding(.horizontal, Spacing.s4)

            // 워터마크: 자유 토글(전면 무료). 기본 ON은 자연 바이럴용.
            DarkToggleRow(
                label: "워터마크",
                subtitle: vm.watermark ? "BabyLog 로고 표시" : "로고 없음",
                systemIcon: "sparkles",
                isOn: Binding(
                    get: { vm.watermark },
                    set: { vm.watermark = $0 }
                )
            )
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(.top, Spacing.s2)
    }

    private var shareButton: some View {
        LiquidButton(fill: AppColors.primary, action: handleShare) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                Text("공유하기")
            }
        }
    }

    private var viralCaption: some View {
        Text("워터마크가 곧 자연 바이럴이 돼요.\n친구가 보고 \"이 앱 뭐야?\" → 동네 유입")
            .font(AppFont.micro)
            .multilineTextAlignment(.center)
            .foregroundStyle(AppColors.ink3)
            .padding(.top, Spacing.s3)
    }

    // MARK: - Actions

    private func handleShare() {
        if let img = vm.renderCard() {
            shareImage = img
            showShareSheet = true
        } else {
            // 렌더 실패: 조용히 넘어가지 않고 사용자에게 안내
            Haptics.warning()
            showRenderError = true
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
