// MotionIcons.swift
// BabyLog · Shared
//
// 디자인 핸드오프(design_handoff_babylog/Location Icon.html)의 애니메이션 아이콘 세트를
// SwiftUI로 재현. 내 위치(숨쉬기+핑) · 전화(수화기 흔들림+신호물결) · 지도(핀 드롭) · 공유(노드 펄스).
// 색상은 핸드오프 primary(초록 #4E8268) 기준. TimelineView로 keyframe을 시간 기반 재현하고,
// 손쉬운 정지를 위해 prefers-reduced-motion(접근성)에서는 애니메이션을 멈춘다.

import SwiftUI

// MARK: - 핸드오프 팔레트

enum MotionIconPalette {
    /// 핸드오프 primary 초록
    static let green = Color(hex: 0x4E8268)
    /// 연한 초록 틴트(버튼 배경용)
    static let greenSoft = Color(hex: 0xDCEFE6)
}

// MARK: - keyframe 보간 유틸

/// 진행도 p(0~1)에서 (위치, 값) 스톱들을 선형 보간.
private func kf(_ p: Double, _ stops: [(Double, Double)]) -> Double {
    guard let first = stops.first else { return 0 }
    if p <= first.0 { return first.1 }
    for i in 1..<stops.count {
        let a = stops[i - 1], b = stops[i]
        if p <= b.0 {
            let f = (p - a.0) / max(b.0 - a.0, 1e-6)
            return a.1 + (b.1 - a.1) * f
        }
    }
    return stops.last?.1 ?? 0
}

/// period 주기로 0~1 반복하는 진행도.
private func loopPhase(_ date: Date, period: Double) -> Double {
    let t = date.timeIntervalSinceReferenceDate
    return (t.truncatingRemainder(dividingBy: period)) / period
}

// MARK: - 핀 머리(내 위치·지도 공용)

/// CSS 핀(border-radius:50% 50% 50% 0; rotate(-45deg)) 방식의 물방울 핀 + 흰 중심점.
private struct PinHead: View {
    var color: Color
    var dot: Color = .white
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: s * 0.5,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: s * 0.5,
                    topTrailingRadius: s * 0.5,
                    style: .continuous
                )
                .fill(color)
                .frame(width: s * 0.74, height: s * 0.74)
                .rotationEffect(.degrees(-45))
                .offset(y: -s * 0.07)

                Circle()
                    .fill(dot)
                    .frame(width: s * 0.26, height: s * 0.26)
                    .offset(y: -s * 0.11)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }
}

// MARK: - 내 위치 (숨쉬기 + 핑 + 그림자)

struct LocationPinIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : loopPhase(ctx.date, period: 2.4)
            // 숨쉬기: 1 → 1.05 → 1
            let breath = 1 + 0.05 * 0.5 * (1 - cos(p * 2 * .pi))
            // 핑: scale .5→1.7, opacity .45→0 (0~70% 구간에서 퍼짐)
            let pp = min(p / 0.7, 1)
            let pingScale = 0.5 + 1.2 * pp
            let pingOpacity = 0.45 * (1 - pp)
            // 그림자: scaleX 1→.82→1
            let shX = 1 - 0.18 * 0.5 * (1 - cos(p * 2 * .pi))

            ZStack {
                Circle()
                    .stroke(color, lineWidth: max(1, size * 0.10))
                    .frame(width: size * 0.46, height: size * 0.46)
                    .scaleEffect(reduceMotion ? 1 : pingScale)
                    .opacity(reduceMotion ? 0 : pingOpacity)
                    .offset(y: -size * 0.06)

                VStack(spacing: size * 0.02) {
                    PinHead(color: color)
                        .frame(width: size * 0.66, height: size * 0.66)
                        .scaleEffect(reduceMotion ? 1 : breath, anchor: .bottom)
                    Ellipse()
                        .fill(color)
                        .frame(width: size * 0.32, height: size * 0.09)
                        .scaleEffect(x: reduceMotion ? 1 : shX)
                        .opacity(reduceMotion ? 0.20 : 0.14 + 0.08 * (1 - 0.5 * (1 - cos(p * 2 * .pi))))
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 전화 (정적 + 탭 시 1회 흔들림)
// ⚠️ 평소엔 정지(스크롤 렉 0). `trigger` 값이 바뀔 때만 phaseAnimator로 1회 재생.

struct PhoneMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    /// 값이 바뀌면 1회 흔들림 재생(병원 카드 탭).
    var trigger: Int = 0

    var body: some View {
        ZStack {
            ArcWave()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .frame(width: size * 0.5, height: size * 0.5)
                .opacity(0.9)
                .offset(x: size * 0.17, y: -size * 0.17)
            ArcWave()
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .frame(width: size * 0.72, height: size * 0.72)
                .opacity(0.55)
                .offset(x: size * 0.17, y: -size * 0.17)
            Image(systemName: "phone.fill")
                .font(.system(size: size * 0.66, weight: .semibold))
                .foregroundStyle(color)
                .offset(x: -size * 0.04, y: size * 0.04)
                .phaseAnimator([0.0, -12, 9, -6, 3, 0], trigger: trigger) { view, angle in
                    view.rotationEffect(.degrees(angle))
                } animation: { _ in .easeInOut(duration: 0.1) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 우상단 4분원 호(신호 물결).
private struct ArcWave: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.minX, y: rect.maxY) // 좌하단 중심 → 우상단 호
        p.addArc(center: c, radius: rect.width,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

// MARK: - 지도 (정적 + 탭 시 1회 핀 드롭)

struct MapPinMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var trigger: Int = 0

    var body: some View {
        ZStack {
            Ellipse()
                .fill(color).opacity(0.18)
                .frame(width: size * 0.34, height: size * 0.10)
                .offset(y: size * 0.42)
            ZStack {
                PinHead(color: color, dot: .clear)
                    .frame(width: size * 0.74, height: size * 0.74)
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.20, height: size * 0.20)
                    .offset(y: -size * 0.085)
            }
            .phaseAnimator([0.0, -size * 0.22, 0], trigger: trigger) { view, dy in
                view.offset(y: dy)
            } animation: { dy in dy == 0 ? .spring(response: 0.28, dampingFraction: 0.55) : .easeOut(duration: 0.16) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - 공유 (정적 + 탭 시 1회 노드 펄스)

struct ShareMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var trigger: Int = 0

    // viewBox 24 기준 좌표 → 단위 변환
    private func pt(_ x: Double, _ y: Double, _ s: CGFloat) -> CGPoint {
        CGPoint(x: x / 24 * s, y: y / 24 * s)
    }

    var body: some View {
        let s = size
        ZStack {
            line(from: pt(6, 12, s), to: pt(17, 6, s))
            line(from: pt(6, 12, s), to: pt(17, 18, s))
            node(at: pt(6, 12, s))
            node(at: pt(17, 6, s))
            node(at: pt(17, 18, s))
        }
        .frame(width: size, height: size)
        .phaseAnimator([1.0, 1.22, 1.0], trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } animation: { _ in .easeInOut(duration: 0.22) }
        .accessibilityHidden(true)
    }

    private func line(from a: CGPoint, to b: CGPoint) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
    }

    private func node(at c: CGPoint) -> some View {
        Circle()
            .fill(color)
            .frame(width: size * 0.25, height: size * 0.25)
            .position(c)
    }
}
