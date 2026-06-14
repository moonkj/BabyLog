// ReportBackend.swift
// BabyLog · 신고 제출(bl_report) + 운영자 조회(admin-reports Edge).
// 신고는 누구나 제출, 조회는 운영자(비번 게이트 Edge)만.

import Foundation

/// 운영자 화면용 신고 항목.
struct AdminReport: Identifiable, Decodable {
    let id: String
    let reporter: String?
    let reported: String?
    let reported_name: String?
    let surface: String?
    let context_id: String?
    let reason: String?
    let note: String?
    let created_at: String?
}

enum ReportBackend {
    static let reasons = ["욕설·비방", "사기·허위 정보", "부적절한 사진/내용", "광고·스팸", "안전 위협", "기타"]

    private static func authBearer() async -> String {
        if let t = await AuthStore.shared.validAccessToken() { return t }
        return SupabaseConfig.anonKey ?? ""
    }

    /// 신고 제출. surface 예: market_chat / crew_meetup / crew_group / market_item / crew_post.
    @discardableResult
    static func submit(surface: String, contextId: String?, reportedName: String?, reportedId: String?,
                       reason: String, note: String? = nil, transcript: [[String: String]] = []) async -> Bool {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/rest/v1/bl_report") else { return false }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // reporter RLS 매칭
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var body: [String: Any] = [
            "reporter": await SupabaseConfig.ownerID(),
            "surface": surface, "reason": reason, "transcript": transcript,
        ]
        if let contextId { body["context_id"] = contextId }
        if let reportedName { body["reported_name"] = String(reportedName.prefix(40)) }
        if let reportedId { body["reported"] = reportedId }
        if let note, !note.isEmpty { body["note"] = String(note.prefix(500)) }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 운영자 — 비밀번호로 신고 목록 조회(Edge admin-reports). 실패/권한없음 시 nil.
    static func adminFetch(pass: String) async -> [AdminReport]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/admin-reports") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["pass": pass])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        struct Wrap: Decodable { let reports: [AdminReport] }
        return (try? JSONDecoder().decode(Wrap.self, from: data))?.reports
    }
}
