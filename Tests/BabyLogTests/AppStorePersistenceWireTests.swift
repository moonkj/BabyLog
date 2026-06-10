// AppStorePersistenceWireTests.swift
// BabyLogTests
//
// QA — AppStore + LocalPersistence 자동 영속화(Wire) 통합 검증
//
// ============================================================
// [계약과 어긋날 수 있는 지점]
//
// 1. AppStore 생성자 시그니처
//    - 계약: AppStore(pregnancies:children:bus:persistence:)
//    - 현재 구현(AppStore.swift)에는 persistence 파라미터가 없다.
//      코더가 AppStore에 LocalPersistence 의존성을 추가해야 이 파일이 컴파일된다.
//    - 현재 init(pregnancies:children:bus:)는 이미 존재하므로,
//      기존 파라미터에 persistence: 를 추가하거나 별도 이니셜라이저를 제공해야 한다.
//
// 2. enableAutoPersist() 메서드
//    - 계약: AppStore가 enableAutoPersist()를 호출하면
//      상태 변경 시 자동으로 LocalPersistence에 저장된다.
//    - 디바운스 간격에 대한 계약이 없다. 이 테스트는 0.6초 대기 후
//      저장이 완료되었다고 가정하는데, 구현이 더 긴 디바운스를 사용하면
//      테스트가 false negative를 낼 수 있다.
//    - 디바운스가 없는 동기 구현이라면 Task.sleep 없이도 통과한다.
//
// 3. 복원 방식
//    - 계약: 같은 URL의 LocalPersistence로 새 AppStore를 생성하면
//      이전 상태가 자동으로 복원된다.
//    - 구현에 따라 init 시 자동 load할 수도 있고,
//      명시적으로 restore()를 호출해야 할 수도 있다.
//      이 테스트는 AppStore(persistence: url)가 init에서 자동으로 복원한다고 가정한다.
//      만약 코더가 별도 restore() 호출을 요구한다면 테스트를 수정해야 한다.
//
// 4. commitBirthTransition 의존
//    - 상태 변경 트리거로 commitBirthTransition을 사용한다.
//      현재 AppStore에 이미 구현되어 있으므로 추가 계약 없이 사용 가능하다.
//      단, persistence 파라미터 추가 후 AppStore 내부 구현이 변경되면
//      commitBirthTransition 동작이 달라질 수 있다.
//
// 5. Task.sleep 정밀도
//    - 0.6초(600_000_000 nanoseconds) 대기는 테스트 환경에서
//      CI 부하에 따라 불안정할 수 있다.
//      필요 시 XCTestExpectation + fulfillOnSave 패턴으로 교체 권장.
//
// 6. tearDown 임시 파일 삭제
//    - 테스트 종료 후 tempURL 파일을 삭제한다.
//      AppStore가 추가 파일(예: WAL, 백업)을 생성한다면 별도 삭제 필요.
// ============================================================

import XCTest
import Combine
@testable import BabyLog

final class AppStorePersistenceWireTests: XCTestCase {

    // MARK: - Properties

    private var tempURL: URL!
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyLogWireTest_\(UUID().uuidString).json")
    }

    override func tearDown() {
        cancellables.removeAll()
        if let url = tempURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        tempURL = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 테스트용 활성 임신 픽스처
    private func makeActivePregnancy() -> Pregnancy {
        Pregnancy(
            id: UUID(),
            lmpDate: makeDate("2024-12-01"),
            eddDate: makeDate("2025-09-01"),
            fetusCount: 1,
            nickname: "콩이",
            clinic: "행복산부인과",
            status: .active
        )
    }

    /// 테스트용 BirthTransitionInput 픽스처
    private func makeValidInput() -> BirthTransitionInput {
        BirthTransitionInput(
            childName: "김아이",
            birthDate: makeDate("2025-09-01"),
            gender: .girl
        )
    }

    // MARK: - 자동 영속화: commitBirthTransition 후 복원 검증

    /// enableAutoPersist() 활성화 → commitBirthTransition → 디바운스 대기 →
    /// 새 AppStore(같은 url) 생성 시 children이 복원되어야 한다.
    func test_autoPersist_afterBirthTransition_restoredInNewStore() async throws {
        // 1. 임시 URL LocalPersistence 생성
        let persistence = LocalPersistence(url: tempURL)

        // 2. 임신 데이터로 AppStore 구성 + 자동 영속화 활성화
        let pregnancy = makeActivePregnancy()
        let bus = EventBus()
        let store = AppStore(
            pregnancies: [pregnancy],
            children: [],
            bus: bus,
            persistence: persistence
        )
        store.enableAutoPersist()

        // 3. 상태 변경 트리거 — commitBirthTransition
        let result = store.commitBirthTransition(
            pregnancyId: pregnancy.id,
            input: makeValidInput()
        )

        guard case .success(let savedChild) = result else {
            XCTFail("commitBirthTransition이 성공해야 한다; 실제: \(result)")
            return
        }

        // 4. 디바운스 대기 (0.6초)
        try await Task.sleep(nanoseconds: 600_000_000)

        // 5. 같은 URL로 새 AppStore 생성 → 자동 복원 기대
        let restoredStore = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        // 6. children이 복원되어 있어야 한다
        XCTAssertEqual(
            restoredStore.children.count, 1,
            "자동 영속화 후 새 AppStore는 children을 1개 복원해야 한다"
        )

        let restoredChild = restoredStore.children.first
        XCTAssertEqual(
            restoredChild?.id, savedChild.id,
            "복원된 child.id는 저장된 child.id와 동일해야 한다"
        )
        XCTAssertEqual(
            restoredChild?.name, savedChild.name,
            "복원된 child.name은 저장된 child.name과 동일해야 한다"
        )
        XCTAssertEqual(
            restoredChild?.pregnancyId, pregnancy.id,
            "복원된 child.pregnancyId는 원본 pregnancy.id와 동일해야 한다"
        )
    }

    // MARK: - 자동 영속화: pregnancy 상태(delivered)도 복원

    /// commitBirthTransition 성공 후 pregnancy.status==.delivered도 복원되어야 한다.
    func test_autoPersist_pregnancyStatusDelivered_isRestored() async throws {
        let persistence = LocalPersistence(url: tempURL)
        let pregnancy = makeActivePregnancy()
        let bus = EventBus()

        let store = AppStore(
            pregnancies: [pregnancy],
            children: [],
            bus: bus,
            persistence: persistence
        )
        store.enableAutoPersist()

        store.commitBirthTransition(pregnancyId: pregnancy.id, input: makeValidInput())

        // 디바운스 대기
        try await Task.sleep(nanoseconds: 600_000_000)

        // 새 AppStore 생성
        let restoredStore = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        let restoredPregnancy = restoredStore.pregnancies.first(where: { $0.id == pregnancy.id })
        XCTAssertNotNil(restoredPregnancy,
            "복원된 store에 pregnancy가 존재해야 한다")
        XCTAssertEqual(
            restoredPregnancy?.status, .delivered,
            "복원된 pregnancy.status는 .delivered여야 한다"
        )
    }

    // MARK: - enableAutoPersist 없으면 저장 안 됨

    /// enableAutoPersist()를 호출하지 않으면 상태 변경 후 파일이 생성되지 않아야 한다.
    func test_withoutEnableAutoPersist_fileNotCreated() async throws {
        let persistence = LocalPersistence(url: tempURL)
        let pregnancy = makeActivePregnancy()
        let bus = EventBus()

        // enableAutoPersist() 미호출
        let store = AppStore(
            pregnancies: [pregnancy],
            children: [],
            bus: bus,
            persistence: persistence
        )
        // enableAutoPersist() 호출 없음

        store.commitBirthTransition(pregnancyId: pregnancy.id, input: makeValidInput())

        // 짧은 대기 후 파일 미존재 확인
        try await Task.sleep(nanoseconds: 200_000_000)

        let loaded = try persistence.load()
        XCTAssertNil(
            loaded,
            "enableAutoPersist() 미호출 시 자동 저장이 발생하지 않아야 한다"
        )
    }

    // MARK: - XCTestExpectation 방식: 저장 완료 이벤트 대기

    /// LocalPersistence.load()가 non-nil을 반환할 때까지 폴링하는 방식으로
    /// 디바운스 타이밍에 덜 민감하게 검증한다.
    func test_autoPersist_expectation_fileWrittenWithinTimeout() async throws {
        let persistence = LocalPersistence(url: tempURL)
        let pregnancy = makeActivePregnancy()
        let bus = EventBus()

        let store = AppStore(
            pregnancies: [pregnancy],
            children: [],
            bus: bus,
            persistence: persistence
        )
        store.enableAutoPersist()

        store.commitBirthTransition(pregnancyId: pregnancy.id, input: makeValidInput())

        // XCTestExpectation: 최대 2초 내 파일 저장 완료 기대
        let expectation = XCTestExpectation(description: "LocalPersistence 파일 저장 완료")

        Task {
            // 최대 2초 동안 100ms 간격으로 폴링
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if (try? persistence.load()) != nil {
                    expectation.fulfill()
                    return
                }
            }
        }

        await fulfillment(of: [expectation], timeout: 2.5)

        // 최종 검증
        let loaded = try persistence.load()
        XCTAssertNotNil(loaded,
            "자동 영속화 후 LocalPersistence.load()는 non-nil을 반환해야 한다")
        XCTAssertEqual(loaded?.children.count, 1,
            "저장된 상태에 children이 1개 있어야 한다")
    }

    // MARK: - 빈 상태에서 시작: 파일 없음 → enableAutoPersist → 변경 없으면 파일 미생성

    /// 상태 변경 없이 enableAutoPersist()만 호출하면 파일이 생성되지 않아야 한다.
    func test_autoPersist_noStateChange_noFileCreated() async throws {
        let persistence = LocalPersistence(url: tempURL)
        let bus = EventBus()

        let store = AppStore(
            pregnancies: [],
            children: [],
            bus: bus,
            persistence: persistence
        )
        store.enableAutoPersist()
        // 상태 변경 없음

        try await Task.sleep(nanoseconds: 600_000_000)

        let loaded = try persistence.load()
        // 구현에 따라 초기 빈 상태도 저장할 수 있으므로,
        // nil이거나 빈 배열을 가진 상태여야 한다.
        if let state = loaded {
            XCTAssertTrue(
                state.children.isEmpty,
                "상태 변경 없이 저장된 경우에도 children은 비어있어야 한다"
            )
            XCTAssertTrue(
                state.pregnancies.isEmpty,
                "상태 변경 없이 저장된 경우에도 pregnancies는 비어있어야 한다"
            )
        }
        // loaded==nil이면 "파일 미생성" 으로 정상 통과
    }
}
