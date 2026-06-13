// ChildAvatarView.swift
// BabyLog — 아이 아바타(보들 머리) · 이모지(👶) 대체
//
// 핸드오프(child_avatar_handoff)의 SVG(viewBox 40)를 SwiftUI Shape로 재현.
// 원형 배경 + 얼굴 + 곱슬 한 가닥 + 눈 2 + 미소 + 양볼 블러시. OS 독립·브랜드 톤 일관.
// 사진(profileImageRef)이 있으면 원형 썸네일, 없으면 이 아바타가 폴백.

import SwiftUI

// MARK: - 팔레트 (성별 중립 4색, 아이별 자동 배정)

struct ChildAvatarPalette {
    let bg: Color, face: Color, ink: Color, cheek: Color

    static let sage  = ChildAvatarPalette(bg: Color(hex: 0xDCEFE6), face: Color(hex: 0xFBF7EE), ink: Color(hex: 0x3F6B55), cheek: Color(hex: 0x9FC9B4))
    static let blue  = ChildAvatarPalette(bg: Color(hex: 0xE6F1FB), face: Color(hex: 0xFBF9F2), ink: Color(hex: 0x3B6FA8), cheek: Color(hex: 0xA9C8EC))
    static let pink  = ChildAvatarPalette(bg: Color(hex: 0xFBEAF0), face: Color(hex: 0xFCF7F1), ink: Color(hex: 0xB5478A), cheek: Color(hex: 0xEAB6CE))
    static let amber = ChildAvatarPalette(bg: Color(hex: 0xFAEEDA), face: Color(hex: 0xFCF8EF), ink: Color(hex: 0x98711E), cheek: Color(hex: 0xE3C98A))

    static let all: [ChildAvatarPalette] = [.sage, .blue, .pink, .amber]

    /// 아이 id 기반 결정적 배정(런치마다 동일 — UUID 문자열의 스칼라 합).
    static func forChild(_ id: UUID) -> ChildAvatarPalette {
        let n = id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return all[n % all.count]
    }
}

// MARK: - 곱슬/미소 path (viewBox 40 기준 → rect 스케일)

private struct AvatarCurlShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 40
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.move(to: p(20, 10))
        path.addCurve(to: p(22.8, 7), control1: p(20, 8), control2: p(21.2, 6.6))
        path.addCurve(to: p(23.4, 9.6), control1: p(24.1, 7.3), control2: p(24.3, 8.8))
        return path
    }
}

private struct AvatarSmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 40
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
        var path = Path()
        path.move(to: p(17.4, 23))
        path.addCurve(to: p(22.6, 23), control1: p(18.8, 24.2), control2: p(21.2, 24.2))
        return path
    }
}

// MARK: - 아바타 뷰

struct ChildAvatarView: View {
    var size: CGFloat = 28
    var palette: ChildAvatarPalette = .sage

    var body: some View {
        let s = size / 40
        ZStack {
            Circle().fill(palette.bg)                              // 원형 배경(r20=전체)
            Circle().fill(palette.face)                            // 얼굴(r10)
                .frame(width: 20 * s, height: 20 * s)
            AvatarCurlShape()                                      // 곱슬 한 가닥
                .stroke(palette.ink, style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            AvatarSmileShape()                                     // 미소
                .stroke(palette.ink, style: StrokeStyle(lineWidth: 1.6 * s, lineCap: .round))
            // 눈(r1.5 → 지름 3)
            Circle().fill(palette.ink).frame(width: 3 * s, height: 3 * s).position(x: 16.6 * s, y: 19.4 * s)
            Circle().fill(palette.ink).frame(width: 3 * s, height: 3 * s).position(x: 23.4 * s, y: 19.4 * s)
            // 양볼 블러시
            Circle().fill(palette.cheek).frame(width: 3 * s, height: 3 * s).position(x: 14.4 * s, y: 22 * s)
            Circle().fill(palette.cheek).frame(width: 3 * s, height: 3 * s).position(x: 25.6 * s, y: 22 * s)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

// MARK: - 아이용 아바타(사진 우선, 없으면 보들머리)

/// 아이의 프로필 사진이 있으면 원형 썸네일, 없으면 id 기반 팔레트 아바타.
struct ChildAvatar: View {
    let child: Child
    var size: CGFloat = 28

    var body: some View {
        if let img = PhotoStore.image(child.profileImageRef) {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityHidden(true)
        } else {
            ChildAvatarView(size: size, palette: ChildAvatarPalette.forChild(child.id))
        }
    }
}
