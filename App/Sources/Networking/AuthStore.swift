// AuthStore.swift
// BabyLog · Networking — Supabase GoTrue 세션(Apple 로그인) 관리
// SDK 없이 REST 직결: /auth/v1/token(id_token·refresh) + Keychain 보관.
// 자세한 설계: docs/AUTH_SETUP.md
// ⚠️ 비로그인이면 session=nil → CrewBackend는 기존처럼 anon key로 동작(회귀 없음).

import Foundation
import Security

/// 저장 세션(Keychain). access/refresh 토큰 + 만료 + auth user id.
struct StoredSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userId: String
}

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    @Published private(set) var session: StoredSession?
    var isLoggedIn: Bool { session != nil }
    var userId: String? { session?.userId }

    private init() { session = Keychain.loadSession() }

    // MARK: - 토큰 제공(CrewBackend가 호출)

    /// 유효한 access token. 만료 임박 시 refresh 후 반환. 세션 없으면 nil → anon 폴백.
    func validAccessToken() async -> String? {
        guard let s = session else { return nil }
        if s.expiresAt > Date().addingTimeInterval(60) { return s.accessToken }
        return await refresh()?.accessToken
    }

    // MARK: - Apple 로그인

    /// Apple id_token + nonce를 GoTrue로 교환 → 세션 저장 + 기존 익명 콘텐츠 귀속(claim_device).
    @discardableResult
    func appleSignIn(idToken: String, nonce: String, fullName: String?) async -> Bool {
        guard let url = tokenURL(grant: "id_token"), let key = SupabaseConfig.anonKey else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "provider": "apple", "id_token": idToken, "nonce": nonce,
        ])
        guard let parsed = await exchange(req) else { return false }
        persist(parsed)
        // 닉네임은 Apple이 최초 1회만 제공 → 비어 있을 때만 기본값으로 채움.
        if let fullName, !fullName.isEmpty,
           (UserDefaults.standard.string(forKey: "bl_nickname") ?? "").isEmpty {
            UserDefaults.standard.set(fullName, forKey: "bl_nickname")
        }
        await claimDevice()
        return true
    }

    // MARK: - 갱신 / 로그아웃

    private func refresh() async -> StoredSession? {
        guard let s = session, let url = tokenURL(grant: "refresh_token"), let key = SupabaseConfig.anonKey else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": s.refreshToken])
        guard let parsed = await exchange(req) else {
            await signOut(remote: false)   // refresh 실패 = 세션 만료 → 로컬 정리
            return nil
        }
        persist(parsed)
        return parsed
    }

    func signOut(remote: Bool = true) async {
        if remote, let s = session, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
           let url = URL(string: "\(base)/auth/v1/logout") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"; req.timeoutInterval = 10
            req.setValue(key, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(s.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        Keychain.deleteSession()
        session = nil
    }

    // MARK: - 익명→계정 귀속

    /// 로그인 직후 1회: 내 기기 UUID로 만든 콘텐츠를 auth.uid()로 귀속(서버 RPC).
    private func claimDevice() async {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let token = session?.accessToken,
              let url = URL(string: "\(base)/rest/v1/rpc/claim_device") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_device": SupabaseConfig.deviceID])
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - 계정 삭제(Apple 가이드라인 의무)

    /// Edge Function `delete-account`(service_role로 auth user 삭제) 호출 후 로컬 세션 정리.
    /// ⚠️ 함수 미배포 시 실패(false) — 로그인 출시 전 배포 필요(supabase/functions/delete-account).
    @discardableResult
    func deleteAccount() async -> Bool {
        guard let token = await validAccessToken(), let base = SupabaseConfig.url,
              let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/delete-account") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        await signOut(remote: false)
        return true
    }

    // MARK: - helpers

    private func tokenURL(grant: String) -> URL? {
        guard let base = SupabaseConfig.url else { return nil }
        return URL(string: "\(base)/auth/v1/token?grant_type=\(grant)")
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Int
        struct U: Decodable { let id: String }
        let user: U
    }

    private func exchange(_ req: URLRequest) async -> StoredSession? {
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let t = try? JSONDecoder().decode(TokenResponse.self, from: data) else { return nil }
        return StoredSession(
            accessToken: t.access_token,
            refreshToken: t.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(t.expires_in)),
            userId: t.user.id
        )
    }

    private func persist(_ s: StoredSession) {
        session = s
        Keychain.saveSession(s)
    }
}

// MARK: - Keychain (세션 전용 미니 래퍼)

private enum Keychain {
    private static let service = "com.vibelab.babylog"
    private static let account = "supabase.session"

    static func saveSession(_ s: StoredSession) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadSession() -> StoredSession? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data,
              let s = try? JSONDecoder().decode(StoredSession.self, from: data) else { return nil }
        return s
    }

    static func deleteSession() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(q as CFDictionary)
    }
}
