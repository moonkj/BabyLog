// FamilyFeedBackend.swift
// BabyLog — Pro 가족 피드 백엔드 (Supabase bl_* PostgREST + media-upload-url Edge + R2 직접 PUT).
// 사진 바이트는 우리 서버/Supabase를 거치지 않고 R2로 직결(트래픽 비용 0).
// 로그인(AuthStore) 필요 + 서버가 is_pro 검증(미디어 업로드). 무료는 노출 안 함(AppFeatures.proFamilyFeed).

import Foundation
import UIKit
import AVFoundation

enum FamilyFeedBackend {

    /// 가족당 영상 개수 상한 기본값(무료). 실제 캡은 등급별(무료 100 / Pro 300) — `familyVideoCap`.
    /// 저장 비용 통제용(시청은 R2라 무료). 서버(media-upload-url)에서도 동일 로직으로 강제.
    static let videoCap = 100

    /// 마지막 실패 상세(진단용 — UI 알럿에 노출). 성공 시 nil.
    nonisolated(unsafe) static var lastError: String?

    private static func authBearer() async -> String {
        if let t = await AuthStore.shared.validAccessToken() { return t }
        return SupabaseConfig.anonKey ?? ""
    }

    private static func rest(_ path: String, method: String) async -> URLRequest? {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/rest/v1\(path)") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = method; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // 이 프로젝트는 RLS에서 auth.uid()가 null로 떨어져, 소유자 식별을 x-device-id 헤더로도
        // 받는다(coalesce(auth.uid, header) 패턴 — 크루/마켓과 동일). 로그인 시 ownerID()=uid.
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        return req
    }

    private static func decode<T: Decodable>(_ data: Data, _ type: T.Type) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
    }

    /// JWT payload(가운데 세그먼트) 디코딩 — 진단용(sub/role 확인).
    private static func decodeJWT(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return [:] }
        var s = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        guard let d = Data(base64Encoded: s),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return obj
    }

    // MARK: - 가족

    /// 내가 속한 가족(RLS가 멤버인 것만 반환). 첫 가족 반환.
    static func myFamily() async -> BLFamily? {
        // created_at 오름차순 → 가장 오래된(정규) 가족을 일관되게 선택(고아 가족 여러 개여도 안정).
        guard let req = await rest("/bl_family?select=*&order=created_at.asc&limit=1", method: "GET") else { return nil }
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let arr = decode(data, [BLFamily].self) else { return nil }
        return arr.first
    }

    /// 가족 생성 + 본인을 parent 멤버로 추가. 생성된 가족 반환.
    /// ⚠️ return=representation 금지 — INSERT와 같은 문장에서 행을 되읽으면(SELECT RLS=bl_is_family_member)
    ///    방금 삽입한 행이 스냅샷에 없어 멤버십이 false → 42501. 대신 id를 클라에서 생성해 되읽기 자체를 없앤다.
    static func createFamily(name: String) async -> BLFamily? {
        lastError = nil
        guard let uid = await AuthStore.shared.userId else { lastError = "로그인 안 됨(uid 없음)"; return nil }
        let famId = UUID().uuidString
        guard var req = await rest("/bl_family", method: "POST") else { lastError = "서버 미구성"; return nil }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "id": famId, "owner_uid": uid, "name": String(name.prefix(40)),
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "네트워크 오류"; return nil }
        guard (200...299).contains(http.statusCode) else {
            lastError = "HTTP \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")"
            return nil
        }
        // 본인 멤버 등록(parent) — 별도 문장이라 위 가족 행이 보임(RLS 통과).
        let nickname = UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님"
        if var mreq = await rest("/bl_family_member", method: "POST") {
            mreq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            mreq.httpBody = try? JSONSerialization.data(withJSONObject: [
                "family_id": famId, "uid": uid, "role": "parent",
                "display_name": String(nickname.prefix(40)),
                "joined_at": ISO8601DateFormatter().string(from: Date()),
                "approved": true,   // 주인은 자동 승인(승인 인원 카운트에 포함)
            ])
            _ = try? await URLSession.shared.data(for: mreq)
        }
        return BLFamily(id: famId, ownerUid: uid, name: String(name.prefix(40)))
    }

    // MARK: - 초대 (조부모 — 안드로이드/웹 합류)

    /// 가족 초대 코드 생성 — 소유자가 미사용 멤버 행(uid=null, invite_code=코드)을 만든다.
    /// 조부모는 웹(…/family/?invite=코드)에서 로그인 후 bl_claim_invite(코드)로 이 가족에 합류한다.
    /// 같은 링크를 여러 명이 써도 됨(웹의 claim RPC가 둘째부터 새 멤버 행 추가). 반환: 초대 코드.
    static func createInvite(familyId: String) async -> String? {
        lastError = nil
        let code = inviteCode()
        guard var req = await rest("/bl_family_member", method: "POST") else { lastError = "서버 미구성"; return nil }
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        // uid 생략 → null(미사용 초대 행). RLS: 소유자만 INSERT 가능.
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "family_id": familyId, "invite_code": code, "role": "grandparent", "display_name": "가족",
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "네트워크 오류"; return nil }
        guard (200...299).contains(http.statusCode) else {
            lastError = "초대 생성 실패 HTTP \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(140) ?? "")"
            return nil
        }
        return code
    }

    /// 혼동 문자(0/O/1/I/L) 제외한 8자리 코드.
    private static func inviteCode() -> String {
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in chars.randomElement()! })
    }

    /// 내 가족 표시 이름을 닉네임으로 동기화(설정에서 닉네임 변경 시). 비로그인/빈값이면 무시.
    /// bl_set_my_name이 내(uid) 모든 가족 멤버 행의 display_name을 갱신 → 가족 보관함 이름이 닉네임과 일치.
    static func updateMyDisplayName(_ name: String) async {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, await AuthStore.shared.userId != nil,
              var req = await rest("/rpc/bl_set_my_name", method: "POST") else { return }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_name": String(t.prefix(40))])
        _ = try? await URLSession.shared.data(for: req)
    }

    /// 가족 비밀번호 설정/변경(소유자) — 숫자 4~10자리. 링크와 함께 2차 확인.
    @discardableResult
    static func setFamilyPass(familyId: String, pass: String) async -> Bool {
        guard var req = await rest("/rpc/bl_set_family_pass", method: "POST") else { return false }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_family": familyId, "p_pass": pass])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - 참여 (부모 — 앱에서 초대코드+비번으로 합류)

    /// 초대코드+비밀번호로 가족 합류 — 서버 RPC bl_claim_invite가 등급/비번/인원을 검증하고
    /// 합류한 family_id(uuid)를 반환한다. 성공 시 family_id 문자열, 실패 시 lastError 설정 후 nil.
    static func joinFamily(code: String, name: String, pass: String) async -> String? {
        lastError = nil
        guard var req = await rest("/rpc/bl_claim_invite", method: "POST") else { lastError = "서버 미구성"; return nil }
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "p_code": code, "p_name": String(name.prefix(40)), "p_pass": pass,
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "네트워크 오류"; return nil }
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200...299).contains(http.statusCode) else {
            // 서버 에러 본문(message 등)에 담긴 사유에 맞춰 한국어 안내로 변환.
            if body.contains("needs_pro_web") {
                lastError = "조부모·친척은 Pro 가족만 초대할 수 있어요."
            } else if body.contains("needs_pro_cap") {
                lastError = "무료는 2명까지예요. Pro로 더 초대할 수 있어요."
            } else if body.contains("family_full") {
                lastError = "가족 인원이 가득 찼어요 (최대 8명)."
            } else if body.contains("wrong_password") {
                lastError = "비밀번호가 맞지 않아요."
            } else if body.contains("invalid invite") {
                lastError = "초대 코드가 올바르지 않아요."
            } else {
                lastError = "참여 실패 HTTP \(http.statusCode)"
            }
            return nil
        }
        // 성공 본문은 uuid가 따옴표로 둘러싸여 옴(예: "...uuid..."). 따옴표·공백 제거.
        let fid = body.trimmingCharacters(in: CharacterSet(charactersIn: "\"\n\r \t"))
        guard !fid.isEmpty else { lastError = "참여 응답이 비어 있어요."; return nil }
        await notifyJoin(familyId: fid, name: name)   // 주인에게 '승인 대기' 푸시
        return fid
    }

    /// 가족 주인에게 '합류 요청' 푸시(승인 대기 알림) — notify-family-join Edge.
    static func notifyJoin(familyId: String, name: String) async {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/notify-family-join") else { return }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["familyId": familyId, "name": String(name.prefix(40))])
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - 가족 관리 (주인 — 멤버 조회/삭제)

    /// 가족 멤버 목록(가입순) — 승인된 멤버만. 실패/디코드 실패 시 [].
    static func fetchMembers(familyId: String) async -> [BLFamilyMember] {
        // uid가 있는 '실제 합류한' 멤버만 — uid=null(미사용 초대 코드)은 제외(이름 '가족'으로 떠 혼란).
        // approved=true: 합류 승인된 멤버만(대기 중은 fetchPendingMembers로 따로 본다).
        let path = "/bl_family_member?family_id=eq.\(familyId)&uid=not.is.null&approved=eq.true&select=*&order=joined_at.asc"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let members = decode(data, [BLFamilyMember].self) else { return [] }
        return members
    }

    /// 승인 대기 중인 멤버(approved=false) — 주인의 승인/거절 대상. 실패 시 [].
    static func fetchPendingMembers(familyId: String) async -> [BLFamilyMember] {
        let path = "/bl_family_member?family_id=eq.\(familyId)&approved=eq.false&uid=not.is.null&select=*&order=joined_at.asc"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let members = decode(data, [BLFamilyMember].self) else { return [] }
        return members
    }

    /// 멤버 승인(주인) — 서버 RPC가 등급별 인원 상한(무료2/Pro8)을 검증. 2xx면 true.
    /// 상한 초과(family_full) 또는 그 외 실패 시 lastError 설정 후 false.
    @discardableResult
    static func approveMember(memberId: String) async -> Bool {
        lastError = nil
        guard var req = await rest("/rpc/bl_approve_member", method: "POST") else { lastError = "서버 미구성"; return false }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_member": memberId])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "승인 실패"; return false }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.contains("needs_pro") {
                lastError = "무료는 부부 2명까지예요. Pro로 업그레이드하면 조부모·친척도 초대할 수 있어요."
            } else if body.contains("family_full") {
                lastError = "가족 인원이 가득 찼어요 (최대 8명)."
            } else {
                lastError = "승인 실패"
            }
            return false
        }
        return true
    }

    /// 무료 '배우자' 명시 지정(주인) — 구독 만료 시 유지될 1명. 승인된 멤버만.
    static func setPartner(memberId: String) async -> Bool {
        lastError = nil
        guard var req = await rest("/rpc/bl_set_partner", method: "POST") else { lastError = "서버 미구성"; return false }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_member": memberId])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            lastError = "배우자 지정 실패"; return false
        }
        return true
    }

    /// 지금 이 가족 피드를 볼 수 있는지(구독 게이팅 반영) — 승인됐어도 만료로 차단될 수 있음.
    /// 차단(false)이면 빈 피드 대신 '구독해야 볼 수 있어요' 안내를 띄운다.
    static func canViewFeed(familyId: String) async -> Bool {
        guard var req = await rest("/rpc/bl_is_family_member", method: "POST") else { return false }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_family": familyId])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return (String(data: data, encoding: .utf8) ?? "").contains("true")
    }

    /// 내 멤버 행 조회(내 승인 상태 확인용) — 대기 멤버도 본인 행은 RLS로 항상 보임. 없으면 nil.
    static func myMembership(familyId: String) async -> BLFamilyMember? {
        guard let uid = await AuthStore.shared.userId else { return nil }
        let path = "/bl_family_member?family_id=eq.\(familyId)&uid=eq.\(uid)&select=*&limit=1"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let members = decode(data, [BLFamilyMember].self) else { return nil }
        return members.first
    }

    /// 멤버 내보내기(주인) — return=representation으로 실제 삭제된 행을 확인. 비어있으면 실패(권한·없음).
    @discardableResult
    static func removeMember(memberId: String) async -> Bool {
        guard var req = await rest("/bl_family_member?id=eq.\(memberId)", method: "DELETE") else { return false }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !arr.isEmpty else { return false }
        return true
    }

    // (제거됨) setDevPro — anon이 자기 is_pro를 위조하던 백도어 RPC(bl_dev_set_pro) 제거(출시 보안).
    //   Pro 등급은 StoreKit 영수증 검증(verify-subscription, service_role)만 bl_profile.is_pro를 쓴다.

    // MARK: - 피드

    static func fetchFeed(familyId: String) async -> [BLFeedPost] {
        let sel = "select=*,bl_post_media(*),bl_reaction(uid),bl_comment(*)"
        let path = "/bl_feed_post?family_id=eq.\(familyId)&\(sel)&order=created_at.desc&limit=100"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let posts = decode(data, [BLFeedPost].self) else { return [] }
        return posts
    }

    /// 타임라인 매칭용 — 내가 볼 수 있는 모든 포스트를 post.id로 색인(가족 무관).
    /// RLS가 내 가족(소유/멤버)만 보여주므로, 고아 가족이 여러 개여도 흩어진 포스트를 모두 찾는다.
    static func fetchFamilySocial() async -> [String: BLFeedPost] {
        let sel = "select=*,bl_post_media(*),bl_reaction(uid),bl_comment(*)"
        let path = "/bl_feed_post?\(sel)&order=created_at.desc&limit=200"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let posts = decode(data, [BLFeedPost].self) else { return [:] }
        var map: [String: BLFeedPost] = [:]
        for p in posts { map[p.id] = p }
        return map
    }

    /// 단일 포스트(하트·댓글 포함) 재조회 — 카드에서 반응/댓글 직후 갱신용.
    static func fetchPost(postId: String) async -> BLFeedPost? {
        let sel = "select=*,bl_post_media(*),bl_reaction(uid),bl_comment(*)"
        let path = "/bl_feed_post?id=eq.\(postId)&\(sel)&limit=1"
        guard let req = await rest(path, method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let posts = decode(data, [BLFeedPost].self) else { return nil }
        return posts.first
    }

    /// 소유자 멤버 행 보장 — Edge(media-upload-url)는 bl_family_member 행을 요구하므로(소유자여도
    /// 멤버 행 없으면 not_member 403), 없으면 본인 parent 멤버를 1회 삽입한다(중복 방지 위해 선조회).
    private static func ensureMembership(familyId: String, uid: String) async {
        if let req = await rest("/bl_family_member?family_id=eq.\(familyId)&uid=eq.\(uid)&select=id&limit=1", method: "GET"),
           let (d, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
           let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]], !arr.isEmpty {
            return  // 이미 멤버
        }
        let nickname = UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님"
        if var mreq = await rest("/bl_family_member", method: "POST") {
            mreq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            mreq.httpBody = try? JSONSerialization.data(withJSONObject: [
                "family_id": familyId, "uid": uid, "role": "parent",
                "display_name": String(nickname.prefix(40)),
                "joined_at": ISO8601DateFormatter().string(from: Date()),
                "approved": true,   // 소유자 본인 보장 — 자동 승인
            ])
            _ = try? await URLSession.shared.data(for: mreq)
        }
    }

    @discardableResult
    static func shareRecordToFamily(postId: String?, images: [UIImage], caption: String?, childLabel: String?,
                                    videoURL: URL? = nil) async -> Bool {
        lastError = nil
        guard !images.isEmpty || videoURL != nil else { lastError = "사진·영상이 없어요"; return false }
        guard let uid = await AuthStore.shared.userId else { lastError = "로그인이 필요해요"; return false }
        var fam = await myFamily()
        if fam == nil { fam = await createFamily(name: "우리 가족") }
        guard let f = fam else { lastError = lastError ?? "가족 보관함 생성 실패"; return false }
        await ensureMembership(familyId: f.id, uid: uid)   // Edge not_member 403 방지
        return await createPhotoPost(familyId: f.id, postId: postId, images: images,
                                     caption: caption, childLabel: childLabel, videoURL: videoURL)
    }

    /// 포스트에 미디어 행이 하나라도 있는지 — 409(이미 존재) 시 빈 카드 vs 완료 구분용.
    private static func postHasMedia(_ postId: String) async -> Bool {
        guard let req = await rest("/bl_post_media?post_id=eq.\(postId)&select=id&limit=1", method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return false }
        return !arr.isEmpty
    }

    /// 가족 영상 개수(카운터 표시용). 실패 시 0.
    static func familyVideoCount(familyId: String) async -> Int {
        guard let req = await rest("/bl_post_media?family_id=eq.\(familyId)&kind=eq.video&select=id", method: "GET"),
              let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return 0 }
        return arr.count
    }

    /// 가족 영상 상한(카운터 분모) — 등급별(무료 100 / Pro 300, 주인 is_pro 기준).
    /// RPC `bl_video_cap`(SECURITY DEFINER)로 비주인 멤버도 정확한 캡을 본다. 실패 시 기본 100.
    static func familyVideoCap(familyId: String) async -> Int {
        guard var req = await rest("/rpc/bl_video_cap", method: "POST") else { return videoCap }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_family": familyId])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let n = Int(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        else { return videoCap }
        return n
    }

    /// 사진 포스트 작성: (사진들) 압축 → R2 업로드(Edge presigned) → bl_feed_post 1개 + bl_post_media N개.
    /// 한 기록(한 순간)이 사진 여러 장이어도 피드에선 한 포스트(여러 미디어).
    /// postId를 주면 그 id로 포스트 생성(기록 entry.id와 동일 → 타임라인이 가족 반응을 매칭).
    @discardableResult
    static func createPhotoPost(familyId: String, postId: String? = nil, images: [UIImage],
                                caption: String?, childLabel: String?, videoURL: URL? = nil) async -> Bool {
        guard let uid = await AuthStore.shared.userId, !images.isEmpty || videoURL != nil else { return false }
        let postId = postId ?? UUID().uuidString
        // 1) 포스트 행을 먼저 생성 — 409(이미 공유)·실패를 업로드 *이전*에 감지해 중복 R2 업로드(고아)를
        //    원천 차단(전엔 업로드 후 409라 재공유마다 미디어 한 세트가 R2에 고아로 남았음).
        guard var preq = await rest("/bl_feed_post", method: "POST") else { lastError = "서버 미구성"; return false }
        preq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var postBody: [String: Any] = ["id": postId, "family_id": familyId, "author_uid": uid]
        if let c = caption, !c.isEmpty { postBody["caption"] = String(c.prefix(2000)) }
        if let cl = childLabel, !cl.isEmpty { postBody["child_label"] = String(cl.prefix(40)) }
        preq.httpBody = try? JSONSerialization.data(withJSONObject: postBody)
        guard let (pdata, presp) = try? await URLSession.shared.data(for: preq),
              let phttp = presp as? HTTPURLResponse else { lastError = "포스트 생성: 네트워크 오류"; return false }
        let alreadyExists = phttp.statusCode == 409   // 같은 id 포스트가 이미 존재(이미 공유됨 or 중단된 공유)
        if !alreadyExists {
            guard (200...299).contains(phttp.statusCode) else {
                lastError = "포스트 생성 실패 HTTP \(phttp.statusCode): \(String(data: pdata, encoding: .utf8)?.prefix(120) ?? "")"
                return false
            }
        }
        // 이미 미디어가 있으면 완료(중복 업로드 0). 미디어 0이면(앱이 공유 도중 죽은 빈 카드) 업로드를 이어서 진행 — 빈 카드 영구화 방지.
        if alreadyExists, await postHasMedia(postId) { return true }
        // 2) 사진 압축(긴변 1280, jpeg 0.7) → R2 업로드. 실패분은 건너뜀.
        var keys: [String] = []
        for image in images.prefix(5) {
            guard let data = compressedJPEG(image, maxDimension: 1280, quality: 0.7),
                  let key = await uploadToR2(familyId: familyId, data: data,
                                             ext: "jpg", contentType: "image/jpeg") else { continue }
            keys.append(key)
        }
        // 2-1) 영상: 720p·60초 압축 → R2 업로드 + 포스터. 개수 상한은 서버(Edge)가 강제(video_cap).
        var videoMedia: (key: String, thumb: String?, durationS: Int, bytes: Int)? = nil
        if let vurl = videoURL, let v = await compressVideo(vurl) {
            if let vdata = try? Data(contentsOf: v.url),
               let vkey = await uploadToR2(familyId: familyId, data: vdata, ext: "mp4", contentType: "video/mp4", kind: "video") {
                var thumbKey: String? = nil
                if let poster = v.poster {
                    thumbKey = await uploadToR2(familyId: familyId, data: poster, ext: "jpg", contentType: "image/jpeg")
                }
                videoMedia = (vkey, thumbKey, v.durationS, vdata.count)
            }
            try? FileManager.default.removeItem(at: v.url)
        }
        // 3) 미디어 행 기록(키만)
        var anyMedia = false
        for key in keys {
            guard var mreq = await rest("/bl_post_media", method: "POST") else { continue }
            mreq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            mreq.httpBody = try? JSONSerialization.data(withJSONObject: [
                "post_id": postId, "family_id": familyId, "kind": "photo", "r2_key": key,
            ])
            if let (_, mresp) = try? await URLSession.shared.data(for: mreq),
               let mhttp = mresp as? HTTPURLResponse, (200...299).contains(mhttp.statusCode) { anyMedia = true }
        }
        // 3-1) 영상 미디어 행(포스터·길이·바이트 포함 — 카운터/쿼터·피드 포스터용)
        if let v = videoMedia, var mreq = await rest("/bl_post_media", method: "POST") {
            mreq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            var body: [String: Any] = ["post_id": postId, "family_id": familyId, "kind": "video",
                                       "r2_key": v.key, "duration_s": v.durationS, "bytes": v.bytes]
            if let t = v.thumb { body["thumb_key"] = t }
            mreq.httpBody = try? JSONSerialization.data(withJSONObject: body)
            if let (_, mresp) = try? await URLSession.shared.data(for: mreq),
               let mhttp = mresp as? HTTPURLResponse, (200...299).contains(mhttp.statusCode) { anyMedia = true }
        }
        // 4) 미디어가 하나도 안 들어갔으면(업로드 전부 실패·영상 캡 등) 빈 포스트 행 삭제 — 빈 카드 방지.
        if !anyMedia {
            await deletePost(postId: postId)
            lastError = lastError ?? "업로드 실패"
            return false
        }
        return anyMedia
    }

    /// 영상 압축(720p·60초 캡) + 포스터 프레임. 반환: (압축 mp4 임시URL, 포스터jpeg, 길이초, 바이트?).
    /// 비용 통제 핵심 — per-file 크기를 720p/60초로 묶는다(시청은 R2라 무료).
    private static func compressVideo(_ src: URL) async -> (url: URL, poster: Data?, durationS: Int)? {
        let asset = AVURLAsset(url: src)
        let durSec = (try? await asset.load(.duration).seconds) ?? 0
        guard durSec > 0 else { return nil }
        let capped = min(durSec, 60.0)
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("fam-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: out)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { return nil }
        export.outputURL = out
        export.outputFileType = .mp4
        export.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: capped, preferredTimescale: 600))
        export.shouldOptimizeForNetworkUse = true
        let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            export.exportAsynchronously { cont.resume(returning: export.status == .completed) }
        }
        guard ok, FileManager.default.fileExists(atPath: out.path) else { return nil }
        // 포스터 프레임(0.5초 지점, 긴변 720)
        var poster: Data? = nil
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 720, height: 720)
        if let cg = try? await gen.image(at: CMTime(seconds: min(0.5, capped / 2), preferredTimescale: 600)).image {
            poster = UIImage(cgImage: cg).jpegData(compressionQuality: 0.7)
        }
        return (out, poster, Int(capped))
    }

    /// 포스트 삭제(DB만) — 기록 삭제 시 가족 피드에서도 제거(미디어·반응·댓글은 FK cascade).
    /// ⚠️ R2 원본 객체는 남는다 → 완전 삭제는 deletePostFully 사용.
    @discardableResult
    static func deletePost(postId: String) async -> Bool {
        guard let req = await rest("/bl_feed_post?id=eq.\(postId)", method: "DELETE"),
              let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 완전 삭제 — R2 원본 객체까지 제거(media-delete Edge, 작성자 본인 검증). Edge 실패 시 DB만이라도 삭제(폴백).
    @discardableResult
    static func deletePostFully(postId: String) async -> Bool {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/media-delete") else {
            return await deletePost(postId: postId)
        }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 20
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["postId": postId])
        if let (_, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            return true
        }
        // Edge 실패 → 최소한 DB에서라도 제거(R2 고아 객체는 추후 정리)
        return await deletePost(postId: postId)
    }

    // MARK: - 하트 / 댓글

    @discardableResult
    static func setHeart(post: BLFeedPost, on: Bool) async -> Bool {
        guard let uid = await AuthStore.shared.userId else { return false }
        if on {
            // 평이한 INSERT(댓글과 동일 경로). on_conflict 업서트가 복합키에서 실패하던 문제 회피.
            guard var req = await rest("/bl_reaction", method: "POST") else { return false }
            req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "post_id": post.id, "family_id": post.familyId, "uid": uid, "kind": "heart",
            ])
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse else { return false }
            if http.statusCode == 409 { return true }   // 이미 누름 = 성공
            if !(200...299).contains(http.statusCode) {
                lastError = "하트 실패 HTTP \(http.statusCode): \(String(data: data, encoding: .utf8)?.prefix(120) ?? "")"
                return false
            }
            return true
        } else {
            let path = "/bl_reaction?post_id=eq.\(post.id)&uid=eq.\(uid)&kind=eq.heart"
            guard let req = await rest(path, method: "DELETE"),
                  let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
            return true
        }
    }

    @discardableResult
    static func addComment(post: BLFeedPost, text: String) async -> Bool {
        guard let uid = await AuthStore.shared.userId else { return false }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, var req = await rest("/bl_comment", method: "POST") else { return false }
        let nickname = UserDefaults.standard.string(forKey: "bl_nickname") ?? "가족"
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "post_id": post.id, "family_id": post.familyId, "uid": uid,
            "author_name": String(nickname.prefix(40)), "text": String(t.prefix(1000)),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - R2 업로드 (Edge presigned → 직접 PUT)

    private static func uploadToR2(familyId: String, data: Data, ext: String, contentType: String,
                                   kind: String = "photo") async -> String? {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/media-upload-url") else { lastError = "서버 미구성"; return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 60
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "familyId": familyId, "kind": kind, "ext": ext, "contentType": contentType,
        ])
        guard let (rdata, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "업로드 URL: 네트워크 오류"; return nil }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: rdata, encoding: .utf8) ?? ""
            if body.contains("video_cap") {
                let cap = (try? JSONSerialization.jsonObject(with: rdata) as? [String: Any])?["cap"] as? Int ?? videoCap
                lastError = "영상은 가족당 \(cap)개까지예요. 오래된 영상을 지우고 올려주세요."
            } else if body.contains("not_approved") {
                lastError = "아직 승인 대기 중이에요. 가족 주인이 승인하면 올릴 수 있어요."
            } else if body.contains("view_blocked") {
                lastError = "지금은 올릴 수 없어요. 가족 구독이 만료됐어요(부부는 계속 가능)."
            } else {
                lastError = "업로드 권한 거부 HTTP \(http.statusCode): \(body.prefix(140))"
            }
            return nil
        }
        guard let obj = try? JSONSerialization.jsonObject(with: rdata) as? [String: Any],
              let uploadUrl = obj["uploadUrl"] as? String, let objKey = obj["key"] as? String,
              let put = URL(string: uploadUrl) else { lastError = "업로드 URL 응답 파싱 실패"; return nil }
        // R2로 직접 PUT
        var preq = URLRequest(url: put); preq.httpMethod = "PUT"; preq.timeoutInterval = 60
        preq.setValue(contentType, forHTTPHeaderField: "Content-Type")
        guard let (_, presp) = try? await URLSession.shared.upload(for: preq, from: data),
              let phttp = presp as? HTTPURLResponse else { lastError = "R2 전송: 네트워크 오류"; return nil }
        guard (200...299).contains(phttp.statusCode) else { lastError = "R2 PUT 실패 HTTP \(phttp.statusCode)"; return nil }
        return objKey
    }

    private static func compressedJPEG(_ image: UIImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let w = image.size.width, h = image.size.height
        let maxSide = max(w, h)
        let img: UIImage
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            let size = CGSize(width: w * scale, height: h * scale)
            img = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        } else { img = image }
        return img.jpegData(compressionQuality: quality)
    }
}
