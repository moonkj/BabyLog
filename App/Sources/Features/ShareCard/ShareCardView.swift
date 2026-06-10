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

    // Pro 상태 (팀장 주입 예정 — 현재는 false 고정)
    let isPro: Bool = false

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

    private let editorBg = Color(hex: 0x15110E)
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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareActivityView(image: img)
            }
        }
    }

    // MARK: - Sections

    private var previewSection: some View {
        let h = previewWidth / vm.aspect.ratio
        return ZStack {
            ShareCardCanvas(vm: vm)
                .frame(width: previewWidth, height: h)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
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
                .background(Color.white.opacity(0.08))
                .padding(.horizontal, Spacing.s4)

            // 워터마크: 무료는 항상 ON (잠금 표시), Pro는 토글 가능
            DarkToggleRow(
                label: "워터마크",
                subtitle: vm.watermark
                    ? "BabyLog 로고 표시 (무료)"
                    : "Pro · 로고 제거됨",
                systemIcon: "sparkles",
                isOn: Binding(
                    get: { vm.watermark },
                    set: { newVal in
                        if vm.isPro { vm.watermark = newVal }
                        // 무료: 토글 불가 (잠금 유지)
                    }
                ),
                isPro: !vm.isPro,   // 무료 사용자에게 PRO 뱃지 표시
                locked: !vm.isPro   // 잠금 아이콘
            )
        }
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
            .foregroundStyle(Color.white.opacity(0.4))
            .padding(.top, Spacing.s3)
    }

    // MARK: - Actions

    private func handleShare() {
        let img = vm.renderCard()
        shareImage = img
        showShareSheet = img != nil
    }
}

// MARK: - Card Canvas (WYSIWYG & Render 공용)

/// 미리보기와 ImageRenderer 렌더링에 모두 사용되는 카드 뷰.
/// 크기는 외부 frame()으로 주입.
struct ShareCardCanvas: View {
    @ObservedObject var vm: ShareCardViewModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .topLeading) {
                // ── 배경: PhotoPlaceholder ──────────────────────────────
                photoLayer(w: w, h: h)

                // ── 그라데이션 스크림 ────────────────────────────────────
                scrimLayer(position: vm.position)

                // ── 데이터 오버레이 ──────────────────────────────────────
                if vm.position != .none {
                    dataOverlay(w: w, h: h)
                }

                // ── 우상단 워터마크 ──────────────────────────────────────
                if vm.watermark {
                    watermarkBadge
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }

    // MARK: - Layers

    private func photoLayer(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // 사진 플레이스홀더 (실제 사진은 팀장이 profileImageRef로 교체 연결)
            PhotoPlaceholder(seed: abs(vm.child.name.hashValue) % 6, cornerRadius: 0)

            // 얼굴 블러: 중앙 상단 영역에 frosted-glass 원형 마스크
            if vm.faceBlur {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: min(w, h) * 0.28, height: min(w, h) * 0.28)
                    .overlay {
                        Text("😊")
                            .font(.system(size: min(w, h) * 0.10))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .offset(y: h * 0.15)
            }
        }
    }

    private func scrimLayer(position: DataPosition) -> some View {
        let isTop = position == .topLeft
        let gradient = LinearGradient(
            stops: isTop
                ? [
                    .init(color: .black.opacity(0.60), location: 0.0),
                    .init(color: .clear,               location: 0.45)
                  ]
                : [
                    .init(color: .clear,               location: 0.45),
                    .init(color: .black.opacity(0.65), location: 1.0)
                  ],
            startPoint: .top,
            endPoint: .bottom
        )
        return gradient
    }

    @ViewBuilder
    private func dataOverlay(w: CGFloat, h: CGFloat) -> some View {
        let alignment: Alignment = {
            switch vm.position {
            case .bottomLeft:   return .bottomLeading
            case .bottomRight:  return .bottomTrailing
            case .topLeft:      return .topLeading
            case .bottomCenter: return .bottom
            case .none:         return .bottom
            }
        }()

        let textAlign: TextAlignment = {
            switch vm.position {
            case .bottomRight:  return .trailing
            case .bottomCenter: return .center
            default:            return .leading
            }
        }()

        let hAlign: HorizontalAlignment = {
            switch vm.position {
            case .bottomRight:  return .trailing
            case .bottomCenter: return .center
            default:            return .leading
            }
        }()

        VStack(alignment: hAlign, spacing: 6) {
            // 이정표 캡슐
            if vm.fields.milestone, let ms = vm.milestoneText {
                Text(ms)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.22))
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Capsule())
            }

            // 이름
            Text(vm.child.name)
                .font(.system(size: w * 0.077, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(textAlign)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // 수치 행
            dataStatsRow(textAlign: textAlign, hAlign: hAlign)
        }
        .padding(Spacing.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    @ViewBuilder
    private func dataStatsRow(textAlign: TextAlignment, hAlign: HorizontalAlignment) -> some View {
        let items: [String] = buildStatItems()
        if !items.isEmpty {
            FlexRow(items: items, hAlign: hAlign) { item in
                Text(item)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
    }

    private func buildStatItems() -> [String] {
        var result: [String] = []
        if vm.fields.monthAge {
            result.append("\(vm.monthAge)개월 · D+\(vm.dDay)")
        }
        if vm.fields.height, let h = vm.heightText {
            result.append(h)
        }
        if vm.fields.weight, let w = vm.weightText {
            result.append(w)
        }
        if vm.fields.percentile {
            result.append("상위 42%")  // 팀장이 실제 백분위 API로 교체
        }
        return result
    }

    // MARK: - Watermark

    private var watermarkBadge: some View {
        HStack(spacing: 4) {
            // BabyLog 하트 글리프 (SF Symbol 근사)
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: 16, height: 16)
                Image(systemName: "heart.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("BabyLog")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Dark Control Sub-Views

private struct DarkControlGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.5))

            _WrappingHStack(spacing: 7, content: content)
        }
    }
}

/// 자동 줄바꿈 HStack (Chip 목록용)
private struct _WrappingHStack<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        // iOS 17 이상: ViewThatFits 사용 불가 패턴, Layout 커스텀 대신 간단 flow 구현
        _FlowLayout(spacing: spacing, content: content)
    }
}

private struct _FlowLayout<Content: View>: Layout, View {
    var spacing: CGFloat

    @ViewBuilder var content: () -> Content

    // Layout 프로토콜 구현
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? UIScreen.main.bounds.width - 40
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowH: CGFloat = 0
        var totalH: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                y += rowH + spacing
                x = 0
                rowH = 0
                totalH = y
            }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        totalH += rowH
        return CGSize(width: maxW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowH: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > maxW, x > bounds.minX {
                y += rowH + spacing
                x = bounds.minX
                rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }

    // View 프로토콜 (자기 자신을 Layout 컨테이너로 사용)
    var body: some View {
        AnyLayout(self) { content() }
    }
}

private struct DarkChip: View {
    let text: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(isOn ? Color(hex: 0x15110E) : Color.white.opacity(0.7))
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(
                    isOn ? Color.white : Color.white.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(LiquidPressStyle(scale: 0.95))
    }
}

private struct DarkToggleRow: View {
    let label: String
    let subtitle: String
    let systemIcon: String
    @Binding var isOn: Bool
    var isPro: Bool = false    // PRO 뱃지 표시
    var locked: Bool = false   // 잠금 아이콘

    var body: some View {
        Button {
            if !locked { isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                // 아이콘 박스
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemIcon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.gold)
                }

                // 레이블
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(.white)
                        if isPro {
                            Text("PRO")
                                .font(.system(size: 9.5, weight: .heavy))
                                .foregroundStyle(Color(hex: 0x15110E))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(AppColors.gold, in: Capsule())
                        }
                        if locked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppColors.gold)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 토글 스위치
                togglePill
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidPressStyle(scale: 0.98))
    }

    private var togglePill: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? AppColors.primary : Color.white.opacity(0.18))
                .frame(width: 46, height: 28)
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
                .padding(3)
        }
        .animation(.easeOut(duration: 0.2), value: isOn)
        .opacity(locked && !isOn ? 0.45 : 1)
    }
}

// MARK: - FlexRow Helper (stat items)

/// 수치 아이템을 가로로 나열하고 `·` 구분자 추가
private struct FlexRow<Item, Content: View>: View {
    let items: [Item]
    var hAlign: HorizontalAlignment = .leading
    var spacing: CGFloat = 10
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    if idx > 0 {
                        Text("·")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    content(item)
                }
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
