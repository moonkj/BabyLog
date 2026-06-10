// AppStorePregnancyLogTests.swift
// BabyLogTests — 임신 태동·체중 영속 회귀 방지

import XCTest
@testable import BabyLog

final class AppStorePregnancyLogTests: XCTestCase {

    func test_movementCount_upsertSameDay() {
        let store = AppStore()
        let pid = UUID()
        XCTAssertEqual(store.todayMovementCount(pregnancyId: pid), 0)
        store.setMovementCount(pregnancyId: pid, count: 3)
        XCTAssertEqual(store.todayMovementCount(pregnancyId: pid), 3)
        store.setMovementCount(pregnancyId: pid, count: 7)   // upsert, 새 로그 생성 X
        XCTAssertEqual(store.todayMovementCount(pregnancyId: pid), 7)
        XCTAssertEqual(store.pregnancyLogs.filter { $0.kind == .movement }.count, 1)
    }

    func test_movementCount_zeroRemovesLog() {
        let store = AppStore()
        let pid = UUID()
        store.setMovementCount(pregnancyId: pid, count: 5)
        store.setMovementCount(pregnancyId: pid, count: 0)
        XCTAssertEqual(store.todayMovementCount(pregnancyId: pid), 0)
        XCTAssertTrue(store.pregnancyLogs.isEmpty)
    }

    func test_movementCount_isScopedPerPregnancy() {
        let store = AppStore()
        let a = UUID(); let b = UUID()
        store.setMovementCount(pregnancyId: a, count: 4)
        XCTAssertEqual(store.todayMovementCount(pregnancyId: a), 4)
        XCTAssertEqual(store.todayMovementCount(pregnancyId: b), 0)
    }

    func test_addWeight_appendsAndSortsAndIgnoresNonPositive() {
        let store = AppStore()
        let pid = UUID()
        let cal = Calendar.current
        let d1 = cal.date(byAdding: .day, value: -2, to: Date())!
        let d2 = Date()
        store.addPregnancyWeight(pregnancyId: pid, kg: 58.4, on: d2)
        store.addPregnancyWeight(pregnancyId: pid, kg: 57.0, on: d1)
        store.addPregnancyWeight(pregnancyId: pid, kg: 0, on: d2)     // 무시
        let weights = store.pregnancyWeights(pregnancyId: pid)
        XCTAssertEqual(weights.count, 2)
        XCTAssertEqual(weights.first?.value, 57.0)   // 오름차순
        XCTAssertEqual(weights.last?.value, 58.4)
    }

    func test_bellyPhoto_addSortDelete() {
        let store = AppStore()
        let pid = UUID()
        store.addBellyPhoto(pregnancyId: pid, week: 30, photoRef: "a.jpg")
        store.addBellyPhoto(pregnancyId: pid, week: 12, photoRef: "b.jpg")
        let photos = store.bellyPhotos(pregnancyId: pid)
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(photos.first?.value, 12)   // 주차 오름차순
        XCTAssertEqual(photos.last?.value, 30)
        store.deleteBellyPhoto(id: photos.first!.id)
        XCTAssertEqual(store.bellyPhotos(pregnancyId: pid).count, 1)
    }

    func test_pregnancyLogs_persistRoundTrip() throws {
        var state = PersistableState()
        state.pregnancyLogs = [
            PregnancyLog(pregnancyId: UUID(), date: Date(), kind: .movement, value: 6),
            PregnancyLog(pregnancyId: UUID(), date: Date(), kind: .weight, value: 59.1)
        ]
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        let decoded = try dec.decode(PersistableState.self, from: try enc.encode(state))
        XCTAssertEqual(decoded.pregnancyLogs.count, 2)
        XCTAssertEqual(decoded.pregnancyLogs.first(where: { $0.kind == .weight })?.value, 59.1)
    }
}
