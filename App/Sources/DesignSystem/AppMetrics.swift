import SwiftUI

/// 간격 (4-base) — DESIGN.md §3.3
enum Spacing {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
    static let s9: CGFloat = 56
}

/// 라운드 — DESIGN.md §3.3
enum Radius {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let xl: CGFloat = 28
    static let pill: CGFloat = 999
}

/// 따뜻한 톤 그림자 — DESIGN.md §3.3 (단일 레이어 근사)
enum BLShadowKind { case chip, card, sheet, fab }

extension View {
    @ViewBuilder
    func blShadow(_ kind: BLShadowKind) -> some View {
        let warm = Color(hex: 0x282118)
        switch kind {
        case .chip:  self.shadow(color: warm.opacity(0.05), radius: 1.5, x: 0, y: 1)
        case .card:  self.shadow(color: warm.opacity(0.07), radius: 10, x: 0, y: 4)
        case .sheet: self.shadow(color: warm.opacity(0.12), radius: 22, x: 0, y: 10)
        case .fab:   self.shadow(color: AppColors.primary.opacity(0.32), radius: 9, x: 0, y: 6)
        }
    }
}
