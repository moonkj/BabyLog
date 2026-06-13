// FamilyFeedBackend.swift
// BabyLog — Pro 가족 피드 백엔드 (Supabase bl_* PostgREST + media-upload-url Edge + R2 직접 PUT).
// 사진 바이트는 우리 서버/Supabase를 거치지 않고 R2로 직결(트래픽 비용 0).
// 로그인(AuthStore) 필요 + 서버가 is_pro 검증(미디어 업로드). 무료는 노출 안 함(AppFeatures.proFamilyFeed).

import Foundation
import UIKit

enum FamilyFeedBackend {

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
        return req
    }

    private static func decode<T: Decodable>(_ data: Data, _ type: T.Type) -> T? {
        try? JSONDecoder().decode(T.self, from: data)
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
    static func createFamily(name: String) async -> BLFamily? {
        guard let uid = await AuthStore.shared.userId else { return nil }
        guard var req = await rest("/bl_family", method: "POST") else { return nil }
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "owner_uid": uid, "name": String(name.prefix(40)),
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let fam = decode(data, [BLFamily].self)?.first else { return nil }
        // 본인 멤버 등록(parent)
        let nickname = UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님"
        if var mreq = await rest("/bl_family_member", method: "POST") {
            mreq.httpBody = try? JSONSerialization.data(withJSONObject: [
                "family_id": fam.id, "uid": uid, "role": "parent",
                "display_name": String(nickname.prefix(40)),
                "joined_at": ISO8601DateFormatter().string(from: Date()),
            ])
            _ = try? await URLSession.shared.data(for: mreq)
        }
        return fam
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

    /// 사진 포스트 작성: 압축 → R2 업로드(Edge presigned) → bl_feed_post + bl_post_media 기록.
    @discardableResult
    static func createPhotoPost(familyId: String, image: UIImage,
                                caption: String?, childLabel: String?) async -> Bool {
        guard let uid = await AuthStore.shared.userId else { return false }
        // 1) 압축(긴변 1280, jpeg 0.7) — 풀화질 백업은 추후 옵션, 피드용은 경량.
        guard let data = compressedJPEG(image, maxDimension: 1280, quality: 0.7) else { return false }
        // 2) R2 업로드 키 발급(Edge) + 직접 PUT
        guard let key = await uploadToR2(familyId: familyId, data: data,
                                         ext: "jpg", contentType: "image/jpeg") else { return false }
        // 3) 포스트 행 생성
        guard var preq = await rest("/bl_feed_post", method: "POST") else { return false }
        preq.setValue("return=representation", forHTTPHeaderField: "Prefer")
        var postBody: [String: Any] = ["family_id": familyId, "author_uid": uid]
        if let c = caption, !c.isEmpty { postBody["caption"] = String(c.prefix(2000)) }
        if let cl = childLabel, !cl.isEmpty { postBody["child_label"] = String(cl.prefix(40)) }
        preq.httpBody = try? JSONSerialization.data(withJSONObject: postBody)
        guard let (pdata, presp) = try? await URLSession.shared.data(for: preq),
              let phttp = presp as? HTTPURLResponse, (200...299).contains(phttp.statusCode),
              let post = decode(pdata, [BLFeedPost].self)?.first else { return false }
        // 4) 미디어 행 기록(키만)
        guard var mreq = await rest("/bl_post_media", method: "POST") else { return false }
        mreq.httpBody = try? JSONSerialization.data(withJSONObject: [
            "post_id": post.id, "family_id": familyId, "kind": "photo", "r2_key": key,
        ])
        guard let (_, mresp) = try? await URLSession.shared.data(for: mreq),
              let mhttp = mresp as? HTTPURLResponse, (200...299).contains(mhttp.statusCode) else { return false }
        return true
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
