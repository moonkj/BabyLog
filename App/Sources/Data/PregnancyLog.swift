// PregnancyLog.swift
// BabyLog — 임신 기록(체중·배 사진·메모) 영속 모델
//
// 태아 가이드는 정적 콘텐츠로 별도. 여기서는 체중·배 사진·메모를 영속한다.
// (.movement = 구 태동 카운터. 기능은 제거됐으나 구 저장 데이터 디코딩 호환을 위해 케이스만 유지.)

import Foundation

struct PregnancyLog: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case movement   // (구) 태동 카운터 — 기능 제거됨. 구 데이터 디코딩 호환용으로만 유지(미표시).
        case weight     // value = kg
        case belly      // value = 주차, photoRef = 로컬 배 사진
        case memo       // note = 메모 텍스트
    }

    let id: UUID
    let pregnancyId: UUID
    let date: Date
    let kind: Kind
    var value: Double
    /// 배 사진 로컬 파일명 (kind == .belly). 서버 비전송.
    var photoRef: String?
    /// 메모 텍스트 (kind == .memo). 옵셔널 → 구 데이터 디코딩 자동 호환.
    var note: String?

    init(id: UUID = UUID(), pregnancyId: UUID, date: Date, kind: Kind,
         value: Double, photoRef: String? = nil, note: String? = nil) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.date = date
        self.kind = kind
        self.value = value
        self.photoRef = photoRef
        self.note = note
    }

    // 하위 호환 디코딩 — 키 누락/미지 Kind 값에도 임신 기록 전체가 깨지지 않게
    // (ChatMessage 패턴). 인코딩은 합성 유지(키 1:1 동일).
    enum CodingKeys: String, CodingKey {
        case id, pregnancyId, date, kind, value, photoRef, note
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        // pregnancyId 누락 시 새 UUID — 어느 임신과도 매칭되지 않아 표시되진 않지만
        // 전체 디코딩 실패(데이터 소실)보다 낫다.
        pregnancyId = try c.decodeIfPresent(UUID.self, forKey: .pregnancyId) ?? UUID()
        date        = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        // 미지 rawValue(미래 버전이 추가한 종류)는 .memo로 흡수 — 태동/체중/배사진으로
        // 잘못 분류하면 카운트·차트가 오염되므로 가장 무해한 종류를 택한다.
        let rawKind = try c.decodeIfPresent(String.self, forKey: .kind)
        kind        = rawKind.flatMap(Kind.init(rawValue:)) ?? .memo
        value       = try c.decodeIfPresent(Double.self, forKey: .value) ?? 0
        photoRef    = try c.decodeIfPresent(String.self, forKey: .photoRef)
        note        = try c.decodeIfPresent(String.self, forKey: .note)
    }
}
