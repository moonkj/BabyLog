import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 모션 토큰 — DESIGN.md §7.1 · §8
///
/// 원칙: 200~300ms 이내, ease-out 통일. bounce(탄성)는 감정 피크·축하에만.
/// transform(scale·rotation·offset)·opacity만 애니메이션해 60fps 보장.
/// reduce motion 설정 시 `respecting(_:_:)`으로 정적 대체.
enum Motion {
    /// 표준 진입·전환 (기능적 모션)
    static let standard: Animation = .easeOut(duration: 0.24)
    /// 빠른 미세 피드백 (탭·토글·칩)
    static let micro: Animation = .easeOut(duration: 0.16)
    /// 감정 피크 보상 (저장 하트 등) — 약한 탄성
    static let reward: Animation = .spring(response: 0.32, dampingFraction: 0.6)
    /// 축하 (이정표·뱃지) — 특별 이벤트 한정 화려한 탄성
    static let celebrate: Animation = .spring(response: 0.46, dampingFraction: 0.55)

    /// reduce motion이면 nil(정적 스냅), 아니면 주어진 애니메이션.
    static func respecting(_ reduceMotion: Bool, _ anim: Animation) -> Animation? {
        reduceMotion ? nil : anim
    }
}

/// 햅틱 피드백 중앙화 — DESIGN.md §8.5(미세 피드백).
/// 절제해서 의미 있는 순간에만 사용한다. 비난성 진동은 쓰지 않는다.
enum Haptics {
    static func light() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func soft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
    /// 저장·달성 등 긍정 완료
    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    /// 검증 실패 — 가벼운 환기용(비난 톤 아님)
    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
    /// 선택 변경(세그먼트·칩 전환)
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}
