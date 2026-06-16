// KeyboardDismiss.swift
// BabyLog · 키보드 닫기 공용 — 검색·입력 후 다른 곳을 탭/스크롤하면 키보드가 내려가게 한다.
//
// 두 갈래로 처리:
//  ① blHideKeyboard()/hideKeyboard() — 버튼 액션 등에서 명시적으로 내림.
//  ② KeyboardDismissTap — 키 윈도우에 탭 제스처(cancelsTouchesInView=false)를 달아
//     '화면 아무 곳이나 탭하면' 키보드가 내려가게 한다(버튼·스크롤은 그대로 동작). 앱 전역 적용.

import SwiftUI
import UIKit

@MainActor
func blHideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

extension View {
    /// 키보드를 즉시 내린다(버튼 액션·탭 등에서 호출).
    func hideKeyboard() { blHideKeyboard() }
}

/// 키 윈도우 전역 탭→키보드 닫기. 다른 터치를 가로채지 않아(버튼/스크롤 정상) 모든 화면에 일괄 적용된다.
@MainActor
final class KeyboardDismissTap: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissTap()
    private static let gestureName = "blKeyboardDismissTap"

    /// 키 윈도우에 1회만 설치. 윈도우가 아직 없으면 무시(다음 호출에서 재시도).
    func install() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows }).first
        else { return }
        if window.gestureRecognizers?.contains(where: { $0.name == Self.gestureName }) == true { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.name = Self.gestureName
        tap.cancelsTouchesInView = false   // 버튼/리스트 탭을 막지 않음
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func handleTap() { blHideKeyboard() }

    // 다른 제스처(스크롤·버튼)와 동시에 인식 — 어떤 동작도 가로채지 않는다.
    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer,
                                       shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
