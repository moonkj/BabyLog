// ShareCardControls.swift
// BabyLog · 성장 카드 다크 컨트롤 서브뷰 (기능 2.4)
// Swift5 / iOS 17 / SwiftUI + UIKit
// ShareCardView.swift에서 분리 — 컨트롤 패널 구성 요소

import SwiftUI
import UIKit

// MARK: - Dark Control Sub-Views

struct DarkControlGroup<Content: View>: View {
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

struct DarkChip: View {
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

struct DarkToggleRow: View {
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
