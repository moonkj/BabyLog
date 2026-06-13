import SwiftUI

/// 카드 — DESIGN.md §5 (용도별 변주, 기본 radius 22)
struct BLCard<Content: View>: View {
    var padding: CGFloat = 18
    var flat: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: shape)
            .overlay { if flat { shape.stroke(AppColors.line, lineWidth: 1) } }
            .modifier(CardShadow(flat: flat))
    }
}

private struct CardShadow: ViewModifier {
    var flat: Bool
    func body(content: Content) -> some View {
        if flat { content } else { content.blShadow(.card) }
    }
}

/// 뱃지/티어 칩 — 색+아이콘(옵션)+레이블 3중 인코딩 (DESIGN.md §11.1)
struct BLBadge: View {
    var tone: BadgeTone
    var text: String
    var systemIcon: String? = nil
    var dot: Bool = true

    var body: some View {
        HStack(spacing: dot || systemIcon != nil ? 5 : 4) {
            if let systemIcon {
                Image(systemName: systemIcon).font(.system(size: 11, weight: .bold))
            } else if dot {
                Circle().fill(tone.ink.opacity(0.85)).frame(width: 6, height: 6)
            }
            Text(text).font(.system(size: 12.5, weight: .bold))
        }
        .foregroundStyle(tone.ink)
        .padding(.horizontal, 10)
        .frame(height: 25)
        .background(tone.bg, in: Capsule())
    }
}

/// 필터 칩 — 온/오프 (DESIGN.md §5.1)
struct BLChip: View {
    var text: String
    var on: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(on ? Color.white : AppColors.ink2)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(on ? AppColors.ink : AppColors.surface, in: Capsule())
                .overlay { Capsule().stroke(on ? AppColors.ink : AppColors.line, lineWidth: 1) }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
    }
}

/// 앱 표준 세그먼트 컨트롤 — 상호배타 '뷰 전환'용.
/// surface2 캡슐 트랙 + 선택 알약(surface+옅은 그림자). 가계부 기간 전환과 동일 언어로 통일.
struct BLSegmented<Tag: Hashable>: View {
    /// (태그, 표시 레이블) 순서대로.
    let segments: [(tag: Tag, label: String)]
    @Binding var selection: Tag

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                let on = seg.tag == selection
                Button {
                    guard !on else { return }
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.2)) { selection = seg.tag }
                } label: {
                    Text(seg.label)
                        .font(.system(size: 14, weight: on ? .bold : .medium))
                        .foregroundStyle(on ? AppColors.ink : AppColors.ink3)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(on ? AppColors.surface : Color.clear, in: Capsule())
                        .shadow(color: on ? Color(hex: 0x282118).opacity(0.08) : .clear, radius: 2, x: 0, y: 1)
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .accessibilityLabel(seg.label)
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(AppColors.surface2, in: Capsule())
    }
}

/// 섹션 헤더 (아이브로/타이틀 + 액션)
struct BLSectionHead: View {
    var eyebrow: String? = nil
    var title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(AppColors.ink3)
                }
                Text(title).font(AppFont.title).foregroundStyle(AppColors.ink)
            }
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 2) {
                        Text(action).font(.system(size: 13.5, weight: .semibold))
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.ink3)
                }
            }
        }
    }
}

/// 따뜻한 그라데이션 사진 플레이스홀더 (DESIGN.md §13.3 / ui.jsx Photo)
struct PhotoPlaceholder: View {
    var seed: Int = 0
    var cornerRadius: CGFloat = Radius.md
    private static let grads: [[Color]] = [
        [Color(hex: 0xF3E4D2), Color(hex: 0xE7CDB6)],
        [Color(hex: 0xDCEFE6), Color(hex: 0xBFE0D0)],
        [Color(hex: 0xEDEBFB), Color(hex: 0xD8D4F2)],
        [Color(hex: 0xFBE6EE), Color(hex: 0xF4C9DA)],
        [Color(hex: 0xE6F1FB), Color(hex: 0xC7DDF2)],
        [Color(hex: 0xFBF0D8), Color(hex: 0xF2DCA9)],
    ]
    var body: some View {
        LinearGradient(colors: Self.grads[seed % Self.grads.count],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - BLScreenHeader
// 모든 탭/화면 제목의 일관 컴포넌트 — 위치·폰트·여백 통일.
// 제목 28pt heavy(tracking -0.4), 상단 좌측 정렬, 표준 여백. eyebrow/subtitle/trailing 선택.

struct BLScreenHeader<Trailing: View>: View {
    let title: String
    var eyebrow: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.ink3)
                }
                Text(title)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s4)
        .padding(.bottom, Spacing.s3)
    }
}

extension BLScreenHeader where Trailing == EmptyView {
    init(title: String, eyebrow: String? = nil, subtitle: String? = nil) {
        self.init(title: title, eyebrow: eyebrow, subtitle: subtitle, trailing: { EmptyView() })
    }
}
