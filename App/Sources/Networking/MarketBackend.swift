// MarketBackend.swift
// BabyLog · 마켓(중고거래) 서버 연동 — PostgREST + Storage (SDK 없이 URLSession)
// 무료 정책: 1인 1매물(freeListingLimit) · 30일 자동 만료(서버 expires_at, fetch는 미만료만).
// 사진은 공개 상품 사진(아이 사진 아님) → Storage 'market-photos' 버킷 호스팅.
// ⚠️ 피처 플래그(AppFeatures.market)로 노출 제어. 스키마: supabase/schema_market.sql

import Foundation
import UIKit

enum MarketBackend {
    /// 무료 동시 판매 매물 수 상한.
    static let freeListingLimit = 1

    private static func authBearer() async -> String {
        if let t = await AuthStore.shared.validAccessToken() { return t }
        return SupabaseConfig.anonKey ?? ""
    }

    // MARK: - 조회

    private struct ItemDTO: Decodable {
        let id: String
        let hood: String?      // 판매자 동(표시)
        let city: String?      // 노출 범위 시
        let title: String?
        let category: String?
        let grade: String?
        let months_tag: String?
        let price: Int?
        let is_free: Bool?
        let is_graduate: Bool?
        let has_recall: Bool?
        let description: String?
        let hygiene_checks: [String]?
        let photo_urls: [String]?
        let seller: String?
        let seller_name: String?
        let status: String?
        let created_at: String?
    }

    /// 시(city) 단위 매물(미만료) 최신순 조회. 미구성/실패 시 nil(→ 로컬 폴백).
    /// 마켓은 시 단위로 노출(동은 좁음). 각 매물에는 판매자 동을 함께 표시.
    static func fetchItems(city: String) async -> [MarketItem]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !city.isEmpty, city != "우리 동네",
              let h = city.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let cols = "id,hood,city,title,category,grade,months_tag,price,is_free,is_graduate,has_recall,description,hygiene_checks,photo_urls,seller,seller_name,status,created_at"
        guard let url = URL(string: "\(base)/rest/v1/market_item?city=eq.\(h)&expires_at=gt.now()&select=\(cols)&order=created_at.desc&limit=100") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[MarketBackend] fetchItems HTTP \(http.statusCode)")  // RLS 회귀 가시화
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([ItemDTO].self, from: data) else { return nil }
        let me = await SupabaseConfig.ownerID()
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        return dtos.map { d in
            MarketItem(
                id: d.id,
                title: d.title ?? "",
                category: MarketCategory(rawValue: d.category ?? "") ?? .etc,
                grade: MarketItemGrade(rawValue: d.grade ?? "") ?? .a,
                monthsTag: d.months_tag ?? "전 월령",
                price: d.price ?? 0,
                originalPrice: nil,
                isFree: d.is_free ?? ((d.price ?? 0) == 0),
                hasRecall: d.has_recall ?? false,
                isGraduate: d.is_graduate ?? false,
                sellerName: d.seller_name ?? "이웃",
                sellerTier: .new,   // 서버 매물: 실제 판매자 티어 미산정 → '신규'로 정직 표기
                distanceText: d.hood ?? "내 동네",   // 판매자 동 표시(시 단위 노출 안에서)
                favoriteCount: 0,
                photoSeed: 0,
                description: d.description ?? "",
                photoRefs: [],
                photoURLs: d.photo_urls ?? [],
                mine: d.seller == me,
                status: MarketStatus(rawValue: d.status ?? "") ?? .selling,
                createdAt: d.created_at.flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) } ?? Date()
            )
        }
    }

    /// 내 활성(판매중·예약중·미만료) 매물 수 — 무료 1매물 게이트용.
    /// 미구성/네트워크 실패/응답 해석 불가 시 nil(불명) — 0으로 단정하면 비행기모드로 한도를 우회할 수 있다.
    static func myActiveListingCount() async -> Int? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let s = (await SupabaseConfig.ownerID()).addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "\(base)/rest/v1/market_item?seller=eq.\(s)&status=in.(%ED%8C%90%EB%A7%A4%EC%A4%91,%EC%98%88%EC%95%BD%EC%A4%91)&expires_at=gt.now()&select=id") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("count=exact", forHTTPHeaderField: "Prefer")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        // Content-Range: 0-4/5 → 총 개수. 없으면 배열 길이로 대체.
        if let range = http.value(forHTTPHeaderField: "Content-Range"),
           let total = range.split(separator: "/").last, let n = Int(total) { return n }
        if let rows = try? JSONDecoder().decode([ItemDTO].self, from: data) { return rows.count }
        return nil   // 2xx여도 본문 해석 불가 = 불명
    }

    /// 내가 올린 매물 전체(상태·만료 무관) 최신순 — 프로필 표시용.
    static func fetchMyItems() async -> [MarketItem]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let s = (await SupabaseConfig.ownerID()).addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let cols = "id,hood,city,title,category,grade,months_tag,price,is_free,is_graduate,has_recall,description,hygiene_checks,photo_urls,seller,seller_name,status,created_at"
        guard let url = URL(string: "\(base)/rest/v1/market_item?seller=eq.\(s)&select=\(cols)&order=created_at.desc&limit=50") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let dtos = try? JSONDecoder().decode([ItemDTO].self, from: data) else { return nil }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        return dtos.map { d in
            MarketItem(
                id: d.id, title: d.title ?? "",
                category: MarketCategory(rawValue: d.category ?? "") ?? .etc,
                grade: MarketItemGrade(rawValue: d.grade ?? "") ?? .a,
                monthsTag: d.months_tag ?? "전 월령", price: d.price ?? 0, originalPrice: nil,
                isFree: d.is_free ?? ((d.price ?? 0) == 0), hasRecall: d.has_recall ?? false,
                isGraduate: d.is_graduate ?? false, sellerName: d.seller_name ?? "이웃",
                sellerTier: .new, distanceText: d.hood ?? "내 동네", favoriteCount: 0, photoSeed: 0,
                description: d.description ?? "", photoRefs: [], photoURLs: d.photo_urls ?? [],
                mine: true, status: MarketStatus(rawValue: d.status ?? "") ?? .selling,
                createdAt: d.created_at.flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) } ?? Date()
            )
        }
    }

    /// 무료 한도 초과 여부(등록 전 확인).
    /// 카운트 확인 불가(nil)면 true — fail-closed: 등록 자체가 네트워크를 요구하므로
    /// 보류해도 UX 손해가 없고, 오프라인으로 무료 한도를 우회하는 구멍을 막는다.
    static func freeLimitReached() async -> Bool {
        guard let count = await myActiveListingCount() else { return true }
        return count >= freeListingLimit
    }

    // MARK: - 등록 / 상태 / 삭제

    /// 매물 등록. 사진(UIImage)은 Storage 업로드 후 URL 저장. 새 id 반환(실패 nil).
    static func createItem(dong: String, city: String, item: MarketItem, photos: [UIImage]) async -> String? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !dong.isEmpty, dong != "우리 동네", !city.isEmpty,
              let url = URL(string: "\(base)/rest/v1/market_item") else { return nil }
        // 사진 업로드(최대 5장)
        var urls: [String] = []
        for img in photos.prefix(5) {
            if let u = await uploadPhoto(img) { urls.append(u) }
        }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "hood": dong,    // 판매자 동(표시)
            "city": city,    // 노출 범위 시
            "title": String(item.title.prefix(120)),
            "category": item.category.rawValue,
            "grade": item.grade.rawValue,
            "months_tag": item.monthsTag,
            "price": item.price,
            "is_free": item.isFree,
            "is_graduate": item.isGraduate,
            "has_recall": item.hasRecall,
            "description": String(item.description.prefix(2000)),
            "hygiene_checks": item.hygieneChecks,
            "photo_urls": urls,
            "seller": await SupabaseConfig.ownerID(),
            "seller_name": String(item.sellerName.prefix(40)),
            "status": item.status.rawValue,
        ])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let rows = try? JSONDecoder().decode([ItemDTO].self, from: data),
              let newId = rows.first?.id else {
            for u in urls { await deletePhoto(u) }   // 행 저장 실패 시 업로드된 사진 고아 객체 정리
            return nil
        }
        return newId
    }

    /// 판매 상태 변경(판매중/예약중/판매완료).
    @discardableResult
    static func setStatus(id: String, status: MarketStatus) async -> Bool {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let i = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "\(base)/rest/v1/market_item?id=eq.\(i)") else { return false }
        var req = URLRequest(url: url); req.httpMethod = "PATCH"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 익명 소유자 RLS 매칭
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")  // RLS 0행 매칭(가짜 성공) 감지용
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["status": status.rawValue])
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        // PostgREST는 0행 매칭(RLS 불일치)도 2xx → 실제 변경된 행이 있어야 성공
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any], !rows.isEmpty else { return false }
        return true
    }

    /// 매물 삭제(+사진 객체 정리).
    @discardableResult
    static func deleteItem(id: String, photoURLs: [String]) async -> Bool {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let i = id.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "\(base)/rest/v1/market_item?id=eq.\(i)") else { return false }
        var req = URLRequest(url: url); req.httpMethod = "DELETE"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 익명 소유자 RLS 매칭
        req.setValue("return=representation", forHTTPHeaderField: "Prefer")  // RLS 0행 매칭(가짜 성공) 감지용
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        // PostgREST는 0행 삭제도 2xx → 실제 삭제된 행이 있을 때만 사진 정리(살아있는 매물 사진 삭제 방지)
        guard let rows = (try? JSONSerialization.jsonObject(with: data)) as? [Any], !rows.isEmpty else { return false }
        for u in photoURLs { await deletePhoto(u) }   // best-effort
        return true
    }

    // MARK: - 거래 신고(증거 서버 보존)

    /// 신고를 서버에 업로드(증거 보존). 운영자만 열람(RLS). 성공 true.
    static func uploadReport(_ report: TradeReport) async -> Bool {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let url = URL(string: "\(base)/rest/v1/market_report") else { return false }
        let iso = ISO8601DateFormatter()
        let transcript: [[String: Any]] = report.transcript.map {
            ["text": $0.text, "mine": $0.mine, "date": iso.string(from: $0.date)]
        }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 15
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "item_id": report.itemId,
            "item_title": String(report.itemTitle.prefix(120)),
            "reporter": await SupabaseConfig.ownerID(),
            "counterpart": String(report.counterpartName.prefix(40)),
            "reason": String(report.reason.prefix(120)),
            "note": String(report.note.prefix(2000)),
            "transcript": transcript,
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    // MARK: - Storage 사진

    /// UIImage 압축·리사이즈 후 Storage 업로드. 공개 URL 반환.
    static func uploadPhoto(_ image: UIImage) async -> String? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let data = compress(image) else { return nil }
        // 경로 첫 폴더 = ownerID — Storage RLS(소유 폴더만 업/삭제)와 정합. 헤더도 동일하게 보냄.
        let owner = await SupabaseConfig.ownerID()
        let path = "\(owner)/\(UUID().uuidString).jpg"
        guard let enc = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(base)/storage/v1/object/market-photos/\(enc)") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 30
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(owner, forHTTPHeaderField: "x-device-id")  // 익명 소유 폴더 RLS 매칭
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return "\(base)/storage/v1/object/public/market-photos/\(enc)"
    }

    private static func deletePhoto(_ publicURL: String) async {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let marker = publicURL.range(of: "/market-photos/") else { return }
        let path = String(publicURL[marker.upperBound...])
        guard let url = URL(string: "\(base)/storage/v1/object/market-photos/\(path)") else { return }
        var req = URLRequest(url: url); req.httpMethod = "DELETE"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 소유 폴더 RLS 매칭
        _ = try? await URLSession.shared.data(for: req)
    }

    /// 상품 사진 압축(긴 변 maxDim, JPEG quality). 대역폭 비용 최소화.
    private static func compress(_ image: UIImage, maxDim: CGFloat = 1280, quality: CGFloat = 0.5) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.jpegData(compressionQuality: quality) }
        let scale = min(1, maxDim / max(size.width, size.height))
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }

    // MARK: - 1:1 거래 채팅 (스레드 = item_id + buyer, 참가자 전용)

    private struct ChatMessageDTO: Decodable {
        let id: String
        let buyer: String?
        let device_id: String?
        let author_name: String?
        let body: String?
        let created_at: String?
    }

    /// 내 식별자(스레드 buyer 기본값) — 로그인 시 auth.uid, 아니면 기기ID.
    static func myID() async -> String { await SupabaseConfig.ownerID() }

    /// 1:1 스레드 메시지 시간순 조회(item_id + buyer). 참가자(구매자/판매자)만 RLS 허용.
    static func fetchMessages(itemId: String, buyer: String) async -> [ChatMessage]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let i = itemId.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let b = buyer.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,buyer,device_id,author_name,body,created_at"
        guard let url = URL(string: "\(base)/rest/v1/market_chat_message?item_id=eq.\(i)&buyer=eq.\(b)&select=\(select)&order=created_at.asc&limit=300") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 10
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 익명 참가자 RLS 매칭
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return nil }
        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("[MarketBackend] fetchMessages HTTP \(http.statusCode)")
            #endif
            return nil
        }
        guard let dtos = try? JSONDecoder().decode([ChatMessageDTO].self, from: data) else { return nil }
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

    /// 1:1 스레드 전송. buyer = 그 스레드의 구매자 식별. 성공 true.
    @discardableResult
    static func sendMessage(itemId: String, buyer: String, body: String, authorName: String) async -> Bool {
        let t = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              !t.isEmpty, let url = URL(string: "\(base)/rest/v1/market_chat_message") else { return false }
        var req = URLRequest(url: url); req.httpMethod = "POST"; req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")  // 익명 참가자 RLS 매칭
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "item_id": itemId, "buyer": buyer, "device_id": await SupabaseConfig.ownerID(),
            "author_name": String(authorName.prefix(40)), "body": String(t.prefix(2000)),
        ])
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return false }
        return true
    }

    /// 판매자용 — 내 매물에 들어온 문의 스레드 목록(구매자별 최신 메시지). RLS로 판매자만 전체 조회 가능.
    struct ChatThread: Identifiable { let id: String; let buyer: String; let buyerName: String; let lastText: String; let lastDate: Date }
    static func fetchThreads(itemId: String) async -> [ChatThread]? {
        guard SupabaseConfig.isConfigured, let base = SupabaseConfig.url, let key = SupabaseConfig.anonKey,
              let i = itemId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        let select = "id,buyer,device_id,author_name,body,created_at"
        guard let url = URL(string: "\(base)/rest/v1/market_chat_message?item_id=eq.\(i)&select=\(select)&order=created_at.asc&limit=500") else { return nil }
        var req = URLRequest(url: url); req.timeoutInterval = 12
        req.setValue(key, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(await authBearer())", forHTTPHeaderField: "Authorization")
        req.setValue(await SupabaseConfig.ownerID(), forHTTPHeaderField: "x-device-id")
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let dtos = try? JSONDecoder().decode([ChatMessageDTO].self, from: data) else { return nil }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        // 구매자별로 묶어 최신 메시지만(시간순이라 마지막이 최신). 구매자 본인이 보낸 닉네임 우선.
        var byBuyer: [String: ChatThread] = [:]
        for d in dtos {
            guard let buyer = d.buyer, !buyer.isEmpty else { continue }
            let date = d.created_at.flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) } ?? Date()
            // 구매자가 보낸 메시지의 닉네임을 스레드 이름으로(없으면 기존 유지/이웃)
            let buyerName = (d.device_id == buyer ? d.author_name : byBuyer[buyer]?.buyerName) ?? byBuyer[buyer]?.buyerName ?? "이웃"
            byBuyer[buyer] = ChatThread(id: buyer, buyer: buyer, buyerName: buyerName,
                                        lastText: d.body ?? "", lastDate: date)
        }
        return byBuyer.values.sorted { $0.lastDate > $1.lastDate }
    }
}
