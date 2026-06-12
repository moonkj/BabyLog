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

    /// 익명 기기 식별 — 영구 저장(개인정보·아동데이터 아님). 푸시토큰·대기신청·사진경로 등 기기 단위에 사용.
    static var deviceID: String {
        let k = "bl_device_id"
        if let s = UserDefaults.standard.string(forKey: k) { return s }
        let s = UUID().uuidString
        UserDefaults.standard.set(s, forKey: k)
        return s
    }

    /// 콘텐츠 소유자 식별 — 로그인 시 auth user id, 아니면 기기ID.
    /// 소유자 기반 RLS(본인 글만 수정/삭제)의 기준. 글·모임·그룹·매물·댓글·좋아요·신고의 owner 컬럼에 사용.
    static func ownerID() async -> String {
        if let uid = await AuthStore.shared.userId { return uid }
        return deviceID
    }
}

enum CrewBackend {
    /// 크루 자동 오픈 목표 인원(동네별).
    static let openThreshold = 30

    private static func request(_ path: String, method: String) async -> URLRequest? {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        return req
    }

    /// PostgREST Authorization Bearer — 로그인 세션이 있으면 user access token, 없으면 anon key.
    private static func authBearer() async -> String {
        if let t = await AuthStore.shared.validAccessToken() { return t }
        return SupabaseConfig.anonKey ?? ""
    }

    // 서버 전송 전 길이 상한(스팸·대용량 페이로드 방어). 무료 RLS(using true) 보강용.
    private enum Cap { static let name = 40, title = 120, body = 2000, place = 80, tag = 20 }
    private static func cap(_ s: String, _ max: Int) -> String { String(s.prefix(max)) }

    /// 동네 대기 신청(중복은 병합). 성공 true.
    @discardableResult
    static func joinWaitlist(hood: String) async -> Bool {
        // on_conflict 미지정 시 PK(id) 기준 병합 → (hood,device_id) unique 충돌이 409로 떨어짐(재설치 후 영구 실패)
        guard SupabaseConfig.isConfigured, var req = await request("/rest/v1/crew_waitlist?on_conflict=hood,device_id", method: "POST") else { return false }
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

        // 2) 목표 도달 시 서버 함수 호출 → 그 동네 모든 기기에 실시간 푸시(서버가 중복 발송 방지)
        guard let count = await waitlistCount(hood: hood) else { return nil }
        if count >= openThreshold {
            await invokeOpenNotify(hood: hood)
        }
        return count
    }

    /// Edge Function(notify-crew-open) 호출 — 동네 오픈 푸시 팬아웃(서버에서 crew_hood_status로 1회만).
    private static func invokeOpenNotify(hood: String) async {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/notify-crew-open") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["hood": hood])
        _ = try? await URLSession.shared.data(for: req)
    }

    /// APNs 푸시 토큰 등록/갱신(기기당 1행 upsert). 실시간 오픈 푸시용.
    static func uploadPushToken(_ apnsToken: String, hood: String?) async {
        guard SupabaseConfig.isConfigured, !apnsToken.isEmpty,
              var req = await request("/rest/v1/crew_push_token?on_conflict=device_id", method: "POST") else { return }
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
        guard SupabaseConfig.isConfigured, var req = await request("/rest/v1/rpc/crew_waitlist_count", method: "POST") else { return nil }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_hood": hood])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        if let n = try? JSONDecoder().decode(Int.self, from: data) { return n }
        if let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), let n = Int(s) { return n }
        return nil
    }

    // MARK: - 게시판(동네 공유 글)

    private struct CrewPostDTO: Decodable {
        let id: String
        let category: String?
        let author: String?
        let author_name: String?
        let title: String
        let body: String?
        let created_at: String?
        let crew_post_like: [CountRow]?
        let crew_post_reply: [CountRow]?
        struct CountRow: Decodable { let count: Int }
    }

    /// 동네 게시글 최신순 조회(좋아요·댓글 수 포함). 미구성/실패 시 nil(→ 로컬 폴백).
    static func fetchPosts(hood: String) async -> [CrewPost]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !hood.isEmpty, hood != "우리 동네",
              let h = hood.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,category,author,author_name,title,body,created_at,crew_post_like(count),crew_post_reply(count)"
        let s = "\(base)/rest/v1/crew_post?hood=eq.\(h)&select=\(select)&order=created_at.desc&limit=50"
        guard let url = URL(string: s) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[CrewBackend] fetchPosts HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([CrewPostDTO].self, from: data) else { return nil }
        let me = await SupabaseConfig.ownerID()
        return dtos.map { d in
            CrewPost(
                id: d.id,
                category: CrewPostCategory(rawValue: d.category ?? "") ?? .info,
                authorName: d.author_name ?? "이웃",
                timeText: Self.relativeTime(d.created_at),
                title: d.title,
                body: d.body ?? "",
                replyCount: d.crew_post_reply?.first?.count ?? 0,
                likeCount: d.crew_post_like?.first?.count ?? 0,
                mine: d.author == me
            )
        }
    }

    /// 동네 게시글 작성(공유). 성공 true.
    @discardableResult
    static func createPost(hood: String, category: String, title: String, body: String, authorName: String) async -> Bool {
        guard SupabaseConfig.isConfigured, !hood.isEmpty, hood != "우리 동네",
              var req = await request("/rest/v1/crew_post", method: "POST") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hood": hood, "category": category, "author": await SupabaseConfig.ownerID(),
            "author_name": cap(authorName, Cap.name), "title": cap(title, Cap.title), "body": cap(body, Cap.body),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 게시글 삭제(소유자 RLS — 본인 글만). return=representation + 비어있지 않은 배열이어야 성공.
    @discardableResult
    static func deletePost(postId: String) async -> Bool {
        guard SupabaseConfig.isConfigured,
              let p = postId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              var req = await request("/rest/v1/crew_post?id=eq.\(p)", method: "DELETE") else { return false }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")  // RLS 0행 매칭(가짜 성공) 감지용
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any], !rows.isEmpty else { return false }
        return true
    }

    // MARK: - 모임(동네 공유)

    private struct CrewMeetupDTO: Decodable {
        let id: String
        let place: String?
        let when_text: String?
        let meetup_type: String?
        let capacity: Int?
        let host: String?
        let host_name: String?
        let crew_meetup_join: [CrewPostDTO.CountRow]?
    }

    /// 동네 모임 최신순 조회. 미구성/실패 시 nil(→ 로컬 폴백).
    static func fetchMeetups(hood: String) async -> [CrewMeetup]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !hood.isEmpty, hood != "우리 동네",
              let h = hood.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,place,when_text,meetup_type,capacity,host,host_name,crew_meetup_join(count)"
        guard let url = URL(string: "\(base)/rest/v1/crew_meetup?hood=eq.\(h)&select=\(select)&order=created_at.desc&limit=50") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[CrewBackend] fetchMeetups HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([CrewMeetupDTO].self, from: data) else { return nil }
        let me = await SupabaseConfig.ownerID()
        return dtos.map { d in
            CrewMeetup(
                id: d.id,
                place: d.place ?? "모임",
                when: d.when_text ?? "일정 협의",
                hostName: d.host_name ?? "이웃",
                hostTier: .new,   // 서버 모임: 실제 신뢰 티어 미산정 → '신규'로 정직 표기(가짜 '따뜻한 이웃' 금지)
                joined: d.crew_meetup_join?.first?.count ?? 0,
                capacity: d.capacity ?? 8,
                meetupType: CrewMeetupType(rawValue: d.meetup_type ?? "park") ?? .park,
                mine: d.host == me
            )
        }
    }

    /// 동네 모임 생성(+주최자 자동 참가). 새 모임 id 반환(실패 시 nil).
    @discardableResult
    static func createMeetup(hood: String, place: String, when: String, capacity: Int,
                             meetupType: String, hostName: String) async -> String? {
        guard SupabaseConfig.isConfigured, !hood.isEmpty, hood != "우리 동네",
              var req = await request("/rest/v1/crew_meetup", method: "POST") else { return nil }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hood": hood, "title": cap(place, Cap.place), "place": cap(place, Cap.place), "when_text": cap(when, Cap.place),
            "meetup_type": meetupType, "capacity": capacity,
            "host": await SupabaseConfig.ownerID(), "host_name": cap(hostName, Cap.name),
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let rows = try? JSONDecoder().decode([CrewMeetupDTO].self, from: data),
              let id = rows.first?.id else { return nil }
        await joinMeetup(meetupId: id)   // 주최자 자동 참가
        return id
    }

    /// 모임 삭제(소유자 RLS — 본인 모임만). PostgREST는 RLS 0행 매칭도 2xx이므로
    /// return=representation으로 실제 삭제된 행을 확인해야 성공(MarketBackend.setStatus와 동일 패턴).
    @discardableResult
    static func deleteMeetup(meetupId: String) async -> Bool {
        guard SupabaseConfig.isConfigured,
              let m = meetupId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              var req = await request("/rest/v1/crew_meetup?id=eq.\(m)", method: "DELETE") else { return false }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")  // RLS 0행 매칭(가짜 성공) 감지용
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any], !rows.isEmpty else { return false }
        return true
    }

    /// 모임 참가(crew_meetup_join upsert).
    @discardableResult
    static func joinMeetup(meetupId: String) async -> Bool {
        guard SupabaseConfig.isConfigured,
              var req = await request("/rest/v1/crew_meetup_join?on_conflict=meetup_id,device_id", method: "POST") else { return false }
        req.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "meetup_id": meetupId, "device_id": await SupabaseConfig.ownerID(),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - 그룹(동네 공유)

    private struct CrewGroupDTO: Decodable {
        let id: String
        let name: String?
        let age_range: String?
        let interest_tags: [String]?
        let crew_group_member: [CrewPostDTO.CountRow]?
    }

    /// 동네 그룹 최신순 조회. 미구성/실패 시 nil(→ 로컬 폴백).
    static func fetchGroups(hood: String) async -> [CrewGroup]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !hood.isEmpty, hood != "우리 동네",
              let h = hood.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,name,age_range,interest_tags,crew_group_member(count)"
        guard let url = URL(string: "\(base)/rest/v1/crew_group?hood=eq.\(h)&select=\(select)&order=created_at.desc&limit=50") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[CrewBackend] fetchGroups HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([CrewGroupDTO].self, from: data) else { return nil }
        return dtos.map { d in
            CrewGroup(
                id: d.id,
                name: d.name ?? "이웃 그룹",
                memberCount: d.crew_group_member?.first?.count ?? 0,
                distanceText: "우리 동네",
                ageRange: (d.age_range?.isEmpty == false ? d.age_range! : "전체"),
                interestTags: d.interest_tags ?? []
            )
        }
    }

    /// 동네 그룹 생성(+개설자 자동 가입). 새 그룹 id 반환(실패 시 nil).
    @discardableResult
    static func createGroup(hood: String, name: String, ageRange: String,
                            interestTags: [String], creatorName: String) async -> String? {
        guard SupabaseConfig.isConfigured, !hood.isEmpty, hood != "우리 동네",
              var req = await request("/rest/v1/crew_group", method: "POST") else { return nil }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hood": hood, "name": cap(name, Cap.title), "age_range": cap(ageRange, Cap.tag),
            "interest_tags": interestTags.prefix(8).map { cap($0, Cap.tag) }, "creator": await SupabaseConfig.ownerID(),
            "creator_name": cap(creatorName, Cap.name),
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let rows = try? JSONDecoder().decode([CrewGroupDTO].self, from: data),
              let id = rows.first?.id else { return nil }
        await setGroupMembership(groupId: id, join: true)
        return id
    }

    /// 그룹 가입/탈퇴(crew_group_member). 성공 true.
    @discardableResult
    static func setGroupMembership(groupId: String, join: Bool) async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        if join {
            guard var req = await request("/rest/v1/crew_group_member?on_conflict=group_id,device_id", method: "POST") else { return false }
            req.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "group_id": groupId, "device_id": await SupabaseConfig.ownerID(),
            ])
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            return true
        } else {
            let dev = await SupabaseConfig.ownerID()
            guard let d = dev.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  let g = groupId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  var req = await request("/rest/v1/crew_group_member?group_id=eq.\(g)&device_id=eq.\(d)", method: "DELETE") else { return false }
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            return true
        }
    }

    // MARK: - 모임 채팅(참가자 공유)

    private struct CrewMessageDTO: Decodable {
        let id: String
        let device_id: String?
        let body: String?
        let created_at: String?
    }

    /// 모임 채팅 메시지 시간순 조회. 미구성/실패 시 nil(→ 로컬 폴백).
    static func fetchMessages(meetupId: String) async -> [ChatMessage]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let m = meetupId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,device_id,body,created_at"
        guard let url = URL(string: "\(base)/rest/v1/crew_meetup_message?meetup_id=eq.\(m)&select=\(select)&order=created_at.asc&limit=300") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[CrewBackend] fetchMessages HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([CrewMessageDTO].self, from: data) else { return nil }
        let me = await SupabaseConfig.ownerID()
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        return dtos.map { d in
            ChatMessage(
                id: d.id,
                text: d.body ?? "",
                mine: d.device_id == me,
                date: d.created_at.flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) } ?? Date()
            )
        }
    }

    /// 모임 채팅 전송. 성공 true.
    @discardableResult
    static func sendMessage(meetupId: String, body: String, authorName: String) async -> Bool {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SupabaseConfig.isConfigured, !t.isEmpty,
              var req = await request("/rest/v1/crew_meetup_message", method: "POST") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "meetup_id": meetupId, "device_id": await SupabaseConfig.ownerID(),
            "author_name": cap(authorName, Cap.name), "body": cap(t, Cap.body),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - 게시판 좋아요·댓글(동네 공유)

    private struct CrewReplyDTO: Decodable { let id: String; let body: String? }

    /// 게시글 댓글 시간순 조회(본문 문자열). 미구성/실패 시 nil.
    static func fetchReplies(postId: String) async -> [String]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let p = postId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        guard let url = URL(string: "\(base)/rest/v1/crew_post_reply?post_id=eq.\(p)&select=id,body&order=created_at.asc&limit=300") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[CrewBackend] fetchReplies HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([CrewReplyDTO].self, from: data) else { return nil }
        return dtos.compactMap { $0.body }
    }

    /// 게시글 댓글 작성. 성공 true.
    @discardableResult
    static func addReply(postId: String, body: String, authorName: String) async -> Bool {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SupabaseConfig.isConfigured, !t.isEmpty,
              var req = await request("/rest/v1/crew_post_reply", method: "POST") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "post_id": postId, "author": await SupabaseConfig.ownerID(),
            "author_name": cap(authorName, Cap.name), "body": cap(t, Cap.body),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 게시글 좋아요 토글(crew_post_like upsert/삭제). 성공 true.
    @discardableResult
    static func setPostLike(postId: String, like: Bool) async -> Bool {
        guard SupabaseConfig.isConfigured else { return false }
        if like {
            guard var req = await request("/rest/v1/crew_post_like?on_conflict=post_id,device_id", method: "POST") else { return false }
            req.setValue("return=minimal,resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "post_id": postId, "device_id": await SupabaseConfig.ownerID(),
            ])
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            return true
        } else {
            let dev = await SupabaseConfig.ownerID()
            guard let d = dev.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  let p = postId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
                  var req = await request("/rest/v1/crew_post_like?post_id=eq.\(p)&device_id=eq.\(d)", method: "DELETE") else { return false }
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            return true
        }
    }

    /// 모임 참가 취소(crew_meetup_join 삭제). 성공 true.
    @discardableResult
    static func leaveMeetup(meetupId: String) async -> Bool {
        let dev = await SupabaseConfig.ownerID()
        guard SupabaseConfig.isConfigured,
              let d = dev.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let m = meetupId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              var req = await request("/rest/v1/crew_meetup_join?meetup_id=eq.\(m)&device_id=eq.\(d)", method: "DELETE") else { return false }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    private static func relativeTime(_ iso: String?) -> String {
        guard let iso else { return "방금" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "방금" }
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "방금" }
        if s < 3600 { return "\(s / 60)분 전" }
        if s < 86400 { return "\(s / 3600)시간 전" }
        return "\(s / 86400)일 전"
    }
}
