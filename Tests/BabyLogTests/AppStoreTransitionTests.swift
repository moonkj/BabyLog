// AppStoreTransitionTests.swift
// BabyLogTests
//
// QA Teammate 3 작성 — AppStore.commitBirthTransition 원자성 계약 기반 단위 테스트
//
// 핵심 검증: 실패 경로에서 pregnancies/children 어느 쪽도 변경되지 않아야 한다(원자성).
// 성공 경로에서는 pregnancy.status == .delivered 이고 children에 연결된 child 1개만 추가된다.
//
// TODO (추가 검증 권장):
// 1. 쌍둥이 다중 Child: fetusCount=2 임신에 commitBirthTransition을 2회 호출할 때의 계약 정의 필요
//    → 현재 계약은 1회 성공 후 pregnancy.status=.delivered → 2번째 호출은 .notActive 반환
//      ("쌍둥이 동시 전환" API가 별도로 필요한지 코더와 합의 필요)
// 2. 동시성: 두 스레드가 동시에 commitBirthTransition을 호출할 때 children이 2개 추가되지 않는지 확인
//    → AppStore가 MainActor isolation 또는 별도 직렬화를 제공하는지 코더와 합의 필요
// 3. 영속화 후 복구: CoreData/CloudKit 도입 이후 커밋 도중 앱 종료 시 half-committed 상태가
//    복구되는지 확인 — 현재는 인메모리이므로 재시작 시 초기화되어 문제 없으나
//    영속화 레이어 추가 후 반드시 재검증 필요

import XCTest
import Combine
@testable import BabyLog

// MARK: - Tests

final class AppStoreTransitionTests: XCTestCase {

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

    /// status=.active인 기본 임신 픽스처
    private func makeActivePregnancy(
        lmpDate: Date? = nil,
        status: PregnancyStatus = .active
    ) -> Pregnancy {
        Pregnancy(
            id: UUID(),
            lmpDate: lmpDate,
            fetusCount: 1,
            nickname: "테스트 태아",
            status: status
        )
    }

    /// 유효한 BirthTransitionInput 픽스처
    private func makeValidInput(
        name: String = "김아이",
        birthDate: Date? = nil,
        gender: Gender? = .girl
    ) -> BirthTransitionInput {
        BirthTransitionInput(
            childName: name,
            birthDate: birthDate ?? d("2025-09-01"),
            gender: gender
        )
    }

    // MARK: - 성공: 원자적 상태 전환

    /// active → commit → .success: pregnancy.status==.delivered, children에 child 1개(pregnancyId 연결)
    func test_commitBirthTransition_activePregnancy_validInput_succeeds() {
        let pregnancy = makeActivePregnancy(lmpDate: d("2024-12-01"))
        let store = AppStore(pregnancies: [pregnancy], children: [])
        let input = makeValidInput()

        let result = store.commitBirthTransition(pregnancyId: pregnancy.id, input: input)

        // 반환값 검증
        guard case .success(let child) = result else {
            XCTFail("유효한 active 임신 + 유효 입력은 .success를 반환해야 한다; 실제: \(result)")
            return
        }

        // pregnancy status 검증
        let updatedPregnancy = store.pregnancies.first(where: { $0.id == pregnancy.id })
        XCTAssertEqual(updatedPregnancy?.status, .delivered,
            "성공 후 pregnancy.status는 .delivered여야 한다")

        // children 검증
        XCTAssertEqual(store.children.count, 1,
            "성공 후 children에 정확히 1개의 child가 추가되어야 한다")
        XCTAssertEqual(store.children.first?.pregnancyId, pregnancy.id,
            "추가된 child.pregnancyId는 원본 pregnancy.id와 일치해야 한다")
        XCTAssertEqual(child.pregnancyId, pregnancy.id,
            "반환된 child.pregnancyId도 pregnancy.id와 일치해야 한다")
        XCTAssertEqual(child.name, input.childName.trimmingCharacters(in: .whitespacesAndNewlines),
            "child.name은 트리밍된 입력값과 일치해야 한다")
    }

    /// 성공 후 pregnancies 배열 크기는 그대로이어야 한다 (삭제 없이 status만 교체)
    func test_commitBirthTransition_success_pregnanciesCountUnchanged() {
        let pregnancy = makeActivePregnancy()
        let store = AppStore(pregnancies: [pregnancy], children: [])

        store.commitBirthTransition(pregnancyId: pregnancy.id, input: makeValidInput())

        XCTAssertEqual(store.pregnancies.count, 1,
            "성공 후 pregnancies 배열 크기는 변경되지 않아야 한다")
    }

    // MARK: - 실패: .loss 상태 → 원자성(완전 무변경)

    /// pregnancy.status==.loss → .notActive 반환, pregnancies/children 완전 무변경 (원자성 핵심)
    func test_commitBirthTransition_lossStatus_returnsNotActive_storeUnchanged() {
        let lossPregnancy = makeActivePregnancy(status: .loss)
        let store = AppStore(pregnancies: [lossPregnancy], children: [])
        let input = makeValidInput()

        let result = store.commitBirthTransition(pregnancyId: lossPregnancy.id, input: input)

        // 에러 타입 검증
        guard case .failure(let error) = result else {
            XCTFail("loss 상태는 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .notActive,
            "loss 상태에서의 에러는 .notActive여야 한다")

        // 원자성: pregnancies 무변경
        let unchangedPregnancy = store.pregnancies.first(where: { $0.id == lossPregnancy.id })
        XCTAssertEqual(unchangedPregnancy?.status, .loss,
            "실패 시 pregnancy.status는 원래 .loss 그대로여야 한다 — 원자성 보장")

        // 원자성: children 무변경
        XCTAssertTrue(store.children.isEmpty,
            "실패 시 children은 비어있어야 한다 — 원자성 보장")
    }

    // MARK: - 실패: 존재하지 않는 ID → 원자성

    /// 존재하지 않는 pregnancyId → .notActive, pregnancies/children 완전 무변경
    func test_commitBirthTransition_unknownId_returnsNotActive_storeUnchanged() {
        let pregnancy = makeActivePregnancy()
        let store = AppStore(pregnancies: [pregnancy], children: [])
        let unknownId = UUID() // store에 없는 ID

        let result = store.commitBirthTransition(pregnancyId: unknownId, input: makeValidInput())

        guard case .failure(let error) = result else {
            XCTFail("존재하지 않는 ID는 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .notActive,
            "존재하지 않는 pregnancyId 에러는 .notActive여야 한다")

        // 원자성: 기존 pregnancy는 그대로
        XCTAssertEqual(store.pregnancies.count, 1)
        XCTAssertEqual(store.pregnancies.first?.status, .active,
            "기존 pregnancy의 status가 변경되지 않아야 한다")

        // 원자성: children 비어있음
        XCTAssertTrue(store.children.isEmpty,
            "실패 시 children은 비어있어야 한다 — 원자성 보장")
    }

    // MARK: - 실패: emptyName → 원자성

    /// childName이 공백(" ") → .emptyName, pregnancies/children 완전 무변경
    func test_commitBirthTransition_whitespaceChildName_returnsEmptyName_storeUnchanged() {
        let pregnancy = makeActivePregnancy()
        let store = AppStore(pregnancies: [pregnancy], children: [])
        let input = BirthTransitionInput(childName: " ", birthDate: d("2025-09-01"), gender: nil)

        let result = store.commitBirthTransition(pregnancyId: pregnancy.id, input: input)

        guard case .failure(let error) = result else {
            XCTFail("공백 이름은 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .emptyName,
            "공백 이름 에러는 .emptyName이어야 한다")

        // 원자성: pregnancies 무변경
        XCTAssertEqual(store.pregnancies.first?.status, .active,
            "실패 시 pregnancy.status가 변경되지 않아야 한다 — 원자성 보장")

        // 원자성: children 비어있음
        XCTAssertTrue(store.children.isEmpty,
            "실패 시 children은 비어있어야 한다 — 원자성 보장")
    }

    /// childName이 완전히 빈 문자열("") → .emptyName, 무변경
    func test_commitBirthTransition_emptyChildName_returnsEmptyName_storeUnchanged() {
        let pregnancy = makeActivePregnancy()
        let store = AppStore(pregnancies: [pregnancy], children: [])
        let input = BirthTransitionInput(childName: "", birthDate: d("2025-09-01"), gender: nil)

        let result = store.commitBirthTransition(pregnancyId: pregnancy.id, input: input)

        guard case .failure(let error) = result else {
            XCTFail("빈 이름은 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .emptyName)
        XCTAssertEqual(store.pregnancies.first?.status, .active)
        XCTAssertTrue(store.children.isEmpty)
    }

    // MARK: - 실패: delivered 상태 → 원자성

    /// pregnancy.status==.delivered → .notActive, 무변경 (이중 전환 방지)
    func test_commitBirthTransition_deliveredStatus_returnsNotActive_storeUnchanged() {
        let deliveredPregnancy = makeActivePregnancy(status: .delivered)
        let store = AppStore(pregnancies: [deliveredPregnancy], children: [])

        let result = store.commitBirthTransition(pregnancyId: deliveredPregnancy.id, input: makeValidInput())

        guard case .failure(let error) = result else {
            XCTFail("delivered 상태는 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .notActive)
        XCTAssertEqual(store.pregnancies.first?.status, .delivered,
            "이미 delivered인 pregnancy의 status가 변경되지 않아야 한다")
        XCTAssertTrue(store.children.isEmpty)
    }

    // MARK: - 실패: birthDateBeforeLMP → 원자성

    /// lmpDate=2025-01-01 + birthDate=2024-12-01 → .birthDateBeforeLMP, 무변경
    func test_commitBirthTransition_birthDateBeforeLMP_returnsError_storeUnchanged() {
        let pregnancy = makeActivePregnancy(lmpDate: d("2025-01-01"))
        let store = AppStore(pregnancies: [pregnancy], children: [])
        let input = BirthTransitionInput(
            childName: "아이",
            birthDate: d("2024-12-01"),
            gender: nil
        )

        let result = store.commitBirthTransition(pregnancyId: pregnancy.id, input: input)

        guard case .failure(let error) = result else {
            XCTFail("출생일이 LMP 이전이면 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .birthDateBeforeLMP)
        XCTAssertEqual(store.pregnancies.first?.status, .active,
            "실패 시 pregnancy.status가 변경되지 않아야 한다 — 원자성 보장")
        XCTAssertTrue(store.children.isEmpty,
            "실패 시 children은 비어있어야 한다 — 원자성 보장")
    }

    // MARK: - 복수 pregnancy 환경에서 격리성

    /// 복수 pregnancy가 있을 때, 성공 전환이 대상 pregnancy만 변경하고 나머지는 영향받지 않음
    func test_commitBirthTransition_multiplePregnancies_onlyTargetModified() {
        let target = makeActivePregnancy()
        let bystander = makeActivePregnancy()
        let store = AppStore(pregnancies: [target, bystander], children: [])

        let result = store.commitBirthTransition(pregnancyId: target.id, input: makeValidInput())

        XCTAssertEqual(store.pregnancies.count, 2,
            "pregnancy 수는 그대로여야 한다")

        guard case .success = result else {
            XCTFail("유효한 전환은 .success여야 한다")
            return
        }

        let updatedTarget = store.pregnancies.first(where: { $0.id == target.id })
        let updatedBystander = store.pregnancies.first(where: { $0.id == bystander.id })

        XCTAssertEqual(updatedTarget?.status, .delivered,
            "대상 pregnancy만 .delivered로 변경되어야 한다")
        XCTAssertEqual(updatedBystander?.status, .active,
            "다른 pregnancy의 status는 변경되지 않아야 한다")
    }

    // MARK: - 빈 store에서 실패

    /// pregnancies가 빈 배열인 store → 임의 id로 commit → .notActive, 무변경
    func test_commitBirthTransition_emptyStore_returnsNotActive() {
        let store = AppStore(pregnancies: [], children: [])

        let result = store.commitBirthTransition(pregnancyId: UUID(), input: makeValidInput())

        guard case .failure(let error) = result else {
            XCTFail("빈 store는 .failure를 반환해야 한다")
            return
        }
        XCTAssertEqual(error, .notActive)
        XCTAssertTrue(store.pregnancies.isEmpty)
        XCTAssertTrue(store.children.isEmpty)
    }
}
