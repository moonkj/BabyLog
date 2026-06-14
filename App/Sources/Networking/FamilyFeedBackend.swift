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
        guard let req = await rest("/bl_family?select=*&limit=1", method: "GET") else { return nil }
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

    /// 타임라인 매칭용 — 내 가족 피드 전체를 post.id로 색인해 반환(기록 entry.id로 조회).
    static func fetchFamilySocial() async -> [String: BLFeedPost] {
        guard let f = await myFamily() else { return [:] }
        var map: [String: BLFeedPost] = [:]
        for p in await fetchFeed(familyId: f.id) { map[p.id] = p }
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
    @discardableResult
    static func shareRecordToFamily(postId: String?, images: [UIImage], caption: String?, childLabel: String?) async -> Bool {
        guard !images.isEmpty else { return false }
        var fam = await myFamily()
        if fam == nil { fam = await createFamily(name: "우리 가족") }
        guard let f = fam else { return false }
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
        guard !keys.isEmpty else { return false }
        // 2) 포스트 행 생성 — id를 클라에서 생성(return=representation 금지: 되읽기 RLS 42501 회피)
        let postId = postId ?? UUID().uuidString
        guard var preq = await rest("/bl_feed_post", method: "POST") else { return false }
        preq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        var postBody: [String: Any] = ["id": postId, "family_id": familyId, "author_uid": uid]
        if let c = caption, !c.isEmpty { postBody["caption"] = String(c.prefix(2000)) }
        if let cl = childLabel, !cl.isEmpty { postBody["child_label"] = String(cl.prefix(40)) }
        preq.httpBody = try? JSONSerialization.data(withJSONObject: postBody)
        guard let (_, presp) = try? await URLSession.shared.data(for: preq),
              let phttp = presp as? HTTPURLResponse, (200...299).contains(phttp.statusCode) else { return false }
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
              let url = URL(string: "\(base)/functions/v1/media-upload-url") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "familyId": familyId, "kind": "photo", "ext": ext, "contentType": contentType,
        ])
        guard let (rdata, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let obj = try? JSONSerialization.jsonObject(with: rdata) as? [String: Any],
              let uploadUrl = obj["uploadUrl"] as? String, let objKey = obj["key"] as? String,
              let put = URL(string: uploadUrl) else { return nil }
        // R2로 직접 PUT
        var preq = URLRequest(url: put); preq.httpMethod = "PUT"; preq.timeoutInterval = 60
        preq.setValue(contentType, forHTTPHeaderField: "Content-Type")
        guard let (_, presp) = try? await URLSession.shared.upload(for: preq, from: data),
              let phttp = presp as? HTTPURLResponse, (200...299).contains(phttp.statusCode) else { return nil }
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
