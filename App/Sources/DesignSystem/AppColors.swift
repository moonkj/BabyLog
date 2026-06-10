import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// 라이트/다크 적응형 색상 생성
private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
#if canImport(UIKit)
    return Color(UIColor { trait in
        let h = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: CGFloat((h >> 16) & 0xFF) / 255,
                       green: CGFloat((h >> 8) & 0xFF) / 255,
                       blue: CGFloat(h & 0xFF) / 255,
                       alpha: 1)
    })
#else
    return Color(hex: light)
#endif
}

/// BabyLog 색상 토큰 — DESIGN.md §2·§3 / babylog-ds.css 기준 (라이트·다크 적응형)
/// 프로덕션은 Asset Catalog named color로 이관 권장 (DESIGN.md §2.4).
enum AppColors {
    // Surfaces (warm ivory ↔ 진차콜)
    static let canvas   = dyn(0xF4EFE6, 0x1A1A1C)
    static let surface  = dyn(0xFFFFFF, 0x2A2A2D)
    static let surface2 = dyn(0xFBF7F0, 0x222226)
    static let surface3 = dyn(0xF0EADE, 0x303035)

    // Ink (순수 검정 금지)
    static let ink   = dyn(0x211D17, 0xF3EFE7)
    static let ink2  = dyn(0x6B6256, 0xB8AFA0)
    static let ink3  = dyn(0xA89D8C, 0x8A8175)
    static let onPrimary = Color.white

    // Hairlines
    static let line  = dyn(0xE9E1D3, 0x3A3A40)
    static let line2 = dyn(0xDBD1BF, 0x47474D)

    // Brand sage
    static let primary      = dyn(0x4E8268, 0x8FBCA3)
    static let primaryPress = dyn(0x3F6B55, 0x6FA386)
    static let primarySoft  = dyn(0xDCEFE6, 0x24443A)
    static let primaryTint  = dyn(0xE1F5EE, 0x1F3C33)

    // Gold (Pro·골든 티어)
    static let gold     = dyn(0xB0832E, 0xD7A94E)
    static let goldTint = dyn(0xFAEEDA, 0x37301E)

    // Danger (응급·리콜)
    static let danger     = dyn(0xBE4D38, 0xE0735C)
    static let dangerTint = dyn(0xFAE2DB, 0x38201A)

    // 응급 모드 다크 (고정)
    static let emergencyBg     = Color(hex: 0x15110E)
    static let emergencyAction = Color(hex: 0xFF5C42)
    static let emergencyAccent = Color(hex: 0xFF8A72)

    // 임신 모드 강조
    static let pregnancyPink = Color(hex: 0xB5478A)
}

/// 뱃지 카테고리 팔레트 (색+아이콘+레이블 3중 인코딩 필수 — DESIGN.md §2.2)
enum BadgeTone: CaseIterable {
    case grey, mint, purple, amber, coral, pink, blue
    var bg: Color {
        switch self {
        case .grey:   return Color(hex: 0xF1EFE8)
        case .mint:   return Color(hex: 0xE1F5EE)
        case .purple: return Color(hex: 0xEEEDFE)
        case .amber:  return Color(hex: 0xFAEEDA)
        case .coral:  return Color(hex: 0xFAECE7)
        case .pink:   return Color(hex: 0xFBEAF0)
        case .blue:   return Color(hex: 0xE6F1FB)
        }
    }
    var ink: Color {
        switch self {
        case .grey:   return Color(hex: 0x877E6B)
        case .mint:   return Color(hex: 0x2E7A5C)
        case .purple: return Color(hex: 0x5B53B0)
        case .amber:  return Color(hex: 0x98711E)
        case .coral:  return Color(hex: 0xB45840)
        case .pink:   return Color(hex: 0xB5478A)
        case .blue:   return Color(hex: 0x3B6FA8)
        }
    }
}
