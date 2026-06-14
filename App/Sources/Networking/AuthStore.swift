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

    /// 신규 설치 감지 플래그 — UserDefaults는 앱 삭제 시 초기화되지만 Keychain은 유지된다.
    private static let installFlagKey = "bl_keychain_install_flag"

    private init() {
        // 앱을 지웠다 새로 깔면(첫 실행 플래그 없음) Keychain에 남은 세션을 지워 로그아웃 상태로 시작.
        // (Keychain은 앱 삭제 후에도 남아 "지웠는데 로그인됨"이 발생 — 이를 차단.)
        if !UserDefaults.standard.bool(forKey: Self.installFlagKey) {
            Keychain.deleteSession()
            UserDefaults.standard.set(true, forKey: Self.installFlagKey)
        }
        session = Keychain.loadSession()
        // 세션 복원 경로 — 과거 claim_device가 실패(오프라인 등)했으면 여기서 재시도해 영구 누락 방지.
        if session != nil {
            Task { await self.retryClaimIfNeeded() }
        }
    }

    /// 진행 중인 refresh 1개를 공유 — 동시 호출이 단일 사용(refresh token)을 두 번 쓰는 레이스 방지.
    private var refreshTask: Task<StoredSession?, Never>?

    // MARK: - 토큰 제공(CrewBackend가 호출)

    /// 유효한 access token. 만료 임박 시 refresh 후 반환. 세션 없으면 nil → anon 폴백.
    func validAccessToken() async -> String? {
        guard let s = session else { return nil }
        if s.expiresAt > Date().addingTimeInterval(60) { return s.accessToken }
        // 이미 refresh 진행 중이면 합류(coalesce). @MainActor라 체크-앤-셋이 원자적.
        if let task = refreshTask { return await task.value?.accessToken }
        let task = Task { await self.refresh() }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result?.accessToken
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
        // ⚠️ Apple 실명을 공개 닉네임으로 자동 저장하지 않는다(프라이버시·성별중립·실명 비노출 원칙).
        //    닉네임은 사용자가 설정에서 직접 정하는 값. fullName은 인증에만 쓰고 보관하지 않음.
        _ = fullName
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
        let (parsed, status) = await exchangeDetailed(req)
        if let parsed {
            persist(parsed)
            return parsed
        }
        // 400/401/403 = refresh token이 확정적으로 무효 → 그때만 로컬 정리.
        // 그 외(네트워크 오류 status=nil, 5xx 등)는 일시 장애 → 세션 유지, 이번 요청만 anon 폴백.
        if let status, [400, 401, 403].contains(status) {
            await signOut(remote: false)
        }
        return nil
    }

    func signOut(remote: Bool = true) async {
        // 만료된 accessToken으로 logout을 부르면 401로 무음 실패(서버 측 refresh token 미회수)
        // → validAccessToken() 경유로 필요 시 갱신된 유효 토큰을 쓴다. 갱신도 불가하면 원격 해지 생략.
        if remote, session != nil, let token = await validAccessToken(),
           let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
           let url = URL(string: "\(base)/auth/v1/logout") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"; req.timeoutInterval = 10
            req.setValue(key, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        Keychain.deleteSession()
        session = nil
    }

    // MARK: - 익명→계정 귀속

    /// claim_device 완료 플래그 키 — uid별로 기록(다른 계정 로그인 시 별도 수행).
    private func claimDoneKey(_ uid: String) -> String { "bl_claim_done_\(uid)" }

    /// 로그인 직후 1회: 내 기기 UUID로 만든 콘텐츠를 auth.uid()로 귀속(서버 RPC).
    /// 결과를 무시(_ = try?)하면 일시 실패가 영구 누락이 되므로, 2xx 확인 후에만 완료 플래그를 저장
    /// → 실패 시 다음 세션 복원에서 retryClaimIfNeeded()가 재시도한다.
    private func claimDevice() async {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let token = session?.accessToken, let uid = session?.userId,
              let url = URL(string: "\(base)/rest/v1/rpc/claim_device") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_device": SupabaseConfig.deviceID])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }
        UserDefaults.standard.set(true, forKey: claimDoneKey(uid))
    }

    /// 세션 복원/로그인 시 호출 — 완료 플래그가 없으면 claim_device를 재시도(멱등 RPC라 중복 호출 안전).
    func retryClaimIfNeeded() async {
        guard let uid = session?.userId,
              !UserDefaults.standard.bool(forKey: claimDoneKey(uid)) else { return }
        await claimDevice()
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
        await exchangeDetailed(req).session
    }

    /// 토큰 교환 + HTTP 상태 구분. status=nil은 전송 계층 오류(오프라인·타임아웃 등).
    private func exchangeDetailed(_ req: URLRequest) async -> (session: StoredSession?, status: Int?) {
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return (nil, nil) }
        guard (200...299).contains(http.statusCode),
              let t = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            return (nil, http.statusCode)
        }
        let s = StoredSession(
            accessToken: t.access_token,
            refreshToken: t.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(t.expires_in)),
            userId: t.user.id
        )
        return (s, http.statusCode)
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
        let deleteStatus = SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        #if DEBUG
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            print("[AuthStore] Keychain delete 실패: \(deleteStatus)")
        }
        if addStatus != errSecSuccess {
            print("[AuthStore] Keychain save 실패: \(addStatus)")
        }
        #endif
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
        let status = SecItemDelete(q as CFDictionary)
        #if DEBUG
        if status != errSecSuccess && status != errSecItemNotFound {
            print("[AuthStore] Keychain delete 실패: \(status)")
        }
        #endif
    }
}
