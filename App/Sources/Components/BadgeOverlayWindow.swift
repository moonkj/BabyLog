// BadgeOverlayWindow.swift
// BabyLog — 뱃지 획득 카드 윈도우 레벨 표시
//
// SwiftUI의 .overlay는 UIKit이 올린 시트(.sheet)·풀스크린 커버 위로 올라가지 못한다.
// 그래서 매물 등록 성공 시트 등이 떠 있는 동안 축하 카드가 뒤에 가려지고, 스크림도
// 화면 일부만 덮였다. 별도 UIWindow(alert 레벨)에 카드를 띄워 항상 최상단·전체 화면으로 보이게 한다.

import SwiftUI
import UIKit

@MainActor
enum BadgeOverlayWindow {
    private static var window: UIWindow?

    /// 뱃지 카드를 최상단 윈도우에 띄운다. 이미 떠 있으면 교체(연속 획득).
    static func show(_ badge: BadgeCatalogItem, onDismiss: @escaping () -> Void) {
        hide()
        guard let scene = activeScene() else { onDismiss(); return }
        let host = UIHostingController(
            rootView: BadgeAwardCard(badge: badge) {
                hide()
                onDismiss()
            }
        )
        host.view.backgroundColor = .clear   // 카드 자체의 풀스크린 스크림만 보이게
        let w = UIWindow(windowScene: scene)
        w.rootViewController = host
        w.windowLevel = .alert + 1           // 시트보다 위
        w.backgroundColor = .clear
        w.isHidden = false
        window = w
    }

    static func hide() {
        window?.isHidden = true
        window = nil
    }

    private static func activeScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
