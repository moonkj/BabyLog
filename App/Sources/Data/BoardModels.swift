// BoardModels.swift
// BabyLog · 성장 보드(Growth Board) — 폴라로이드 카드를 흰 캔버스에 자유 배치, 연결선·스티커.
// Re-Link 캔버스 컨셉 차용. 사진은 PhotoStore 재사용(기록 참조) 또는 보드 전용(4096px) 저장.
// 영속: PersistableState에 growthBoards로 포함 → 자동저장·iCloud 백업·표준 익스포트 자동 편입.
// 하위호환: 모든 모델은 decodeIfPresent + 기본값(구 저장파일 무손상 — 프로젝트 정책 통일).

import Foundation

/// 폴라로이드 카드 1장.
struct BoardCard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: String = "photo"   // "photo"(폴라로이드) | "memo"(텍스트 메모지)
    /// PhotoStore 파일명. 보드 전용 사진(4096 저장) 또는 기록 사진 참조.
    var photoRef: String?
    /// 기록(DiaryEntry)에서 가져온 경우 원본 id — 참조만(사진 미복제). nil이면 보드 전용(삭제 시 사진도 정리).
    var sourceEntryId: String?
    var caption: String = ""     // 폴라로이드 하단 글씨("20개월" 등)
    var title: String = ""       // 메모 제목
    var note: String = ""        // 상세 메모(폴라로이드) / 메모 본문(메모 카드)
    var theme: String?           // 메모 색 테마 키(mint/pink/amber/blue/coral/purple)
    var x: Double = 2000         // 캔버스 좌표(카드 중심)
    var y: Double = 2000
    var rotation: Double = 0     // 라디안 — 살짝 기울임
    var createdAt: Date = Date()

    init(id: UUID = UUID(), kind: String = "photo", photoRef: String? = nil, sourceEntryId: String? = nil,
         caption: String = "", title: String = "", note: String = "", theme: String? = nil,
         x: Double = 2000, y: Double = 2000, rotation: Double = 0, createdAt: Date = Date()) {
        self.id = id; self.kind = kind; self.photoRef = photoRef; self.sourceEntryId = sourceEntryId
        self.caption = caption; self.title = title; self.note = note; self.theme = theme
        self.x = x; self.y = y; self.rotation = rotation; self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey { case id, kind, photoRef, sourceEntryId, caption, title, note, theme, x, y, rotation, createdAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "photo"
        photoRef = try c.decodeIfPresent(String.self, forKey: .photoRef)
        sourceEntryId = try c.decodeIfPresent(String.self, forKey: .sourceEntryId)
        caption = try c.decodeIfPresent(String.self, forKey: .caption) ?? ""
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        theme = try c.decodeIfPresent(String.self, forKey: .theme)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 2000
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 2000
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// 카드 사이 연결선.
struct BoardConnection: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var fromId: UUID
    var toId: UUID
    var label: String?           // 선 위 텍스트(선택) — nil이면 작은 '글 추가' 칩만 표시

    init(id: UUID = UUID(), fromId: UUID, toId: UUID, label: String? = nil) {
        self.id = id; self.fromId = fromId; self.toId = toId; self.label = label
    }

    enum CodingKeys: String, CodingKey { case id, fromId, toId, label }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fromId = try c.decode(UUID.self, forKey: .fromId)
        toId = try c.decode(UUID.self, forKey: .toId)
        label = try c.decodeIfPresent(String.self, forKey: .label)
    }
}

/// 카드 밖 빈 면에 붙이는 스티커.
struct BoardSticker: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: String = "star"        // 디자인 스티커 키(에셋 sticker_<kind>)
    var x: Double = 2000
    var y: Double = 2000
    var scale: Double = 1
    var rotation: Double = 0

    init(id: UUID = UUID(), kind: String = "star", x: Double = 2000, y: Double = 2000,
         scale: Double = 1, rotation: Double = 0) {
        self.id = id; self.kind = kind; self.x = x; self.y = y; self.scale = scale; self.rotation = rotation
    }

    /// 스티커 종류의 한국어 이름(VoiceOver 라벨·트레이 공용 — 33종 단일 출처). 미등록 키는 그대로 반환.
    static func displayName(_ kind: String) -> String {
        let names: [String: String] = [
            "smile": "웃음", "giggle": "깔깔웃음", "love": "사랑", "sleepy": "졸린 얼굴", "cry": "우는 얼굴",
            "heart-pink": "분홍 하트", "heart-coral": "코랄 하트", "heart-gold": "금빛 하트",
            "cake": "케이크", "crown": "왕관", "medal": "메달", "firststep": "첫걸음", "tooth": "치아",
            "boy": "남자아이", "girl": "여자아이", "mom": "엄마", "dad": "아빠", "grandma": "할머니", "grandpa": "할아버지",
            "bottle": "젖병", "paci": "공갈젖꼭지", "rattle": "딸랑이", "foot": "발도장", "bib": "턱받이",
            "sun": "해", "moon": "달", "star": "별", "cloud": "구름", "flower": "꽃", "leaf": "잎사귀",
            "ribbon": "리본", "sparkle": "반짝임", "speech": "말풍선",
        ]
        return names[kind] ?? kind
    }

    enum CodingKeys: String, CodingKey { case id, kind, x, y, scale, rotation }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "star"
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 2000
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 2000
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        rotation = try c.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
    }
}

/// 성장 보드(아이 1명당 여러 개 — 무료 대표 1개만 편집 / Pro 최대 100개·대표 변경 가능, UI에서 게이팅).
struct GrowthBoard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var childId: UUID
    var title: String = ""       // 보드 이름(빈 값이면 "{아이}의 성장 보드" 기본 사용)
    var isPrimary: Bool = false  // 대표 보드 — 무료에서도 편집 가능한 1개(대표 변경은 Pro만)
    var cards: [BoardCard] = []
    var connections: [BoardConnection] = []
    var stickers: [BoardSticker] = []
    var updatedAt: Date = Date()

    /// 캔버스 논리 크기(Re-Link와 동일 4000². 확장은 증가만).
    static let canvasSize: Double = 4000
    /// 아이당 최대 보드 수(Pro 상한). 무료는 대표 1개만 편집.
    static let maxPerChild: Int = 100

    init(id: UUID = UUID(), childId: UUID, title: String = "", isPrimary: Bool = false, cards: [BoardCard] = [],
         connections: [BoardConnection] = [], stickers: [BoardSticker] = [], updatedAt: Date = Date()) {
        self.id = id; self.childId = childId; self.title = title; self.isPrimary = isPrimary; self.cards = cards
        self.connections = connections; self.stickers = stickers; self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey { case id, childId, title, isPrimary, cards, connections, stickers, updatedAt }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        childId = try c.decode(UUID.self, forKey: .childId)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false
        cards = try c.decodeIfPresent([BoardCard].self, forKey: .cards) ?? []
        connections = try c.decodeIfPresent([BoardConnection].self, forKey: .connections) ?? []
        stickers = try c.decodeIfPresent([BoardSticker].self, forKey: .stickers) ?? []
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}
