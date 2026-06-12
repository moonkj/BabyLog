// CrewBackend.swift
// BabyLog — Networking
//
// 크루(동네 모임) 백엔드 — Supabase PostgREST 직접 호출(SDK 의존성 없이 URLSession).
// 동네별 대기 신청/카운트. 키(SUPABASE_URL/ANON) 없으면 비활성(목업 폴백, B4 정책).
//
// 절대 원칙: 아동·개인정보 비저장. 동네명 + 익명 기기 UUID만 전송.

import Foundation

enum SupabaseConfig {
    static var url: String? {
        guard let u = APIConfig.key("SUPABASE_URL") else { return nil }
        return u.hasSuffix("/") ? String(u.dropLast()) : u
    }
    static var anonKey: String? { APIConfig.key("SUPABASE_ANON_KEY") }
    static var isConfigured: Bool { url != nil && anonKey != nil }

    /// 익명 기기 식별 — 영구 저장(개인정보·아동데이터 아님).
    static var deviceID: String {
        let k = "bl_device_id"
        if let s = UserDefaults.standard.string(forKey: k) { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: k)
        return s
    }
}

enum CrewBackend {
    /// 크루 자동 오픈 목표 인원(동네별).
    static let openThreshold = 30

    private static func request(_ path: String, method: String) -> URLRequest? {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(SupabaseConfig.deviceID, forHTTPHeaderField: "x-device-id")
        return req
    }

    /// 동네 대기 신청(중복은 병합). 성공 true.
    @discardableResult
    static func joinWaitlist(hood: String) async -> Bool {
        guard SupabaseConfig.isConfigured, var req = request("/rest/v1/crew_waitlist", method: "POST") else { return false }
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hood": hood, "device_id": SupabaseConfig.deviceID,
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 동네별 신청 수(RPC). 실패/미구성 시 nil.
    static func waitlistCount(hood: String) async -> Int? {
        guard SupabaseConfig.isConfigured, var req = request("/rest/v1/rpc/crew_waitlist_count", method: "POST") else { return nil }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_hood": hood])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        if let n = try? JSONDecoder().decode(Int.self, from: data) { return n }
        if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), let n = Int(s) { return n }
        return nil
    }
}
