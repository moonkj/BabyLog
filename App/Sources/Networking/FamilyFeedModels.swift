// FamilyFeedModels.swift
// BabyLog — Pro 가족 피드 모델 (Supabase bl_* 테이블 ↔ Swift).
// PostgREST JSON(snake_case) 디코딩. 미디어 바이트는 R2(여기엔 키/URL만).

import Foundation

struct BLFamily: Identifiable, Codable, Equatable {
    let id: String
    let ownerUid: String
    var name: String
    var partnerUid: String?   // 무료 '배우자'(구독 만료 시 유지될 1명). 미지정이면 첫 승인자 폴백.
    enum CodingKeys: String, CodingKey { case id, ownerUid = "owner_uid", name, partnerUid = "partner_uid" }

    init(id: String, ownerUid: String, name: String, partnerUid: String? = nil) {
        self.id = id; self.ownerUid = ownerUid; self.name = name; self.partnerUid = partnerUid
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id         = try c.decode(String.self, forKey: .id)
        ownerUid   = try c.decode(String.self, forKey: .ownerUid)
        name       = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "우리 가족"
        partnerUid = try? c.decodeIfPresent(String.self, forKey: .partnerUid)
    }
}

struct BLFamilyMember: Identifiable, Codable, Equatable {
    let id: String
    let familyId: String
    let uid: String?
    let role: String          // parent | grandparent
    let displayName: String
    let approved: Bool        // 합류 승인 여부(주인=true, 신규 합류=false=대기)
    enum CodingKeys: String, CodingKey {
        case id, familyId = "family_id", uid, role, displayName = "display_name", approved
    }

    // 서버 응답이 일부 필드를 빠뜨려도 안전하게(approved 기본 false=대기).
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        familyId    = try c.decode(String.self, forKey: .familyId)
        uid         = try? c.decodeIfPresent(String.self, forKey: .uid)
        role        = (try? c.decodeIfPresent(String.self, forKey: .role)) ?? "parent"
        displayName = (try? c.decodeIfPresent(String.self, forKey: .displayName)) ?? "가족"
        approved    = (try? c.decodeIfPresent(Bool.self, forKey: .approved)) ?? false
    }
}

struct BLPostMedia: Identifiable, Codable, Equatable {
    let id: String
    let kind: String          // photo | video
    let r2Key: String
    let thumbKey: String?
    enum CodingKeys: String, CodingKey {
        case id, kind, r2Key = "r2_key", thumbKey = "thumb_key"
    }
}

struct BLReaction: Codable, Equatable {
    let uid: String
    let authorName: String?   // 좋아요 누른 사람 표시이름(댓글과 동일). 구 데이터는 nil/'가족'.
    enum CodingKeys: String, CodingKey { case uid, authorName = "author_name" }

    init(uid: String, authorName: String? = nil) { self.uid = uid; self.authorName = authorName }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        uid = try c.decode(String.self, forKey: .uid)
        authorName = try? c.decodeIfPresent(String.self, forKey: .authorName)
    }
}

struct BLComment: Identifiable, Codable, Equatable {
    let id: String
    let uid: String
    let authorName: String
    let text: String
    let createdAt: String?
    enum CodingKeys: String, CodingKey {
        case id, uid, authorName = "author_name", text, createdAt = "created_at"
    }
}

/// 피드 포스트 — PostgREST 임베딩으로 미디어·반응·댓글을 함께 로드.
struct BLFeedPost: Identifiable, Codable, Equatable {
    let id: String
    let familyId: String
    let authorUid: String
    let childLabel: String?
    let caption: String?
    let milestone: String?
    let createdAt: String?
    var media: [BLPostMedia]
    var reactions: [BLReaction]
    var comments: [BLComment]

    enum CodingKeys: String, CodingKey {
        case id, familyId = "family_id", authorUid = "author_uid"
        case childLabel = "child_label", caption, milestone, createdAt = "created_at"
        case media = "bl_post_media", reactions = "bl_reaction", comments = "bl_comment"
    }

    // 임베딩이 비어 올 수 있어 관대 디코딩(기본 빈 배열).
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id        = try c.decode(String.self, forKey: .id)
        familyId  = try c.decode(String.self, forKey: .familyId)
        authorUid = try c.decode(String.self, forKey: .authorUid)
        childLabel = try? c.decodeIfPresent(String.self, forKey: .childLabel)
        caption    = try? c.decodeIfPresent(String.self, forKey: .caption)
        milestone  = try? c.decodeIfPresent(String.self, forKey: .milestone)
        createdAt  = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        media     = (try? c.decodeIfPresent([BLPostMedia].self, forKey: .media)) ?? []
        reactions = (try? c.decodeIfPresent([BLReaction].self, forKey: .reactions)) ?? []
        comments  = (try? c.decodeIfPresent([BLComment].self, forKey: .comments)) ?? []
    }
}
