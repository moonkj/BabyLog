// PersistenceCompatTests.swift
// BabyLogTests — 저장 스키마 하위호환 (데이터 손실 방지)

import XCTest
@testable import BabyLog

final class PersistenceCompatTests: XCTestCase {

    /// 마켓/크루 키가 전혀 없는 구 버전 저장 파일도 디코딩되어야 하며,
    /// 기존 children/diaryEntries는 절대 손실되면 안 된다.
    func test_decodesLegacyStateWithoutMarketCrewKeys() throws {
        let cid = UUID().uuidString
        let legacy = """
        {
          "pregnancies": [],
          "children": [{"id":"\(cid)","name":"지호","birthDate":"2024-01-01T00:00:00Z"}],
          "diaryEntries": [{"id":"\(UUID().uuidString)","childId":"\(cid)","date":"2025-01-01T00:00:00Z","recordType":"photo","photoRef":"a.jpg"}]
        }
        """.data(using: .utf8)!
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let state = try dec.decode(PersistableState.self, from: legacy)
        XCTAssertEqual(state.children.count, 1)
        XCTAssertEqual(state.children.first?.name, "지호")
        XCTAssertEqual(state.diaryEntries.count, 1)
        XCTAssertEqual(state.diaryEntries.first?.photoRef, "a.jpg")
        // 신규 키 없으면 빈 기본값 (손실 아님)
        XCTAssertTrue(state.marketItems.isEmpty)
        XCTAssertTrue(state.crews.isEmpty)
    }

    /// 전체 라운드트립 — 저장 후 로드 시 동일 (children/diary 보존)
    func test_roundTripPreservesData() throws {
        let cid = UUID()
        let state = PersistableState(
            children: [Child(id: cid, name: "지호", birthDate: Date(), gender: nil,
                             profileImageRef: "p.jpg", caregiverRole: nil, pregnancyId: nil)],
            diaryEntries: [DiaryEntry(childId: cid, date: Date(), recordType: "photo", photoRef: "a.jpg")]
        )
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let back = try dec.decode(PersistableState.self, from: try enc.encode(state))
        XCTAssertEqual(back.children.first?.profileImageRef, "p.jpg")
        XCTAssertEqual(back.diaryEntries.first?.photoRef, "a.jpg")
    }
}
