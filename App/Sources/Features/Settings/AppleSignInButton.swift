// AppleSignInButton.swift
// BabyLog · Sign in with Apple → Supabase Auth (AuthStore)
// nonce: 평문 생성 → SHA256은 Apple 요청에, 평문은 Supabase 교환에 전달.

import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppleSignInButton: View {
    /// 로그인 결과(성공 여부) 콜백.
    var onResult: (Bool) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    @State private var currentNonce: String?

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            let nonce = Self.randomNonce()
            currentNonce = nonce
            // 이름은 받지 않는다 — 공개 닉네임은 사용자가 직접 설정(실명 비노출·프라이버시 원칙).
            request.requestedScopes = []
            request.nonce = Self.sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let auth):
                guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                      let tokenData = cred.identityToken,
                      let idToken = String(data: tokenData, encoding: .utf8),
                      let nonce = currentNonce else { onResult(false); return }
                Task {
                    let ok = await AuthStore.shared.appleSignIn(
                        idToken: idToken, nonce: nonce, fullName: nil)
                    onResult(ok)
                }
            case .failure(let error):
                // 사용자가 Apple 시트를 닫은 경우(취소)는 오류가 아니므로 조용히 무시.
                if let e = error as? ASAuthorizationError, e.code == .canceled { return }
                onResult(false)
            }
        }
        .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityLabel("Apple로 로그인")
    }

    // MARK: - nonce helpers

    static func randomNonce(_ length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else { continue }
            if Int(byte) < charset.count {
                result.append(charset[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
