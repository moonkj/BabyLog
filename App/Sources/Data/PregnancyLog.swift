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
    }

    let id: UUID
    let pregnancyId: UUID
    let date: Date
    let kind: Kind
    var value: Double

    init(id: UUID = UUID(), pregnancyId: UUID, date: Date, kind: Kind, value: Double) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.date = date
        self.kind = kind
        self.value = value
    }
}
