// FamilyFeedBackend.swift
// BabyLog — Pro 가족 피드 백엔드 (Supabase bl_* PostgREST + media-upload-url Edge + R2 직접 PUT).
// 사진 바이트는 우리 서버/Supabase를 거치지 않고 R2로 직결(트래픽 비용 0).
// 로그인(AuthStore) 필요 + 서버가 is_pro 검증(미디어 업로드). 무료는 노출 안 함(AppFeatures.proFamilyFeed).

import Foundation
import UIKit

enum FamilyFeedBackend {

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
            ])
            _ = try? await URLSession.shared.data(for: mreq)
        }
        return BLFamily(id: famId, ownerUid: uid, name: String(name.prefix(40)))
    }

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

    /// 기록→가족 자동 공유: 가족이 없으면 만들고, 한 기록의 사진들을 한 포스트로 올린다.
    /// (기록 탭에서 사진을 저장하면 Pro 사용자는 이 경로로 가족 피드에 자동 게시)
    /// ⚠️ DEV ONLY — 로컬 Pro 검증용으로 서버 bl_profile.is_pro=true를 설정한다.
    /// (미디어 업로드 Edge가 서버 is_pro를 검사하므로, 개발 토글만으론 업로드가 403난다.)
    /// 출시 시 제거 — 실제 is_pro는 StoreKit 영수증 검증(verify-subscription)이 service_role로 설정.
    /// 서버에 `bl_dev_set_pro(boolean)` SECURITY DEFINER 함수가 있어야 동작(없으면 무시).
    static func ensureProForDev() async {
        guard await AuthStore.shared.userId != nil,
              var req = await rest("/rpc/bl_dev_set_pro", method: "POST") else { return }
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["p_on": true])
        guard let (d, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "is_pro 설정: 네트워크 오류"; return }
        if !(200...299).contains(http.statusCode) {
            lastError = "is_pro 설정 실패 HTTP \(http.statusCode): \(String(data: d, encoding: .utf8)?.prefix(100) ?? "") — SQL(bl_dev_set_pro) 실행했나요?"
        }
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
            ])
            _ = try? await URLSession.shared.data(for: mreq)
        }
    }

    @discardableResult
    static func shareRecordToFamily(postId: String?, images: [UIImage], caption: String?, childLabel: String?) async -> Bool {
        lastError = nil
        guard !images.isEmpty else { lastError = "사진이 없어요"; return false }
        guard let uid = await AuthStore.shared.userId else { lastError = "로그인이 필요해요"; return false }
        await ensureProForDev()   // DEV: 서버 is_pro 동기화(출시 시 제거)
        var fam = await myFamily()
        if fam == nil { fam = await createFamily(name: "우리 가족") }
        guard let f = fam else { lastError = lastError ?? "가족 보관함 생성 실패"; return false }
        await ensureMembership(familyId: f.id, uid: uid)   // Edge not_member 403 방지
        return await createPhotoPost(familyId: f.id, postId: postId, images: images, caption: caption, childLabel: childLabel)
    }

    /// 사진 포스트 작성: (사진들) 압축 → R2 업로드(Edge presigned) → bl_feed_post 1개 + bl_post_media N개.
    /// 한 기록(한 순간)이 사진 여러 장이어도 피드에선 한 포스트(여러 미디어).
    /// postId를 주면 그 id로 포스트 생성(기록 entry.id와 동일 → 타임라인이 가족 반응을 매칭).
    @discardableResult
    static func createPhotoPost(familyId: String, postId: String? = nil, images: [UIImage],
                                caption: String?, childLabel: String?) async -> Bool {
        guard let uid = await AuthStore.shared.userId, !images.isEmpty else { return false }
        // 1) 모든 사진 압축(긴변 1280, jpeg 0.7) → R2 업로드. 실패분은 건너뜀.
        //    포스트보다 먼저 업로드해 R2 실패(비Pro/네트워크) 시 고아 포스트가 안 생기게 한다.
        var keys: [String] = []
        for image in images.prefix(5) {
            guard let data = compressedJPEG(image, maxDimension: 1280, quality: 0.7),
                  let key = await uploadToR2(familyId: familyId, data: data,
                                             ext: "jpg", contentType: "image/jpeg") else { continue }
            keys.append(key)
        }
        guard !keys.isEmpty else { lastError = lastError ?? "사진 업로드 실패"; return false }
        // 2) 포스트 행 생성 — id를 클라에서 생성(return=representation 금지: 되읽기 RLS 42501 회피)
        let postId = postId ?? UUID().uuidString
        guard var preq = await rest("/bl_feed_post", method: "POST") else { lastError = "서버 미구성"; return false }
        preq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var postBody: [String: Any] = ["id": postId, "family_id": familyId, "author_uid": uid]
        if let c = caption, !c.isEmpty { postBody["caption"] = String(c.prefix(2000)) }
        if let cl = childLabel, !cl.isEmpty { postBody["child_label"] = String(cl.prefix(40)) }
        preq.httpBody = try? JSONSerialization.data(withJSONObject: postBody)
        guard let (pdata, presp) = try? await URLSession.shared.data(for: preq),
              let phttp = presp as? HTTPURLResponse else { lastError = "포스트 생성: 네트워크 오류"; return false }
        // 409 = 같은 id 포스트가 이미 존재 = 이미 공유된 기록 → 성공으로 간주(미디어 재삽입 생략).
        if phttp.statusCode == 409 { return true }
        guard (200...299).contains(phttp.statusCode) else {
            lastError = "포스트 생성 실패 HTTP \(phttp.statusCode): \(String(data: pdata, encoding: .utf8)?.prefix(120) ?? "")"
            return false
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
        return anyMedia
    }

    // MARK: - 하트 / 댓글

    @discardableResult
    static func setHeart(post: BLFeedPost, on: Bool) async -> Bool {
        guard let uid = await AuthStore.shared.userId else { return false }
        if on {
            guard var req = await rest("/bl_reaction?on_conflict=post_id,uid,kind", method: "POST") else { return false }
            req.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "post_id": post.id, "family_id": post.familyId, "uid": uid, "kind": "heart",
            ])
            guard let (_, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
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

    private static func uploadToR2(familyId: String, data: Data, ext: String, contentType: String) async -> String? {
        guard let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/functions/v1/media-upload-url") else { lastError = "서버 미구성"; return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "familyId": familyId, "kind": "photo", "ext": ext, "contentType": contentType,
        ])
        guard let (rdata, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { lastError = "업로드 URL: 네트워크 오류"; return nil }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: rdata, encoding: .utf8) ?? ""
            lastError = "업로드 권한 거부 HTTP \(http.statusCode): \(body.prefix(140))"
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
