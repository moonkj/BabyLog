// AppStoreOnboardingTests.swift
// BabyLogTests
//
// QA — AppStore 온보딩 API 계약 기반 단위 테스트
//
// ============================================================
// [계약과 어긋날 수 있는 지점 — 팀장 구현 전 주의사항]
//
// 1. selectedChild (computed var)
//    - 계약: selectedChildId가 있으면 해당 Child, 없으면 children.first.
//    - AppStore에 selectedChildId: UUID? 프로퍼티가 아직 없다.
//      팀장이 @Published private(set) var selectedChildId: UUID? 를 추가해야 한다.
//    - selectedChild 자체가 computed var인지 @Published var인지 미정.
//      이 테스트는 computed var 방식을 가정한다.
//
// 2. activePregnancy (computed var)
//    - 계약: pregnancies 중 status == .active인 첫 번째 항목.
//    - 역시 AppStore에 추가 필요. 순서(배열 삽입 순서)를 유지한다고 가정.
//
// 3. hasContent (computed var)
//    - 계약: children 또는 pregnancies 중 하나라도 비어있지 않으면 true.
//    - 현재 AppStore에 없음. 팀장 추가 필요.
//
// 4. completeBabyOnboarding(name:birthDate:gender:)
//    - 계약: 빈 이름(trim 후 empty)이면 추가하지 않음.
//    - 두 번 호출 시 selectedChild가 가장 마지막에 추가된 child를 가리키는지
//      (selectedChildId를 마지막 child.id로 갱신하는 정책) 팀장과 합의 필요.
//      이 테스트는 "마지막 추가된 child가 selectedChild" 정책을 가정한다.
//    - @MainActor isolation 여부 미정. 테스트는 동기 호출로 작성.
//
// 5. startPregnancy(lmp:edd:nickname:)
//    - 계약: status == .active 인 Pregnancy를 생성·추가.
//    - fetusCount 기본값이 1인지 팀장 구현 확인 필요.
//    - 여러 번 호출 시 activePregnancy는 첫 번째 .active 항목을 반환.
//      (배열 순서 유지 가정)
//
// 6. 영속화 연계 테스트
//    - completeBabyOnboarding 후 snapshot → 새 AppStore(동일 LocalPersistence) 복원.
//    - enableAutoPersist()의 0.5s 디바운스를 피하기 위해
//      직접 persistence.save(store.snapshot())을 사용하는 방식으로 작성.
//    - AppStore.snapshot() / AppStore.restore(_:) 은 현재 구현에 존재함.
//
// 7. AppStore 생성자
//    - 현재: init(pregnancies:children:bus:persistence:) — AppStore.swift에 구현됨.
//    - 온보딩 API 추가 후 기존 init 시그니처가 유지되어야 이 파일이 컴파일된다.
// ============================================================

import XCTest
import Combine
@testable import BabyLog

// MARK: - AppStoreOnboardingTests

final class AppStoreOnboardingTests: XCTestCase {

    // MARK: - Properties

    private var tempURL: URL!
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("BabyLogOnboardingTest_\(UUID().uuidString).json")
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

    /// "yyyy-MM-dd" 문자열을 현지 그레고리안 자정으로 변환
    private func d(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 빈 AppStore 픽스처 (pregnancies, children 모두 빈 배열)
    private func makeEmptyStore() -> AppStore {
        AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: nil
        )
    }

    // MARK: - 1. 초기 빈 Store 상태 검증

    /// 빈 store: hasContent==false, selectedChild==nil, activePregnancy==nil
    func test_initialEmptyStore_hasContentFalse_selectedChildNil_activePregnancyNil() {
        let store = makeEmptyStore()

        XCTAssertFalse(
            store.hasContent,
            "초기 빈 store의 hasContent는 false여야 한다"
        )
        XCTAssertNil(
            store.selectedChild,
            "초기 빈 store의 selectedChild는 nil이어야 한다"
        )
        XCTAssertNil(
            store.activePregnancy,
            "초기 빈 store의 activePregnancy는 nil이어야 한다"
        )
    }

    // MARK: - 2. completeBabyOnboarding — 정상 등록

    /// completeBabyOnboarding("지호", date, .boy) → children 1개, selectedChild.name=="지호", hasContent=true
    func test_completeBabyOnboarding_validName_addsChildAndSetsSelectedChild() {
        let store = makeEmptyStore()
        let birthDate = d("2025-03-15")

        store.completeBabyOnboarding(name: "지호", birthDate: birthDate, gender: .boy)

        XCTAssertEqual(
            store.children.count, 1,
            "completeBabyOnboarding 후 children에 정확히 1개가 추가되어야 한다"
        )
        XCTAssertEqual(
            store.children.first?.name, "지호",
            "추가된 child.name은 '지호'여야 한다"
        )
        XCTAssertEqual(
            store.children.first?.gender, .boy,
            "추가된 child.gender는 .boy여야 한다"
        )
        XCTAssertEqual(
            store.children.first?.birthDate, birthDate,
            "추가된 child.birthDate는 입력값과 동일해야 한다"
        )
        XCTAssertEqual(
            store.selectedChild?.name, "지호",
            "completeBabyOnboarding 후 selectedChild.name은 '지호'여야 한다"
        )
        XCTAssertTrue(
            store.hasContent,
            "child 추가 후 hasContent는 true여야 한다"
        )
    }

    /// gender가 nil인 경우도 정상 추가되어야 한다
    func test_completeBabyOnboarding_nilGender_addsChildSuccessfully() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: "아이", birthDate: d("2025-06-01"), gender: nil)

        XCTAssertEqual(store.children.count, 1,
            "gender=nil이어도 child가 추가되어야 한다")
        XCTAssertNil(store.children.first?.gender,
            "gender가 nil로 저장되어야 한다")
    }

    // MARK: - 3. completeBabyOnboarding — 빈 이름 정책 (추가하지 않음)

    /// completeBabyOnboarding(" ", ...) → 공백 이름 → children 변화 없음
    func test_completeBabyOnboarding_whitespaceName_doesNotAddChild() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: " ", birthDate: d("2025-03-15"), gender: .girl)

        XCTAssertTrue(
            store.children.isEmpty,
            "공백 이름으로 호출 시 children은 변경되지 않아야 한다 — 정책: 빈 이름 무시"
        )
        XCTAssertFalse(
            store.hasContent,
            "공백 이름 호출 후 hasContent는 여전히 false여야 한다"
        )
        XCTAssertNil(
            store.selectedChild,
            "공백 이름 호출 후 selectedChild는 nil이어야 한다"
        )
    }

    /// completeBabyOnboarding("", ...) → 완전히 빈 문자열 → children 변화 없음
    func test_completeBabyOnboarding_emptyString_doesNotAddChild() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: "", birthDate: d("2025-03-15"), gender: nil)

        XCTAssertTrue(
            store.children.isEmpty,
            "빈 문자열 이름으로 호출 시 children은 변경되지 않아야 한다"
        )
    }

    /// 탭·개행 등 whitespace 조합도 빈 이름으로 처리되어야 한다
    func test_completeBabyOnboarding_tabNewlineName_doesNotAddChild() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: "\t\n  ", birthDate: d("2025-03-15"), gender: nil)

        XCTAssertTrue(
            store.children.isEmpty,
            "탭·개행 등 whitespace만 포함한 이름도 빈 이름으로 처리되어야 한다"
        )
    }

    // MARK: - 4. completeBabyOnboarding — 두 번 호출 (selectedChild 정책)

    /// 두 번 호출 → children 2개, selectedChild는 마지막 추가된 child (정책 가정)
    func test_completeBabyOnboarding_calledTwice_twoChildren_selectedChildIsLatest() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: "첫째", birthDate: d("2023-01-10"), gender: .girl)
        store.completeBabyOnboarding(name: "둘째", birthDate: d("2025-05-20"), gender: .boy)

        XCTAssertEqual(
            store.children.count, 2,
            "두 번 호출 후 children 수는 2여야 한다"
        )
        XCTAssertTrue(
            store.children.contains(where: { $0.name == "첫째" }),
            "첫 번째 child '첫째'가 존재해야 한다"
        )
        XCTAssertTrue(
            store.children.contains(where: { $0.name == "둘째" }),
            "두 번째 child '둘째'가 존재해야 한다"
        )
        // 정책 가정: completeBabyOnboarding은 호출마다 selectedChildId를 새 child.id로 갱신
        XCTAssertEqual(
            store.selectedChild?.name, "둘째",
            "두 번 호출 후 selectedChild는 가장 마지막에 추가된 '둘째'여야 한다 — 정책 가정"
        )
    }

    /// 빈 이름 호출 + 유효 이름 호출 혼합 → children 1개만 추가
    func test_completeBabyOnboarding_mixedEmptyAndValid_onlyValidAdded() {
        let store = makeEmptyStore()

        store.completeBabyOnboarding(name: "   ", birthDate: d("2025-01-01"), gender: nil)
        store.completeBabyOnboarding(name: "서준", birthDate: d("2025-06-01"), gender: .boy)

        XCTAssertEqual(
            store.children.count, 1,
            "공백 이름은 무시되고 유효한 이름만 추가되어야 한다"
        )
        XCTAssertEqual(
            store.selectedChild?.name, "서준",
            "selectedChild는 유효하게 추가된 '서준'이어야 한다"
        )
    }

    // MARK: - 5. startPregnancy — activePregnancy

    /// startPregnancy(lmp:edd:nickname:) → activePregnancy.nickname=="콩", status==.active, hasContent=true
    func test_startPregnancy_addsActivePregnancy_withNickname() {
        let store = makeEmptyStore()
        let lmp = d("2025-09-01")
        let edd = d("2026-06-08")

        store.startPregnancy(lmp: lmp, edd: edd, nickname: "콩")

        XCTAssertEqual(
            store.pregnancies.count, 1,
            "startPregnancy 후 pregnancies에 정확히 1개가 추가되어야 한다"
        )
        XCTAssertEqual(
            store.pregnancies.first?.status, .active,
            "추가된 pregnancy.status는 .active여야 한다"
        )
        XCTAssertEqual(
            store.pregnancies.first?.nickname, "콩",
            "추가된 pregnancy.nickname은 '콩'이어야 한다"
        )
        XCTAssertEqual(
            store.pregnancies.first?.lmpDate, lmp,
            "lmpDate가 올바르게 저장되어야 한다"
        )
        XCTAssertEqual(
            store.pregnancies.first?.eddDate, edd,
            "eddDate가 올바르게 저장되어야 한다"
        )
        XCTAssertEqual(
            store.activePregnancy?.nickname, "콩",
            "activePregnancy.nickname은 '콩'이어야 한다"
        )
        XCTAssertEqual(
            store.activePregnancy?.status, .active,
            "activePregnancy.status는 .active여야 한다"
        )
        XCTAssertTrue(
            store.hasContent,
            "pregnancy 추가 후 hasContent는 true여야 한다"
        )
    }

    /// startPregnancy에 lmp, edd, nickname 모두 nil로 호출해도 추가되어야 한다
    func test_startPregnancy_allNilParams_addsActivePregnancy() {
        let store = makeEmptyStore()

        store.startPregnancy(lmp: nil, edd: nil, nickname: nil)

        XCTAssertEqual(
            store.pregnancies.count, 1,
            "모든 파라미터가 nil이어도 pregnancy가 추가되어야 한다"
        )
        XCTAssertEqual(
            store.pregnancies.first?.status, .active,
            "추가된 pregnancy.status는 .active여야 한다"
        )
        XCTAssertNil(
            store.pregnancies.first?.nickname,
            "nickname이 nil로 저장되어야 한다"
        )
        XCTAssertNotNil(
            store.activePregnancy,
            "activePregnancy는 nil이 아니어야 한다"
        )
    }

    // MARK: - 6. activePregnancy — 복수 pregnancy 중 첫 번째 .active

    /// pregnancies 중 .delivered 다음에 .active가 있을 때 activePregnancy는 .active인 첫 항목
    func test_activePregnancy_returnsFirstActiveAmongMultiple() {
        let deliveredPreg = Pregnancy(
            id: UUID(),
            lmpDate: d("2023-01-01"),
            fetusCount: 1,
            nickname: "첫째태아",
            status: .delivered
        )
        let activePreg = Pregnancy(
            id: UUID(),
            lmpDate: d("2025-01-01"),
            fetusCount: 1,
            nickname: "둘째태아",
            status: .active
        )
        let store = AppStore(
            pregnancies: [deliveredPreg, activePreg],
            children: [],
            bus: EventBus(),
            persistence: nil
        )

        XCTAssertEqual(
            store.activePregnancy?.id, activePreg.id,
            "activePregnancy는 status==.active인 첫 번째 항목이어야 한다"
        )
        XCTAssertEqual(
            store.activePregnancy?.nickname, "둘째태아",
            "activePregnancy.nickname은 '둘째태아'여야 한다"
        )
    }

    /// 모든 pregnancy가 .delivered이면 activePregnancy는 nil
    func test_activePregnancy_allDelivered_returnsNil() {
        let p1 = Pregnancy(id: UUID(), fetusCount: 1, status: .delivered)
        let p2 = Pregnancy(id: UUID(), fetusCount: 1, status: .delivered)
        let store = AppStore(
            pregnancies: [p1, p2],
            children: [],
            bus: EventBus(),
            persistence: nil
        )

        XCTAssertNil(
            store.activePregnancy,
            "모든 pregnancy가 .delivered이면 activePregnancy는 nil이어야 한다"
        )
    }

    // MARK: - 7. selectedChild — selectedChildId 우선, 없으면 children.first

    /// children이 있고 selectedChildId가 설정되지 않은 경우 → selectedChild는 children.first
    func test_selectedChild_noSelectedChildId_returnsChildrenFirst() {
        let child1 = Child(
            id: UUID(),
            name: "첫째",
            birthDate: d("2023-05-01"),
            gender: .girl
        )
        let child2 = Child(
            id: UUID(),
            name: "둘째",
            birthDate: d("2025-01-01"),
            gender: .boy
        )
        let store = AppStore(
            pregnancies: [],
            children: [child1, child2],
            bus: EventBus(),
            persistence: nil
        )

        // selectedChildId를 명시적으로 설정하지 않은 상태
        XCTAssertEqual(
            store.selectedChild?.id, child1.id,
            "selectedChildId 미설정 시 selectedChild는 children.first여야 한다"
        )
    }

    // MARK: - 8. hasContent — children 또는 pregnancies 존재 시 true

    /// children만 있을 때 hasContent==true
    func test_hasContent_onlyChildren_returnsTrue() {
        let child = Child(id: UUID(), name: "아이", birthDate: d("2025-01-01"))
        let store = AppStore(
            pregnancies: [],
            children: [child],
            bus: EventBus(),
            persistence: nil
        )

        XCTAssertTrue(store.hasContent,
            "children이 있으면 hasContent는 true여야 한다")
    }

    /// pregnancies만 있을 때 hasContent==true
    func test_hasContent_onlyPregnancies_returnsTrue() {
        let preg = Pregnancy(id: UUID(), fetusCount: 1, status: .active)
        let store = AppStore(
            pregnancies: [preg],
            children: [],
            bus: EventBus(),
            persistence: nil
        )

        XCTAssertTrue(store.hasContent,
            "pregnancies가 있으면 hasContent는 true여야 한다")
    }

    /// children도 pregnancies도 없을 때 hasContent==false
    func test_hasContent_bothEmpty_returnsFalse() {
        let store = makeEmptyStore()

        XCTAssertFalse(store.hasContent,
            "children과 pregnancies 모두 없으면 hasContent는 false여야 한다")
    }

    // MARK: - 9. 영속화 연계: completeBabyOnboarding 후 snapshot → 새 store restore → child 유지

    /// completeBabyOnboarding 후 LocalPersistence에 수동 저장 → 새 store에서 복원 → child 유지
    func test_persistence_afterCompleteBabyOnboarding_childSurvivesRestore() throws {
        let persistence = LocalPersistence(url: tempURL)
        let store = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        store.completeBabyOnboarding(name: "지호", birthDate: d("2025-03-15"), gender: .boy)

        // 자동 debounce를 우회하여 즉시 수동 저장
        let snap = store.snapshot()
        try persistence.save(snap)

        // 새 store — 동일 persistence로 init 시 자동 복원 기대
        let restoredStore = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        XCTAssertEqual(
            restoredStore.children.count, 1,
            "복원된 store에 child가 1개 있어야 한다"
        )
        XCTAssertEqual(
            restoredStore.children.first?.name, "지호",
            "복원된 child.name은 '지호'여야 한다"
        )
        XCTAssertEqual(
            restoredStore.children.first?.gender, .boy,
            "복원된 child.gender는 .boy여야 한다"
        )
        XCTAssertTrue(
            restoredStore.hasContent,
            "복원 후 hasContent는 true여야 한다"
        )
    }

    /// startPregnancy 후 snapshot 저장 → 새 store 복원 → pregnancy 유지
    func test_persistence_afterStartPregnancy_pregnancySurvivesRestore() throws {
        let persistence = LocalPersistence(url: tempURL)
        let store = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        store.startPregnancy(lmp: d("2025-09-01"), edd: d("2026-06-08"), nickname: "콩")

        let snap = store.snapshot()
        try persistence.save(snap)

        let restoredStore = AppStore(
            pregnancies: [],
            children: [],
            bus: EventBus(),
            persistence: persistence
        )

        XCTAssertEqual(
            restoredStore.pregnancies.count, 1,
            "복원된 store에 pregnancy가 1개 있어야 한다"
        )
        XCTAssertEqual(
            restoredStore.pregnancies.first?.nickname, "콩",
            "복원된 pregnancy.nickname은 '콩'이어야 한다"
        )
        XCTAssertEqual(
            restoredStore.pregnancies.first?.status, .active,
            "복원된 pregnancy.status는 .active여야 한다"
        )
        XCTAssertNotNil(
            restoredStore.activePregnancy,
            "복원 후 activePregnancy는 nil이 아니어야 한다"
        )
    }
}
