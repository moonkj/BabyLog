// PregnancyTransitionTests.swift
// BabyLogTests
//
// QA Teammate 3 작성 — PregnancyTransition.makeChild API 계약 기반 단위 테스트
//
// TODO (리뷰어 관점 — 누락/위험 케이스):
// 1. 쌍둥이(fetusCount=2): makeChild 1회 호출 시 단일 Child만 반환 → 쌍둥이용 복수 Child 생성 API 필요 여부 검토
// 2. .paused 상태 → .notActive 처리 여부: 스펙에 명시 없음, 코더와 합의 필요
// 3. birthDate == edd 경계: 정상 성공인지 추가 검증 케이스 추가 권장
// 4. childName 길이 상한: 최대 문자 수 제한(예: 50자) 정책 미정 — 초과 시 에러 반환 여부 확인
// 5. gender=nil vs .unspecified: makeChild가 nil 그대로 저장하는지 .unspecified로 변환하는지 정책 확인
// 6. 시간대 경계: birthDate가 UTC 자정 vs 현지 자정일 때 lmp 비교 결과 달라지는지 확인
// 7. lmpDate=nil인 pregnancy + 유효 birthDate → birthDateBeforeLMP 에러 안 뜨는지 확인
// 8. 동시성: makeChild가 pure function(참조 캡처 없음)인지, Actor isolation 필요 여부 확인
// 9. Child.id 유일성: 연속 호출 시 매번 새 UUID가 부여되는지 확인
// 10. pregnancyId 승계: child.pregnancyId == pregnancy.id 를 타입 수준에서 보장하는지 검토

import XCTest
@testable import BabyLog

final class PregnancyTransitionTests: XCTestCase {

    // MARK: - Helpers

    /// "yyyy-MM-dd" 문자열을 현지 그레고리안 자정으로 변환
    func d(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 기본 활성 임신 픽스처
    func makeActivePregnancy(
        lmpDate: Date? = nil,
        eddDate: Date? = nil,
        fetusCount: Int = 1,
        status: PregnancyStatus = .active
    ) -> Pregnancy {
        Pregnancy(
            id: UUID(),
            lmpDate: lmpDate,
            eddDate: eddDate,
            fetusCount: fetusCount,
            nickname: "테스트 태아",
            clinic: nil,
            status: status
        )
    }

    // MARK: - 성공 케이스

    /// status=.active + 유효 입력 → success, child.pregnancyId == pregnancy.id, child.name == input
    func test_makeChild_activePregnancy_validInput_succeeds() throws {
        let pregnancy = makeActivePregnancy(
            lmpDate: d("2024-12-01"),
            status: .active
        )
        let input = BirthTransitionInput(
            childName: "김아이",
            birthDate: d("2025-09-01"),
            gender: .girl
        )

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .success(let child):
            XCTAssertEqual(child.pregnancyId, pregnancy.id, "pregnancyId가 pregnancy.id와 일치해야 한다")
            XCTAssertEqual(child.name, input.childName, "child.name이 입력값과 일치해야 한다")
            XCTAssertEqual(child.birthDate, input.birthDate)
            XCTAssertEqual(child.gender, input.gender)
        case .failure(let error):
            XCTFail("성공이어야 하는데 에러 반환: \(error)")
        }
    }

    /// gender=nil 입력도 성공해야 한다
    func test_makeChild_genderNil_succeeds() {
        let pregnancy = makeActivePregnancy(status: .active)
        let input = BirthTransitionInput(
            childName: "이아이",
            birthDate: d("2025-09-01"),
            gender: nil
        )

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        if case .failure(let error) = result {
            XCTFail("gender=nil은 에러가 아니어야 함: \(error)")
        }
    }

    // MARK: - .notActive 에러 케이스

    /// status=.delivered → .notActive
    func test_makeChild_delivered_returnsNotActive() {
        let pregnancy = makeActivePregnancy(status: .delivered)
        let input = BirthTransitionInput(childName: "아이", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.notActive):
            break // 예상된 에러
        default:
            XCTFail("delivered 상태는 .notActive를 반환해야 함, 실제: \(result)")
        }
    }

    /// status=.loss → .notActive  (상실 후 전환 차단 — 민감 영역)
    func test_makeChild_loss_returnsNotActive() {
        // 유산/사산 이후 아이 승계를 차단하는 것은 사용자 데이터 무결성 및
        // 정서적 안전을 위한 핵심 정책이다. 이 테스트는 반드시 통과해야 한다.
        let pregnancy = makeActivePregnancy(status: .loss)
        let input = BirthTransitionInput(childName: "아이", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.notActive):
            break // 예상된 에러
        default:
            XCTFail("loss 상태는 .notActive를 반환해야 함, 실제: \(result)")
        }
    }

    /// status=.paused → .notActive 여부 (TODO: 정책 확인 필요 — 현재는 .notActive 기대)
    func test_makeChild_paused_returnsNotActive() {
        let pregnancy = makeActivePregnancy(status: .paused)
        let input = BirthTransitionInput(childName: "아이", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.notActive):
            break
        case .success:
            // paused 정책이 active와 동일하게 허용된다면 이쪽도 허용될 수 있음.
            // 코더와 합의 후 expectation 수정 필요.
            XCTFail("paused 상태 처리 정책 미결 — 코더와 합의 후 이 assertion 업데이트 필요")
        default:
            XCTFail("paused 상태에서 예상치 못한 에러: \(result)")
        }
    }

    // MARK: - .emptyName 에러 케이스

    /// childName이 공백 문자열(" ") → .emptyName
    func test_makeChild_whitespaceChildName_returnsEmptyName() {
        let pregnancy = makeActivePregnancy(status: .active)
        let input = BirthTransitionInput(childName: " ", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.emptyName):
            break
        default:
            XCTFail("공백 이름은 .emptyName을 반환해야 함, 실제: \(result)")
        }
    }

    /// childName이 빈 문자열("") → .emptyName
    func test_makeChild_emptyChildName_returnsEmptyName() {
        let pregnancy = makeActivePregnancy(status: .active)
        let input = BirthTransitionInput(childName: "", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.emptyName):
            break
        default:
            XCTFail("빈 이름은 .emptyName을 반환해야 함, 실제: \(result)")
        }
    }

    /// childName이 탭·개행 등 공백류 → .emptyName
    func test_makeChild_tabAndNewlineChildName_returnsEmptyName() {
        let pregnancy = makeActivePregnancy(status: .active)
        let input = BirthTransitionInput(childName: "\t\n", birthDate: d("2025-09-01"), gender: nil)

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.emptyName):
            break
        default:
            XCTFail("공백류 이름은 .emptyName을 반환해야 함, 실제: \(result)")
        }
    }

    // MARK: - .birthDateBeforeLMP 에러 케이스

    /// lmpDate=2025-01-01, birthDate=2024-12-01 → .birthDateBeforeLMP
    func test_makeChild_birthDateBeforeLMP_returnsError() {
        let pregnancy = makeActivePregnancy(
            lmpDate: d("2025-01-01"),
            status: .active
        )
        let input = BirthTransitionInput(
            childName: "아이",
            birthDate: d("2024-12-01"),
            gender: nil
        )

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        switch result {
        case .failure(.birthDateBeforeLMP):
            break
        default:
            XCTFail("birthDate < lmpDate는 .birthDateBeforeLMP를 반환해야 함, 실제: \(result)")
        }
    }

    /// lmpDate == birthDate (경계값) → 어떤 결과인지 명시 (현재는 에러 아님으로 기대)
    func test_makeChild_birthDateEqualToLMP_boundary() {
        // birthDate == lmpDate는 생물학적으로 불가능하지만 에러 처리 정책 확인용
        // 코더 구현에서 strict < 인지 <= 인지에 따라 달라짐 — 합의 필요
        let lmp = d("2025-01-01")
        let pregnancy = makeActivePregnancy(lmpDate: lmp, status: .active)
        let input = BirthTransitionInput(
            childName: "아이",
            birthDate: lmp,
            gender: nil
        )

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        // 정책 미결: strict < 면 .success, <= 면 .birthDateBeforeLMP
        // 이 테스트는 정책 확정 전까지 코더와 협의 후 assertion 업데이트
        switch result {
        case .success:
            break // birthDate == lmpDate 허용 시
        case .failure(.birthDateBeforeLMP):
            break // birthDate == lmpDate 불허 시
        default:
            XCTFail("예상치 못한 결과: \(result)")
        }
    }

    /// lmpDate=nil인 경우 birthDateBeforeLMP 에러 안 뜨는지 확인
    func test_makeChild_noLMP_doesNotThrowBirthDateBeforeLMP() {
        let pregnancy = makeActivePregnancy(lmpDate: nil, status: .active)
        let input = BirthTransitionInput(
            childName: "아이",
            birthDate: d("2025-01-01"),
            gender: nil
        )

        let result = PregnancyTransition.makeChild(from: pregnancy, input: input)

        if case .failure(.birthDateBeforeLMP) = result {
            XCTFail("lmpDate=nil 이면 birthDateBeforeLMP 에러가 발생하지 않아야 함")
        }
    }

    // MARK: - pregnancyId 승계 추가 검증

    /// 연속 두 번 호출 시 child.id가 매번 다른 UUID인지 확인
    func test_makeChild_consecutiveCalls_uniqueChildIds() throws {
        let pregnancy = makeActivePregnancy(status: .active)
        let input = BirthTransitionInput(childName: "아이", birthDate: d("2025-09-01"), gender: nil)

        let r1 = PregnancyTransition.makeChild(from: pregnancy, input: input)
        let r2 = PregnancyTransition.makeChild(from: pregnancy, input: input)

        guard case .success(let c1) = r1, case .success(let c2) = r2 else {
            XCTFail("두 호출 모두 성공해야 함")
            return
        }

        XCTAssertNotEqual(c1.id, c2.id, "매 호출마다 새 UUID가 부여되어야 한다")
        XCTAssertEqual(c1.pregnancyId, pregnancy.id)
        XCTAssertEqual(c2.pregnancyId, pregnancy.id)
    }
}
