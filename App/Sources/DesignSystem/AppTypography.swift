import SwiftUI

/// 타이포 스케일 — DESIGN.md §4 / babylog-ds.css (Pretendard 번들 전까지 시스템 폰트)
///
/// 접근성(Dynamic Type): 각 토큰을 의미가 가장 가까운 텍스트 스타일에 매핑해 사용자 글씨 크기에
/// 실시간 반응하도록 한다(고정 pt → 스케일 폰트). 기준(기본 설정) 크기는 기존과 거의 동일하게 유지.
/// 과대 확대로 레이아웃이 깨지지 않도록 앱 루트에서 dynamicTypeSize 상한을 둔다(BabyLogApp/MainTabView).
enum AppFont {
    static let display = Font.system(.largeTitle, design: .default).weight(.heavy)   // ~34
    static let h1      = Font.system(.title,      design: .default).weight(.bold)    // ~28
    static let h2      = Font.system(.title2,     design: .default).weight(.bold)    // ~22
    static let title   = Font.system(.title3,     design: .default).weight(.semibold)// ~20
    static let body    = Font.system(.body,       design: .default)                  // ~17
    static let callout = Font.system(.callout,    design: .default)                  // ~16
    static let subhead = Font.system(.subheadline, design: .default).weight(.medium) // ~15
    static let caption = Font.system(.footnote,   design: .default).weight(.medium)  // ~13
    static let micro   = Font.system(.caption2,   design: .default).weight(.bold)    // ~11

    /// 숫자 고정폭(키·몸무게·날짜 정렬) — 임의 pt도 가장 가까운 텍스트 스타일로 매핑해 Dynamic Type 스케일.
    static func num(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(numStyle(for: size), design: .default).weight(weight).monospacedDigit()
    }

    private static func numStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12:  return .caption2
        case ..<13.5: return .footnote
        case ..<16:  return .subheadline
        case ..<18:  return .body
        case ..<21:  return .title3
        case ..<25:  return .title2
        case ..<31:  return .title
        default:     return .largeTitle
        }
    }
}
