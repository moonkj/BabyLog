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

// MARK: - 전화 (수화기 흔들림 + 신호 물결)

struct PhoneMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : loopPhase(ctx.date, period: 2.2)
            // 벨처럼 흔들림: 대부분 0, 58~94% 구간에서 빠르게 흔들림
            let angle = kf(p, [(0, 0), (0.58, 0), (0.64, -11), (0.72, 9), (0.80, -6), (0.88, 3), (0.94, 0), (1, 0)])

            ZStack {
                wave(p: p, delay: 0)
                wave(p: p, delay: 0.073)
                Image(systemName: "phone.fill")
                    .font(.system(size: size * 0.74, weight: .semibold))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(reduceMotion ? 0 : angle))
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    /// 우상단에서 퍼지는 신호 물결.
    @ViewBuilder
    private func wave(p: Double, delay: Double) -> some View {
        let wp = (p - delay).truncatingRemainder(dividingBy: 1)
        let q = wp < 0 ? wp + 1 : wp
        // 55%까지 숨김 → 66% 등장 → 100% 사라짐
        let opacity = reduceMotion ? 0 : kf(q, [(0, 0), (0.55, 0), (0.66, 0.9), (1, 0)])
        let scale = reduceMotion ? 1 : kf(q, [(0, 0.5), (0.55, 0.5), (1, 1.25)])
        ArcWave()
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
            .frame(width: size * 0.7, height: size * 0.7)
            .scaleEffect(scale, anchor: .topTrailing)
            .opacity(opacity)
            .offset(x: size * 0.16, y: -size * 0.16)
    }
}

/// 우상단 4분원 호(신호 물결).
private struct ArcWave: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.minX, y: rect.maxY) // 좌하단을 중심으로 우상단 호
        p.addArc(center: c, radius: rect.width * 0.7,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

// MARK: - 지도 (핀 드롭 + 중심점 펄스)

struct MapPinMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : loopPhase(ctx.date, period: 2.2)
            // 핀 드롭: -5 → 0 → 살짝 튕김
            let dy = kf(p, [(0, -5), (0.16, 0), (0.24, -2), (0.32, 0), (0.70, 0), (1, 0)])
            // 중심점: 1 → .55 → 1
            let dot = kf(p, [(0, 1), (0.30, 1), (0.50, 0.55), (0.70, 1), (1, 1)])

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
                        .scaleEffect(reduceMotion ? 1 : dot)
                }
                .offset(y: reduceMotion ? 0 : dy)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - 공유 (연결선 흐름 + 노드 펄스)

struct ShareMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // viewBox 24 기준 좌표 → 단위 변환
    private func pt(_ x: Double, _ y: Double, _ s: CGFloat) -> CGPoint {
        CGPoint(x: x / 24 * s, y: y / 24 * s)
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { ctx in
            let p = reduceMotion ? 0 : loopPhase(ctx.date, period: 2.4)
            let s = size
            // 선 그리기: dashoffset 14→0 (45~70% 그려짐)
            let draw1 = reduceMotion ? 1 : 1 - kf(p, [(0, 1), (0.20, 1), (0.45, 0), (0.70, 0), (1, 1)])
            let draw2p = (p - 0.05).truncatingRemainder(dividingBy: 1)
            let q2 = draw2p < 0 ? draw2p + 1 : draw2p
            let draw2 = reduceMotion ? 1 : 1 - kf(q2, [(0, 1), (0.20, 1), (0.45, 0), (0.70, 0), (1, 1)])

            ZStack {
                line(from: pt(6, 12, s), to: pt(17, 6, s), trim: draw1)
                line(from: pt(6, 12, s), to: pt(17, 18, s), trim: draw2)
                node(at: pt(6, 12, s), p: p, delay: 0)
                node(at: pt(17, 6, s), p: p, delay: 0.21)
                node(at: pt(17, 18, s), p: p, delay: 0.29)
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private func line(from a: CGPoint, to b: CGPoint, trim: Double) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }
            .trim(from: 0, to: max(0, min(1, trim)))
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
    }

    @ViewBuilder
    private func node(at c: CGPoint, p: Double, delay: Double) -> some View {
        let np = (p - delay).truncatingRemainder(dividingBy: 1)
        let q = np < 0 ? np + 1 : np
        let scale = reduceMotion ? 1 : kf(q, [(0, 1), (0.30, 1), (0.45, 1.22), (0.60, 1), (1, 1)])
        Circle()
            .fill(color)
            .frame(width: size * 0.25, height: size * 0.25)
            .scaleEffect(scale)
            .position(c)
    }
}
