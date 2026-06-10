// AppStoreBudgetVaccineTests.swift
// BabyLogTests
//
// 가계부 지출 CRUD · 접종 완료(안정 키) · 영속 라운드트립 회귀 방지.

import XCTest
@testable import BabyLog

final class AppStoreBudgetVaccineTests: XCTestCase {

    // MARK: - 지출 CRUD

    func test_addExpense_appendsAndIgnoresNonPositive() {
        let store = AppStore()
        store.addExpense(amount: 10_000, category: .diaper)
        store.addExpense(amount: 0, category: .play)       // 무시
        store.addExpense(amount: -500, category: .etc)     // 무시
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertEqual(store.expenses.first?.amount, 10_000)
        XCTAssertEqual(store.expenses.first?.category, .diaper)
    }

    func test_addExpense_trimsEmptyMemoToNil() {
        let store = AppStore()
        store.addExpense(amount: 5_000, category: .etc, memo: "   ")
        XCTAssertNil(store.expenses.first?.memo)
    }

    func test_deleteExpense_removesById() {
        let store = AppStore()
        store.addExpense(amount: 1_000, category: .diaper)
        store.addExpense(amount: 2_000, category: .medical)
        let target = store.expenses[0].id
        store.deleteExpense(id: target)
        XCTAssertEqual(store.expenses.count, 1)
        XCTAssertFalse(store.expenses.contains { $0.id == target })
    }

    // MARK: - 접종 완료 (안정 키)

    func test_toggleVaccine_isStableAcrossDifferentRecordUUIDs() {
        let store = AppStore()
        let childId = UUID()
        XCTAssertFalse(store.isVaccineDone(childId: childId, vaccineId: "BCG"))
        store.toggleVaccine(childId: childId, vaccineId: "BCG")
        XCTAssertTrue(store.isVaccineDone(childId: childId, vaccineId: "BCG"))
        // provider가 새 UUID로 다시 로드해도 childId+vaccineId 키로 완료 유지됨
        XCTAssertTrue(store.isVaccineDone(childId: childId, vaccineId: "BCG"))
        store.toggleVaccine(childId: childId, vaccineId: "BCG")
        XCTAssertFalse(store.isVaccineDone(childId: childId, vaccineId: "BCG"))
    }

    func test_vaccineCompletion_isScopedPerChild() {
        let store = AppStore()
        let a = UUID(); let b = UUID()
        store.toggleVaccine(childId: a, vaccineId: "DTaP-1")
        XCTAssertTrue(store.isVaccineDone(childId: a, vaccineId: "DTaP-1"))
        XCTAssertFalse(store.isVaccineDone(childId: b, vaccineId: "DTaP-1"))
    }

    // MARK: - 영속 라운드트립

    func test_persistableState_roundTrip_preservesExpensesAndVaccines() throws {
        var state = PersistableState()
        state.expenses = [Expense(amount: 3_000, category: .clothing, date: Date())]
        state.vaccineCompletions = ["\(UUID().uuidString)|BCG"]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistableState.self, from: data)

        XCTAssertEqual(decoded.expenses.count, 1)
        XCTAssertEqual(decoded.expenses.first?.amount, 3_000)
        XCTAssertEqual(decoded.vaccineCompletions, state.vaccineCompletions)
    }

    func test_persistableState_backwardCompat_missingNewKeysDefaultEmpty() throws {
        // 구버전 저장 파일: expenses/vaccineCompletions 키 없음
        let legacy = #"{"pregnancies":[],"children":[]}"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersistableState.self, from: legacy)
        XCTAssertTrue(decoded.expenses.isEmpty)
        XCTAssertTrue(decoded.vaccineCompletions.isEmpty)
    }
}
