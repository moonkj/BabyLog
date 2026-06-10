// ShareCardCanvas.swift
// BabyLog · 성장 카드 캔버스 (기능 2.4)
// Swift5 / iOS 17 / SwiftUI + UIKit
// 미리보기와 ImageRenderer 렌더링 공용 — ShareCardView.swift에서 분리

import SwiftUI
import UIKit

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
            // 배경: 선택된 실제 이미지 우선, 없으면 플레이스홀더
            if let photo = vm.backgroundPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h)
                    .clipped()
            } else {
                PhotoPlaceholder(seed: abs(vm.child.name.hashValue) % 6, cornerRadius: 0)
            }

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

// MARK: - FlexRow Helper (stat items)

/// 수치 아이템을 가로로 나열하고 `·` 구분자 추가
struct FlexRow<Item, Content: View>: View {
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
