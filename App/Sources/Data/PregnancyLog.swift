// PregnancyLog.swift
// BabyLog — 임신 기록(태동·체중) 영속 모델
//
// 태아 가이드/배 사진은 별도(가이드=정적 콘텐츠, 사진=사진 저장 시스템).
// 여기서는 일일 태동 카운트와 체중 기록만 영속한다.

import Foundation

struct PregnancyLog: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case movement   // value = 그 날의 태동 횟수
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
}
