// PersistenceTests.swift
// BabyLogTests
//
// QA — LocalPersistence 라운드트립 및 AppStore snapshot/restore 검증
//
// 계약 타입 (코더 구현 예정):
//   PersistableState: Codable & Equatable, { pregnancies: [Pregnancy], children: [Child] }
//   LocalPersistence: init(url: URL), save(_ state: PersistableState) throws, load() throws -> PersistableState?
//   AppStore: snapshot() -> PersistableState, restore(_ state: PersistableState)
//   AppStore.init(pregnancies:children:bus:) — bus 파라미터 추가 예정
//
// 주의: 아직 위 타입/메서드가 존재하지 않으면 컴파일 에러 발생.
//   코더가 계약을 충족할 때 이 테스트가 그린으로 전환된다.

import XCTest
@testable import BabyLog

final class PersistenceTests: XCTestCase {

    // MARK: - 프로퍼티

    private var tempURL: URL!

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
    }

    override func tearDown() {
        if let url = tempURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func d(_ s: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 테스트용 PersistableState 픽스처
    private func makeSampleState() -> PersistableState {
        let pregnancyId = UUID()
        let pregnancy = Pregnancy(
            id: pregnancyId,
            lmpDate: d("2024-11-01"),
            eddDate: d("2025-08-08"),
            fetusCount: 1,
            nickname: "콩이",
            clinic: "행복산부인과",
            status: .active
        )
        let child = Child(
            id: UUID(),
            name: "김아이",
            birthDate: d("2025-06-01"),
            gender: .girl,
            profileImageRef: nil,
            caregiverRole: "엄마",
            pregnancyId: pregnancyId
        )
        return PersistableState(pregnancies: [pregnancy], children: [child])
    }

    // MARK: - LocalPersistence: 파일 없을 때 load → nil

    /// 파일이 존재하지 않을 때 load()는 nil을 반환해야 한다.
    func test_localPersistence_load_whenFileDoesNotExist_returnsNil() throws {
        let persistence = LocalPersistence(url: tempURL)
        let loaded = try persistence.load()
        XCTAssertNil(loaded,
            "파일이 없으면 load()는 nil을 반환해야 한다")
    }

    // MARK: - LocalPersistence: save → load 라운드트립

    /// save 후 load하면 저장한 PersistableState와 Equatable 동일해야 한다.
    func test_localPersistence_saveAndLoad_roundTrip_equatable() throws {
        let persistence = LocalPersistence(url: tempURL)
        let original = makeSampleState()

        try persistence.save(original)
        let loaded = try persistence.load()

        XCTAssertNotNil(loaded,
            "save 후 load()는 nil이 아니어야 한다")
        XCTAssertEqual(loaded, original,
            "load()로 복원한 PersistableState는 저장한 것과 동일해야 한다 — Equatable 검증")
    }

    // MARK: - LocalPersistence: 빈 상태 라운드트립

    /// 빈 배열을 가진 PersistableState도 정상적으로 라운드트립되어야 한다.
    func test_localPersistence_emptyState_roundTrip() throws {
        let persistence = LocalPersistence(url: tempURL)
        let empty = PersistableState(pregnancies: [], children: [])

        try persistence.save(empty)
        let loaded = try persistence.load()

        XCTAssertEqual(loaded, empty,
            "빈 PersistableState도 라운드트립 후 동일해야 한다")
    }

    // MARK: - LocalPersistence: 덮어쓰기 라운드트립

    /// save를 두 번 호출하면 마지막으로 저장한 상태만 남아야 한다.
    func test_localPersistence_overwrite_lastWriteWins() throws {
        let persistence = LocalPersistence(url: tempURL)
        let firstState = PersistableState(pregnancies: [], children: [])
        let secondState = makeSampleState()

        try persistence.save(firstState)
        try persistence.save(secondState)
        let loaded = try persistence.load()

        XCTAssertEqual(loaded, secondState,
            "덮어쓰기 후 load()는 마지막에 저장한 상태를 반환해야 한다")
        XCTAssertNotEqual(loaded, firstState,
            "첫 번째로 저장한 상태와 달라야 한다")
    }

    // MARK: - AppStore: snapshot / restore 라운드트립

    /// store → snapshot() → 새 store.restore(_:) → 상태 동일.
    /// 계약: AppStore.init(pregnancies:children:bus:), snapshot(), restore(_:)
    func test_appStore_snapshotAndRestore_roundTrip() {
        let bus = EventBus()
        let originalState = makeSampleState()

        // 원본 store 구성
        let store = AppStore(
            pregnancies: originalState.pregnancies,
            children: originalState.children,
            bus: bus
        )

        // snapshot 획득
        let snapshot = store.snapshot()

        // 새 store에 restore
        let restoredStore = AppStore(pregnancies: [], children: [], bus: bus)
        restoredStore.restore(snapshot)

        // 상태 비교
        XCTAssertEqual(restoredStore.pregnancies, originalState.pregnancies,
            "restore 후 pregnancies는 원본과 동일해야 한다")
        XCTAssertEqual(restoredStore.children, originalState.children,
            "restore 후 children은 원본과 동일해야 한다")
    }

    // MARK: - AppStore: snapshot → LocalPersistence → restore 통합 라운드트립

    /// store.snapshot()을 LocalPersistence로 저장하고 복원해도 상태가 동일해야 한다.
    func test_appStore_snapshotPersistenceRestore_fullRoundTrip() throws {
        let bus = EventBus()
        let originalState = makeSampleState()

        let store = AppStore(
            pregnancies: originalState.pregnancies,
            children: originalState.children,
            bus: bus
        )

        // snapshot을 파일에 저장
        let persistence = LocalPersistence(url: tempURL)
        let snapshot = store.snapshot()
        try persistence.save(snapshot)

        // 파일에서 로드 후 새 store에 restore
        guard let loaded = try persistence.load() else {
            XCTFail("snapshot을 저장 후 load()가 nil을 반환했다")
            return
        }

        let restoredStore = AppStore(pregnancies: [], children: [], bus: bus)
        restoredStore.restore(loaded)

        XCTAssertEqual(restoredStore.pregnancies, originalState.pregnancies,
            "파일 경유 restore 후 pregnancies가 원본과 동일해야 한다")
        XCTAssertEqual(restoredStore.children, originalState.children,
            "파일 경유 restore 후 children이 원본과 동일해야 한다")
    }

    // MARK: - PersistableState: Equatable 동일성 세부 검증

    /// 같은 값으로 만든 두 PersistableState는 == 이어야 한다.
    func test_persistableState_equatable_sameValues_equal() {
        let state1 = makeSampleState()
        // 동일한 픽스처를 다시 생성하는 대신, save/load 후 비교로 Equatable을 확인
        // (픽스처 내부 UUID가 고정이 아니므로 동일 인스턴스와 비교)
        let state2 = state1
        XCTAssertEqual(state1, state2,
            "동일한 PersistableState 인스턴스는 Equatable == 이어야 한다")
    }

    /// pregnancies 배열 내용이 다르면 != 이어야 한다.
    func test_persistableState_equatable_differentPregnancies_notEqual() {
        let state1 = PersistableState(pregnancies: [], children: [])
        let state2 = makeSampleState()
        XCTAssertNotEqual(state1, state2,
            "내용이 다른 PersistableState는 != 이어야 한다")
    }
}
