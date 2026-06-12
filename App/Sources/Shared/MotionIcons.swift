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

// MARK: - 정적 라인 글리프(핸드오프 action_icons_handoff/svg)

/// 지도·길찾기 라인 핀(아웃라인 물방울 + 중심 원). viewBox 24×24의 cubic 경로를 그대로 재현.
struct MapLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var p = Path()
        // 물방울 외곽(원본 c 커브 절대좌표화)
        p.move(to: P(12, 2.5))
        p.addCurve(to: P(5.5, 9.0),  control1: P(8.4, 2.5),  control2: P(5.5, 5.4))
        p.addCurve(to: P(11.5, 18.5), control1: P(5.5, 13.4), control2: P(11.2, 18.3))
        p.addCurve(to: P(12.5, 18.5), control1: P(11.8, 18.7), control2: P(12.2, 18.7))
        p.addCurve(to: P(18.5, 9.0),  control1: P(12.8, 18.3), control2: P(18.5, 13.4))
        p.addCurve(to: P(12, 2.5),    control1: P(18.5, 5.4),  control2: P(15.6, 2.5))
        p.closeSubpath()
        // 중심 원 (cx12 cy9 r2.5)
        p.addEllipse(in: CGRect(x: (12 - 2.5) * s, y: (9 - 2.5) * s, width: 5 * s, height: 5 * s))
        return p
    }
}

/// 공유 라인(연결선 2 + 노드 3). 원본 좌표 그대로.
struct ShareLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var p = Path()
        p.move(to: P(8.5, 11)); p.addLine(to: P(15, 7.5))
        p.move(to: P(8.5, 13)); p.addLine(to: P(15, 16.5))
        for c in [(17.0, 6.0), (17.0, 18.0), (6.0, 12.0)] {
            p.addEllipse(in: CGRect(x: (c.0 - 2.6) * s, y: (c.1 - 2.6) * s, width: 5.2 * s, height: 5.2 * s))
        }
        return p
    }
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

// MARK: - 전화 (정적=깔끔한 수화기 / animated=흔들림+신호물결)
// ⚠️ animated=true(선택된 카드)일 때만 연속 재생. 평소엔 정적 → 스크롤 렉 0.

struct PhoneMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation) { ctx in
                    let p = loopPhase(ctx.date, period: 2.2)
                    let angle = kf(p, [(0, 0), (0.58, 0), (0.64, -12), (0.72, 9), (0.80, -6), (0.88, 3), (0.94, 0), (1, 0)])
                    phoneBody(angle: angle, p: p)
                }
            } else {
                // 정적 = 라인 수화기(핸드오프 아웃라인 스타일)
                Image(systemName: "phone")
                    .font(.system(size: size * 0.66, weight: .regular))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func phoneBody(angle: Double, p: Double) -> some View {
        ZStack {
            if p >= 0 {
                signal(p: p, delay: 0, r: 0.52)
                signal(p: p, delay: 0.12, r: 0.74)
            }
            Image(systemName: "phone.fill")
                .font(.system(size: size * 0.62, weight: .semibold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(angle))
        }
    }

    /// 우상단으로 퍼지는 신호 물결.
    @ViewBuilder
    private func signal(p: Double, delay: Double, r: Double) -> some View {
        let q = ((p - delay).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let opacity = kf(q, [(0, 0), (0.5, 0), (0.62, 0.9), (1, 0)])
        let scale = kf(q, [(0, 0.6), (0.5, 0.6), (1, 1.2)])
        SignalArc()
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            .frame(width: size * r, height: size * r)
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: size * 0.06, y: -size * 0.06)
    }
}

/// 수화기 우상단에서 퍼지는 신호 호.
private struct SignalArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.addArc(center: c, radius: rect.width * 0.42,
                 startAngle: .degrees(-65), endAngle: .degrees(-15), clockwise: false)
        return p
    }
}

// MARK: - 지도 (정적=핀 / animated=핀 드롭+중심점 펄스)

struct MapPinMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation) { ctx in
                    let p = loopPhase(ctx.date, period: 2.2)
                    let dy = kf(p, [(0, -size * 0.22), (0.16, 0), (0.24, -size * 0.08), (0.32, 0), (0.70, 0), (1, 0)])
                    let dot = kf(p, [(0, 1), (0.30, 1), (0.50, 0.55), (0.70, 1), (1, 1)])
                    pinBody(dy: dy, dot: dot)
                }
            } else {
                // 정적 = 라인 핀(핸드오프 아웃라인 스타일)
                MapLineShape()
                    .stroke(color, style: StrokeStyle(lineWidth: max(1.6, size * 0.085), lineCap: .round, lineJoin: .round))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func pinBody(dy: CGFloat, dot: CGFloat) -> some View {
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
                    .scaleEffect(dot)
            }
            .offset(y: dy)
        }
    }
}

// MARK: - 공유 (정적=연결선+노드 / animated=선 흐름+노드 펄스)

struct ShareMotionIcon: View {
    var color: Color = MotionIconPalette.green
    var size: CGFloat = 20
    var animated: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func pt(_ x: Double, _ y: Double, _ s: CGFloat) -> CGPoint {
        CGPoint(x: x / 24 * s, y: y / 24 * s)
    }

    var body: some View {
        Group {
            if animated && !reduceMotion {
                TimelineView(.animation) { ctx in
                    let p = loopPhase(ctx.date, period: 2.4)
                    shareBody(p: p)
                }
            } else {
                // 정적 = 라인 노드(핸드오프 아웃라인 스타일)
                ShareLineShape()
                    .stroke(color, style: StrokeStyle(lineWidth: max(1.6, size * 0.085), lineCap: .round, lineJoin: .round))
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shareBody(p: Double) -> some View {
        let s = size
        let draw1 = p < 0 ? 1 : 1 - kf(p, [(0, 1), (0.20, 1), (0.45, 0), (0.70, 0), (1, 1)])
        let q2 = p < 0 ? -1.0 : ((p - 0.05).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        let draw2 = q2 < 0 ? 1 : 1 - kf(q2, [(0, 1), (0.20, 1), (0.45, 0), (0.70, 0), (1, 1)])
        ZStack {
            line(from: pt(6, 12, s), to: pt(17, 6, s), trim: draw1)
            line(from: pt(6, 12, s), to: pt(17, 18, s), trim: draw2)
            node(at: pt(6, 12, s), p: p, delay: 0)
            node(at: pt(17, 6, s), p: p, delay: 0.21)
            node(at: pt(17, 18, s), p: p, delay: 0.29)
        }
    }

    private func line(from a: CGPoint, to b: CGPoint, trim: Double) -> some View {
        Path { p in p.move(to: a); p.addLine(to: b) }
            .trim(from: 0, to: max(0, min(1, trim)))
            .stroke(color, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
    }

    private func node(at c: CGPoint, p: Double, delay: Double) -> some View {
        let scale: Double = {
            guard p >= 0 else { return 1 }
            let q = ((p - delay).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
            return kf(q, [(0, 1), (0.30, 1), (0.45, 1.22), (0.60, 1), (1, 1)])
        }()
        return Circle()
            .fill(color)
            .frame(width: size * 0.25, height: size * 0.25)
            .scaleEffect(scale)
            .position(c)
    }
}
