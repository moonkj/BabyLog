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
    // Surfaces — 클린 화이트 (TickLab 프리미엄 참고) / 다크는 딥 인디고
    static let canvas   = dyn(0xFFFFFF, 0x0F1118)
    static let surface  = dyn(0xFFFFFF, 0x171922)
    static let surface2 = dyn(0xF7F8FA, 0x1F2230)
    static let surface3 = dyn(0xEFF1F4, 0x2C3040)

    // Ink — 딥 인디고 텍스트 (순수 검정 금지)
    static let ink   = dyn(0x1A1B2E, 0xF2F2F7)
    static let ink2  = dyn(0x404040, 0xAEB2C2)
    static let ink3  = dyn(0x737373, 0x7E8295)
    static let onPrimary = Color.white

    // Hairlines — 뉴트럴 그레이
    static let line  = dyn(0xE5E5E5, 0x2C3040)
    static let line2 = dyn(0xD4D4D4, 0x3A3F52)

    // Brand primary — 세이지 그린 (흰색·골드·세이지 팔레트)
    static let primary      = dyn(0x4E8268, 0x7FB89E)
    static let primaryPress = dyn(0x3F6B55, 0x6BA88B)
    static let primarySoft  = dyn(0xDCEFE6, 0x24332C)
    static let primaryTint  = dyn(0xE1F5EE, 0x1C2A23)

    // Accent — 앤티크 골드 (TickLab 럭셔리 시그니처 / Pro·골든 티어)
    static let gold     = dyn(0xC9A961, 0xD8B973)
    static let goldTint = dyn(0xFAF6E8, 0x322D1C)

    // 브랜드 코어 — 앱 아이콘·스플래시 정체성 색(크림 배경·금색 링·잎 그린).
    // 감정 피크 화면(저장 보상·뱃지)에 재등장시켜 "하나의 세계관"으로 묶는다(고정색 — 아이콘과 동일).
    static let brandCreamHi = Color(hex: 0xF5EDDC)
    static let brandCreamLo = Color(hex: 0xE3D4BA)
    static let brandLeaf    = Color(hex: 0x2E7A5C)
    static let brandRingTop = Color(hex: 0xEBC56C)
    static let brandRingBot = Color(hex: 0xC9A24B)

    // Danger (응급·리콜) — 딥 레드
    static let danger     = dyn(0xB5363A, 0xE86B6F)
    static let dangerTint = dyn(0xF7E6E7, 0x3A211B)

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
