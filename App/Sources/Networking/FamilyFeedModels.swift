// FamilyFeedModels.swift
// BabyLog — Pro 가족 피드 모델 (Supabase bl_* 테이블 ↔ Swift).
// PostgREST JSON(snake_case) 디코딩. 미디어 바이트는 R2(여기엔 키/URL만).

import Foundation

struct BLFamily: Identifiable, Codable, Equatable {
    let id: String
    let ownerUid: String
    var name: String
    enum CodingKeys: String, CodingKey { case id, ownerUid = "owner_uid", name }
}

struct BLFamilyMember: Identifiable, Codable, Equatable {
    let id: String
    let familyId: String
    let uid: String?
    let role: String          // parent | grandparent
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case id, familyId = "family_id", uid, role, displayName = "display_name"
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
