import SwiftUI

/// 타이포 스케일 — DESIGN.md §4 / babylog-ds.css (Pretendard 번들 전까지 시스템 폰트)
/// TODO: Pretendard Variable 번들 + Dynamic Type relativeTo 매핑 (DESIGN.md §4.3)
enum AppFont {
    static let display = Font.system(size: 34, weight: .heavy)
    static let h1      = Font.system(size: 27, weight: .bold)
    static let h2      = Font.system(size: 22, weight: .bold)
    static let title   = Font.system(size: 18, weight: .semibold)
    static let body    = Font.system(size: 16, weight: .regular)
    static let callout = Font.system(size: 15, weight: .regular)
    static let subhead = Font.system(size: 14, weight: .medium)
    static let caption = Font.system(size: 13, weight: .medium)
    static let micro   = Font.system(size: 11, weight: .bold)

    /// 숫자 고정폭 (키·몸무게·날짜 정렬)
    static func num(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}
