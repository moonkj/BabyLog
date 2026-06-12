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

    /// 동네 진입 시 호출: (1) 내 기기 자동 카운트(기기당 1회 — 재입장해도 누적 안 됨)
    /// (2) 목표 인원 도달 시 동네당 1회 자동 로컬 알림.
    /// - Returns: 현재 동네 신청 수(미구성/실패 시 nil)
    @discardableResult
    static func syncNeighborhood(hood: String) async -> Int? {
        guard SupabaseConfig.isConfigured, !hood.isEmpty, hood != "우리 동네" else { return nil }

        // 0) 푸시 토큰 hood 최신화 — 앱 시작 시 위치 미확보로 hood가 비었을 수 있음
        if let tok = UserDefaults.standard.string(forKey: "bl_apns_token") {
            await uploadPushToken(tok, hood: hood)
        }

        // 1) 자동 등록 — 로컬 dedup + 서버 unique(hood,device_id)로 이중 중복 방지
        let regKey = "crew_registered_hoods"
        var registered = Set(UserDefaults.standard.stringArray(forKey: regKey) ?? [])
        if !registered.contains(hood), await joinWaitlist(hood: hood) {
            registered.insert(hood)
            UserDefaults.standard.set(Array(registered), forKey: regKey)
        }

        // 2) 현재 수 + 오픈 시 자동 알림(동네당 1회)
        guard let count = await waitlistCount(hood: hood) else { return nil }
        if count >= openThreshold {
            let notifiedKey = "crew_opened_notified_hoods"
            var notified = Set(UserDefaults.standard.stringArray(forKey: notifiedKey) ?? [])
            if !notified.contains(hood) {
                notified.insert(hood)
                UserDefaults.standard.set(Array(notified), forKey: notifiedKey)
                let center = UNPendingScheduler()
                if await center.requestAuthorization() {
                    center.schedule([LocalNotificationRequest(
                        id: "crew_open_\(hood)",
                        title: "🌱 \(hood) 크루가 열렸어요",
                        body: "이웃이 충분히 모였어요. 동네 크루를 확인해 보세요.",
                        fireDate: Date().addingTimeInterval(3)
                    )])
                }
            }
        }
        return count
    }

    /// APNs 푸시 토큰 등록/갱신(기기당 1행 upsert). 실시간 오픈 푸시용.
    static func uploadPushToken(_ apnsToken: String, hood: String?) async {
        guard SupabaseConfig.isConfigured, !apnsToken.isEmpty,
              var req = request("/rest/v1/crew_push_token?on_conflict=device_id", method: "POST") else { return }
        req.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        var body: [String: Any] = [
            "device_id": SupabaseConfig.deviceID,
            "apns_token": apnsToken,
            "updated_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let hood, !hood.isEmpty, hood != "우리 동네" { body["hood"] = hood }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
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
