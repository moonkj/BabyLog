// ReportBackend.swift
// BabyLog · 신고 제출(bl_report) + 운영자 조회(admin-reports Edge).
// 신고는 누구나 제출, 조회는 운영자(비번 게이트 Edge)만.

import Foundation

/// 신고 시점 대화 스냅샷 한 줄(증거). 크루={author,text}, 마켓={text,mine,date} 양쪽을 수용.
struct TranscriptLine: Decodable, Identifiable {
    let id = UUID()
    let author: String?
    let text: String?
    let mine: Bool?
    enum CodingKeys: String, CodingKey { case author, text, mine }
    /// 표시용 발신자 라벨.
    var speaker: String {
        if let a = author, !a.isEmpty { return a }
        if let m = mine { return m ? "신고자" : "상대" }
        return "메시지"
    }
}

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
    let transcript: [TranscriptLine]?
    let created_at: String?
}

/// 운영자 콘텐츠 관리용 — 모임/크루/매물/게시글 한 줄.
struct AdminContentRow: Identifiable, Decodable {
    let id: String
    let title: String?       // 모임 title / 매물 title / 게시글 title
    let name: String?        // 크루 그룹 name
    let hood: String?
    let host_name: String?   // 모임 주최자
    let creator_name: String? // 그룹 생성자
    let seller_name: String? // 매물 판매자
    let author_name: String? // 게시글 작성자
    let status: String?      // 매물 상태
    let when_text: String?   // 모임 일시
    let category: String?    // 게시글 분류
    let created_at: String?
    let expires_at: String?
}

/// op=list 응답.
struct AdminContent: Decodable {
    let meetups: [AdminContentRow]
    let groups: [AdminContentRow]
    let items: [AdminContentRow]
    let posts: [AdminContentRow]
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

    /// 운영자 — 콘텐츠 목록(모임/크루/매물/게시글) 조회(admin-action op=list). 실패 시 nil.
    static func adminListContent(pass: String) async -> AdminContent? {
        guard let data = await adminAction(pass: pass, body: ["op": "list"]) else { return nil }
        return try? JSONDecoder().decode(AdminContent.self, from: data)
    }

    /// 운영자 — 콘텐츠 삭제(admin-action op=delete). kind: crew_meetup/crew_group/market_item/crew_post.
    @discardableResult
    static func adminDelete(pass: String, kind: String, id: String) async -> Bool {
        await adminAction(pass: pass, body: ["op": "delete", "kind": kind, "id": id]) != nil
    }

    /// admin-action Edge 공통 호출 — 성공(2xx) 시 응답 바디, 실패 시 nil.
    private static func adminAction(pass: String, body: [String: Any]) async -> Data? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/admin-action") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload = body; payload["pass"] = pass
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return data
    }
}
