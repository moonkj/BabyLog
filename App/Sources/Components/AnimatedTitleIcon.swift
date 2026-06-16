// AnimatedTitleIcon.swift
// BabyLog · 섹션 제목 옆 마이크로 모션 아이콘 (홈·기록·가계부·내정보).
// 핸드오프(animated_icons_handoff) 사양 그대로 포팅:
//  - 세이지 라인 #4E8268 · stroke 1.9 · round cap/join · 24×24 viewBox.
//  - 5초 주기 자동 루프: 모션 ~0.8초 + 휴지 ~4.2초(끊김 없이 반복).
//  - reduced-motion이면 정지 상태로 렌더.
// 구현: iOS17 KeyframeAnimator(repeating)로 part별 값을 구동, Canvas로 패스 스트로크/필.

import SwiftUI

struct AnimatedTitleIcon: View {
    enum Kind { case home, record, budget, profile }

    let kind: Kind
    var size: CGFloat = 28
    var color: Color = Color(hex: 0x4E8268)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                canvas(Self.staticRest(kind))
            } else {
                // 5초마다 '한 번만' 재생(트리거) → 휴지 구간엔 정지 렌더(상시 60fps 리드로우 방지, 배터리).
                TimelineView(.periodic(from: .now, by: 5)) { ctx in
                    animator(trigger: ctx.date)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func animator(trigger: Date) -> some View {
        switch kind {
        case .home:
            KeyframeAnimator(initialValue: Self.staticRest(.home), trigger: trigger) { v in canvas(v) } keyframes: { _ in
                KeyframeTrack(\.roofDY)     { CubicKeyframe(-2.5, duration: 0.2); CubicKeyframe(1, duration: 0.3); CubicKeyframe(0, duration: 0.25) }
                KeyframeTrack(\.roofScaleX) { CubicKeyframe(0.93, duration: 0.2); CubicKeyframe(1.05, duration: 0.3); CubicKeyframe(1, duration: 0.25) }
                KeyframeTrack(\.winOpacity) { LinearKeyframe(1, duration: 0.3); LinearKeyframe(0.15, duration: 0.15); LinearKeyframe(1, duration: 0.2) }
            }
        case .record:
            KeyframeAnimator(initialValue: Self.staticRest(.record), trigger: trigger) { v in canvas(v) } keyframes: { _ in
                KeyframeTrack(\.flipScaleX)   { LinearKeyframe(1, duration: 0.25); CubicKeyframe(-1, duration: 0.55); CubicKeyframe(1, duration: 0.4) }
                KeyframeTrack(\.sparkOpacity) { LinearKeyframe(0, duration: 0.6); LinearKeyframe(1, duration: 0.25); LinearKeyframe(0, duration: 0.35) }
                KeyframeTrack(\.sparkScale)   { LinearKeyframe(0.4, duration: 0.6); CubicKeyframe(1, duration: 0.25); CubicKeyframe(1.2, duration: 0.35) }
            }
        case .budget:
            KeyframeAnimator(initialValue: Self.staticRest(.budget), trigger: trigger) { v in canvas(v) } keyframes: { _ in
                KeyframeTrack(\.coinDY)      { LinearKeyframe(-13, duration: 0.001); CubicKeyframe(2, duration: 0.55); CubicKeyframe(1, duration: 0.15) }
                KeyframeTrack(\.coinOpacity) { LinearKeyframe(0, duration: 0.001); LinearKeyframe(1, duration: 0.3); LinearKeyframe(1, duration: 0.4) }
                KeyframeTrack(\.flapDY)      { LinearKeyframe(0, duration: 0.55); CubicKeyframe(-1.5, duration: 0.2); CubicKeyframe(0, duration: 0.2) }
            }
        case .profile:
            KeyframeAnimator(initialValue: Self.staticRest(.profile), trigger: trigger) { v in canvas(v) } keyframes: { _ in
                KeyframeTrack(\.figDY)       { CubicKeyframe(-2, duration: 0.25); CubicKeyframe(-1, duration: 0.3); CubicKeyframe(0, duration: 0.25) }
                KeyframeTrack(\.figRot)      { CubicKeyframe(-5, duration: 0.25); CubicKeyframe(4, duration: 0.3); CubicKeyframe(0, duration: 0.25) }
                KeyframeTrack(\.ringScale)   { CubicKeyframe(1.25, duration: 0.6); LinearKeyframe(0.7, duration: 0.001) }
                KeyframeTrack(\.ringOpacity) { LinearKeyframe(0.55, duration: 0.1); CubicKeyframe(0, duration: 0.55) }
            }
        }
    }

    // MARK: - Canvas 렌더
    private func canvas(_ v: IconValues) -> some View {
        Canvas { ctx, sz in
            let s = sz.width / 24.0
            let toPx = CGAffineTransform(scaleX: s, y: s)
            let lw = 1.9 * s
            let stroke = StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round)
            func line(_ p: Path, _ t: CGAffineTransform = .identity) {
                ctx.stroke(p.applying(t.concatenating(toPx)), with: .color(color), style: stroke)
            }
            func line(_ p: Path, _ t: CGAffineTransform, opacity: Double) {
                ctx.stroke(p.applying(t.concatenating(toPx)), with: .color(color.opacity(opacity)), style: stroke)
            }
            func fill(_ p: Path, _ t: CGAffineTransform = .identity, opacity: Double = 1) {
                ctx.fill(p.applying(t.concatenating(toPx)), with: .color(color.opacity(opacity)))
            }

            switch kind {
            case .home:
                let roofT = CGAffineTransform.identity
                    .translatedBy(x: 0, y: v.roofDY)
                    .translatedBy(x: 12, y: 0).scaledBy(x: v.roofScaleX, y: 1).translatedBy(x: -12, y: 0)
                line(Self.homeBody)
                line(Self.homeRoof, roofT)
                fill(Self.homeWin, opacity: v.winOpacity)
            case .record:
                line(Self.recLeft)
                line(Self.recRight)
                let flipT = CGAffineTransform.identity
                    .translatedBy(x: 12, y: 0).scaledBy(x: v.flipScaleX, y: 1).translatedBy(x: -12, y: 0)
                line(Self.recRight, flipT)            // 책등(왼쪽) 축으로 넘어가는 페이지
                line(Self.recSpine)
                let sparkT = CGAffineTransform.identity
                    .translatedBy(x: 19.4, y: 6.5).scaledBy(x: v.sparkScale, y: v.sparkScale).translatedBy(x: -19.4, y: -6.5)
                fill(Self.recSpark, sparkT, opacity: v.sparkOpacity)
            case .budget:
                let coinT = CGAffineTransform(translationX: 0, y: v.coinDY)
                line(Self.budCoin, coinT, opacity: v.coinOpacity)
                line(Self.budFlap, CGAffineTransform(translationX: 0, y: v.flapDY))
                line(Self.budBody)
                line(Self.budSnap)
            case .profile:
                let ringT = CGAffineTransform.identity
                    .translatedBy(x: 12, y: 12).scaledBy(x: v.ringScale, y: v.ringScale).translatedBy(x: -12, y: -12)
                line(Self.meRing, ringT, opacity: v.ringOpacity)
                let figT = CGAffineTransform.identity
                    .translatedBy(x: 0, y: v.figDY)
                    .translatedBy(x: 12, y: 19.2).rotated(by: v.figRot * .pi / 180).translatedBy(x: -12, y: -19.2)
                line(Self.meHead, figT)
                line(Self.meBody, figT)
            }
        }
    }

    // MARK: - 애니메이션 값
    struct IconValues {
        var roofScaleX: CGFloat = 1
        var roofDY: CGFloat = 0
        var winOpacity: Double = 1
        var flipScaleX: CGFloat = 1
        var sparkOpacity: Double = 0
        var sparkScale: CGFloat = 0.4
        var coinDY: CGFloat = 0
        var coinOpacity: Double = 1
        var flapDY: CGFloat = 0
        var figDY: CGFloat = 0
        var figRot: CGFloat = 0      // degrees
        var ringScale: CGFloat = 0.7
        var ringOpacity: Double = 0
    }
    /// 애니메이션 시작(=0% 키프레임) 상태. 루프가 여기서 시작·복귀.
    static func animStart(_ k: Kind) -> IconValues {
        var v = IconValues()
        if k == .budget { v.coinDY = -13; v.coinOpacity = 0 }   // 동전은 위에서 보이지 않게 시작
        return v
    }
    /// reduced-motion 정지 상태(휴지 중 보이는 모습).
    static func staticRest(_ k: Kind) -> IconValues {
        var v = IconValues()
        if k == .budget { v.coinDY = 1; v.coinOpacity = 1 }     // 동전은 지갑에 안착
        return v
    }

    // MARK: - 패스 (24×24 좌표, 핸드오프 SVG 그대로)
    static let homeRoof: Path = { var p = Path(); p.move(to: .init(x: 4, y: 11.5)); p.addLine(to: .init(x: 12, y: 5)); p.addLine(to: .init(x: 20, y: 11.5)); return p }()
    static let homeBody: Path = {
        var p = Path()
        p.move(to: .init(x: 6, y: 10.5)); p.addLine(to: .init(x: 6, y: 19))
        p.addQuadCurve(to: .init(x: 7, y: 20), control: .init(x: 6, y: 20))
        p.addLine(to: .init(x: 17, y: 20))
        p.addQuadCurve(to: .init(x: 18, y: 19), control: .init(x: 18, y: 20))
        p.addLine(to: .init(x: 18, y: 10.5)); return p
    }()
    static let homeWin: Path = { Path(roundedRect: CGRect(x: 10.5, y: 13.6, width: 3, height: 3), cornerRadius: 0.6) }()

    static let recLeft: Path = {
        var p = Path(); p.move(to: .init(x: 12, y: 6.4))
        p.addCurve(to: .init(x: 6, y: 4.6), control1: .init(x: 10.4, y: 5.2), control2: .init(x: 8.4, y: 4.6))
        p.addLine(to: .init(x: 6, y: 17))
        p.addCurve(to: .init(x: 12, y: 18.8), control1: .init(x: 8.4, y: 17), control2: .init(x: 10.4, y: 17.6)); return p
    }()
    static let recRight: Path = {
        var p = Path(); p.move(to: .init(x: 12, y: 6.4))
        p.addCurve(to: .init(x: 18, y: 4.6), control1: .init(x: 13.6, y: 5.2), control2: .init(x: 15.6, y: 4.6))
        p.addLine(to: .init(x: 18, y: 17))
        p.addCurve(to: .init(x: 12, y: 18.8), control1: .init(x: 15.6, y: 17), control2: .init(x: 13.6, y: 17.6)); return p
    }()
    static let recSpine: Path = { var p = Path(); p.move(to: .init(x: 12, y: 6.4)); p.addLine(to: .init(x: 12, y: 18.8)); return p }()
    static let recSpark: Path = {
        var p = Path(); p.move(to: .init(x: 19.4, y: 4.4))
        p.addLine(to: .init(x: 20.0, y: 5.9)); p.addLine(to: .init(x: 21.5, y: 6.5)); p.addLine(to: .init(x: 20.0, y: 7.1))
        p.addLine(to: .init(x: 19.4, y: 8.6)); p.addLine(to: .init(x: 18.8, y: 7.1)); p.addLine(to: .init(x: 17.3, y: 6.5))
        p.addLine(to: .init(x: 18.8, y: 5.9)); p.closeSubpath(); return p
    }()

    static let budCoin: Path = { Path(ellipseIn: CGRect(x: 9, y: 5, width: 6, height: 6)) }()   // cx12 cy8 r3
    static let budFlap: Path = {
        var p = Path(); p.move(to: .init(x: 4, y: 9.5))
        p.addQuadCurve(to: .init(x: 6, y: 7.5), control: .init(x: 4, y: 7.5))
        p.addLine(to: .init(x: 18, y: 7.5))
        p.addQuadCurve(to: .init(x: 20, y: 9.5), control: .init(x: 20, y: 7.5)); return p
    }()
    static let budBody: Path = {
        var p = Path(); p.move(to: .init(x: 4, y: 9.5)); p.addLine(to: .init(x: 4, y: 17.5))
        p.addQuadCurve(to: .init(x: 6, y: 19.5), control: .init(x: 4, y: 19.5))
        p.addLine(to: .init(x: 18, y: 19.5))
        p.addQuadCurve(to: .init(x: 20, y: 17.5), control: .init(x: 20, y: 19.5))
        p.addLine(to: .init(x: 20, y: 9.5)); return p
    }()
    static let budSnap: Path = {
        var p = Path(); p.move(to: .init(x: 20, y: 12.5)); p.addLine(to: .init(x: 17, y: 12.5))
        p.addCurve(to: .init(x: 17, y: 15.7), control1: .init(x: 15.3, y: 12.5), control2: .init(x: 15.3, y: 15.7))
        p.addLine(to: .init(x: 20, y: 15.7)); return p
    }()

    static let meRing: Path = { Path(ellipseIn: CGRect(x: 2.5, y: 2.5, width: 19, height: 19)) }()  // cx12 cy12 r9.5
    static let meHead: Path = { Path(ellipseIn: CGRect(x: 8.8, y: 5.8, width: 6.4, height: 6.4)) }() // cx12 cy9 r3.2
    static let meBody: Path = {
        var p = Path(); p.move(to: .init(x: 6, y: 19.2))
        p.addCurve(to: .init(x: 12, y: 14.1), control1: .init(x: 6, y: 15.8), control2: .init(x: 8.6, y: 14.1))
        p.addCurve(to: .init(x: 18, y: 19.2), control1: .init(x: 15.4, y: 14.1), control2: .init(x: 18, y: 15.8)); return p
    }()
}
