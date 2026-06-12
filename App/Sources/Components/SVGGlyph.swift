// SVGGlyph.swift
// BabyLog — Components
//
// 디자인 핸드오프 SVG path(d 속성)를 SwiftUI Path로 렌더하는 경량 파서 + 글리프 Shape.
// M/m L/l H/h V/v C/c S/s A/a Z 지원(24×24 viewBox 가정). 라인(stroke) 아이콘 전용.

import SwiftUI

// MARK: - SVG path 파서

enum SVGPathParser {
    private enum Tok { case cmd(Character); case num(CGFloat) }

    /// SVG path `d` → Path (24-unit 좌표 그대로; 스케일은 호출측 transform).
    static func parse(_ d: String) -> Path {
        let toks = tokenize(d)
        var path = Path()
        var i = 0
        var cur = CGPoint.zero
        var sub = CGPoint.zero
        var prevC2 = CGPoint.zero
        var hadCubic = false
        var cmd: Character = " "

        func num() -> CGFloat {
            if i < toks.count, case .num(let v) = toks[i] { i += 1; return v }
            return 0
        }

        while i < toks.count {
            if case .cmd(let ch) = toks[i] { cmd = ch; i += 1 }
            let rel = cmd.isLowercase
            switch Character(cmd.uppercased()) {
            case "M":
                var x = num(), y = num()
                if rel { x += cur.x; y += cur.y }
                cur = CGPoint(x: x, y: y); sub = cur; path.move(to: cur)
                cmd = rel ? "l" : "L"; hadCubic = false
            case "L":
                var x = num(), y = num(); if rel { x += cur.x; y += cur.y }
                cur = CGPoint(x: x, y: y); path.addLine(to: cur); hadCubic = false
            case "H":
                var x = num(); if rel { x += cur.x }; cur.x = x; path.addLine(to: cur); hadCubic = false
            case "V":
                var y = num(); if rel { y += cur.y }; cur.y = y; path.addLine(to: cur); hadCubic = false
            case "C":
                var c1 = CGPoint(x: num(), y: num()), c2 = CGPoint(x: num(), y: num()), e = CGPoint(x: num(), y: num())
                if rel { c1.x += cur.x; c1.y += cur.y; c2.x += cur.x; c2.y += cur.y; e.x += cur.x; e.y += cur.y }
                path.addCurve(to: e, control1: c1, control2: c2); prevC2 = c2; cur = e; hadCubic = true
            case "S":
                var c2 = CGPoint(x: num(), y: num()), e = CGPoint(x: num(), y: num())
                if rel { c2.x += cur.x; c2.y += cur.y; e.x += cur.x; e.y += cur.y }
                let c1 = hadCubic ? CGPoint(x: 2 * cur.x - prevC2.x, y: 2 * cur.y - prevC2.y) : cur
                path.addCurve(to: e, control1: c1, control2: c2); prevC2 = c2; cur = e; hadCubic = true
            case "A":
                let rx = num(), ry = num(), rot = num(), large = num(), sweep = num()
                var e = CGPoint(x: num(), y: num()); if rel { e.x += cur.x; e.y += cur.y }
                addArc(&path, from: cur, to: e, rx: rx, ry: ry, rotDeg: rot, large: large != 0, sweep: sweep != 0)
                cur = e; hadCubic = false
            case "Z":
                path.closeSubpath(); cur = sub; hadCubic = false
                // Z는 인자를 받지 않는다 — 뒤따르는 잘못된 숫자 토큰은 건너뛰어
                // 루프가 반드시 전진하도록 보장(무한 루프 → 메인 스레드 행 방지).
                while i < toks.count, case .num = toks[i] { i += 1 }
            default:
                // 미지원/공백 커맨드 — 토큰을 하나 소비해 루프 전진 보장.
                i += 1
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [Tok] {
        var toks: [Tok] = []
        let a = Array(d); var i = 0
        while i < a.count {
            let c = a[i]
            if c.isLetter { toks.append(.cmd(c)); i += 1 }
            else if c == "," || c == " " || c == "\n" || c == "\t" || c == "\r" { i += 1 }
            else if c == "-" || c == "+" || c == "." || c.isNumber {
                var s = ""; var dot = false
                if c == "-" || c == "+" { s.append(c); i += 1 }
                while i < a.count {
                    let ch = a[i]
                    if ch.isNumber { s.append(ch); i += 1 }
                    else if ch == "." { if dot { break }; dot = true; s.append(ch); i += 1 }
                    else if ch == "e" || ch == "E" {
                        s.append(ch); i += 1
                        if i < a.count, a[i] == "-" || a[i] == "+" { s.append(a[i]); i += 1 }
                    } else { break }
                }
                if let v = Double(s) { toks.append(.num(CGFloat(v))) }
            } else { i += 1 }
        }
        return toks
    }

    /// SVG 타원호(endpoint) → 중심 파라미터화 후 큐빅 베지어 근사.
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                              rx rxIn: CGFloat, ry ryIn: CGFloat, rotDeg: CGFloat, large: Bool, sweep: Bool) {
        if p0 == p1 { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotDeg * .pi / 180, cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1p = cosP * dx + sinP * dy
        let y1p = -sinP * dx + cosP * dy
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { let s = sqrt(lambda); rx *= s; ry *= s }
        let sign: CGFloat = (large != sweep) ? 1 : -1
        var numr = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        if numr < 0 { numr = 0 }
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let co = den == 0 ? 0 : sign * sqrt(numr / den)
        let cxp = co * (rx * y1p / ry)
        let cyp = co * (-ry * x1p / rx)
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func ang(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(max(-1, min(1, len == 0 ? 1 : dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let theta1 = ang(1, 0, ux, uy)
        var dTheta = ang(ux, uy, vx, vy)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segs = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let delta = dTheta / CGFloat(segs)
        let t = 4.0 / 3.0 * tan(delta / 4)
        var a0 = theta1
        for _ in 0..<segs {
            let a1 = a0 + delta
            let c0 = cos(a0), s0 = sin(a0), c1a = cos(a1), s1 = sin(a1)
            func pt(_ ca: CGFloat, _ sa: CGFloat) -> CGPoint {
                let x = rx * ca, y = ry * sa
                return CGPoint(x: cosP * x - sinP * y + cx, y: sinP * x + cosP * y + cy)
            }
            let e = pt(c1a, s1)
            let cp1 = CGPoint(x: pt(c0, s0).x + (-rx * s0 * cosP - ry * c0 * sinP) * t,
                              y: pt(c0, s0).y + (-rx * s0 * sinP + ry * c0 * cosP) * t)
            let cp2 = CGPoint(x: e.x - (-rx * s1 * cosP - ry * c1a * sinP) * t,
                              y: e.y - (-rx * s1 * sinP + ry * c1a * cosP) * t)
            path.addCurve(to: e, control1: cp1, control2: cp2)
            a0 = a1
        }
    }
}

// MARK: - 글리프(여러 SVG 요소 합성)

enum SVGEl {
    case path(String)
    case circle(CGFloat, CGFloat, CGFloat)              // cx, cy, r
    case rrect(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) // x, y, w, h, r
}

/// 24×24 viewBox SVG 요소들을 합쳐 stroke용 Path로 만드는 Shape.
struct SVGGlyph: Shape {
    let elements: [SVGEl]
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for el in elements {
            switch el {
            case .path(let d):
                p.addPath(SVGPathParser.parse(d))
            case .circle(let cx, let cy, let r):
                p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
            case .rrect(let x, let y, let w, let h, let r):
                p.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h), cornerSize: CGSize(width: r, height: r))
            }
        }
        let k = rect.width / 24
        return p.applying(CGAffineTransform(scaleX: k, y: k))
    }
}

// MARK: - 네비게이션 라인 아이콘(핸드오프 nav_icons_handoff)

enum NavGlyph {
    // 바텀 탭
    case home, record, dongne, budget, profile
    // 동네 세그먼트
    case nearby, market, crew

    var elements: [SVGEl] {
        switch self {
        case .home:
            return [.path("M4 11.5 12 5l8 6.5"),
                    .path("M6 10.5V19a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-8.5"),
                    .path("M10 20v-5h4v5")]
        case .record:
            return [.path("M12 6.2C10.4 5 8.4 4.4 6 4.4V17c2.4 0 4.4.6 6 1.8 1.6-1.2 3.6-1.8 6-1.8V4.4c-2.4 0-4.4.6-6 1.8z"),
                    .path("M12 6.2V18.8")]
        case .dongne, .nearby:
            return [.path("M12 21s-6.5-5-6.5-10A6.5 6.5 0 0 1 18.5 11c0 5-6.5 10-6.5 10Z"),
                    .circle(12, 11, 2.4)]
        case .budget:
            return [.rrect(4, 6.5, 16, 12, 2.5),
                    .path("M4 9.5h16"),
                    .path("M9.5 13l2.5 3 2.5-3M12 12v3.4M10 13.7h4")]
        case .profile:
            return [.circle(12, 8.5, 3.4),
                    .path("M5.5 20c0-3.6 3-5.4 6.5-5.4s6.5 1.8 6.5 5.4")]
        case .market:
            return [.path("M4 5h5l9 9a2 2 0 0 1 0 2.8l-3.2 3.2a2 2 0 0 1-2.8 0l-9-9V5z"),
                    .circle(8, 9, 1.4)]
        case .crew:
            return [.circle(9, 9, 3),
                    .circle(16.5, 10.5, 2.3),
                    .path("M3.5 19c0-3 2.5-4.6 5.5-4.6s5.5 1.6 5.5 4.6"),
                    .path("M15 14.6c2.4.2 4 1.6 4 4")]
        }
    }
}

/// 네비/세그먼트 라인 아이콘. 선택 시 살짝 굵게(2.1), 기본 1.9 stroke(round).
struct NavLineIcon: View {
    let glyph: NavGlyph
    var color: Color
    var size: CGFloat = 24
    var bold: Bool = false

    var body: some View {
        SVGGlyph(elements: glyph.elements)
            .stroke(color, style: StrokeStyle(lineWidth: (bold ? 2.1 : 1.9) * size / 24,
                                              lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 핸드오프 네비 팔레트
enum NavPalette {
    static let inactive = Color(hex: 0x737373)  // ink-3 (중립 그레이 — 앱 현행 팔레트와 일치)
    static let activeTab = Color(hex: 0x4E8268) // sage
    static let segActive = Color(hex: 0x3F6B55) // sage-press
}
