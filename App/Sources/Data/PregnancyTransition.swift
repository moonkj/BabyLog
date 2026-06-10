import Foundation

// MARK: - Input

struct BirthTransitionInput {
    let childName: String
    let birthDate: Date
    let gender: Gender?
}

// MARK: - Error

enum BirthTransitionError: Error, Equatable {
    case notActive
    case emptyName
    case birthDateBeforeLMP
}

// MARK: - Transition Logic

enum PregnancyTransition {

    /// 검증 후 Child 생성(태명 → 이름은 input.childName 사용, pregnancyId 연결).
    /// 원자성은 호출측 책임. 여기선 검증 + 생성만 수행.
    static func makeChild(
        from pregnancy: Pregnancy,
        input: BirthTransitionInput
    ) -> Result<Child, BirthTransitionError> {

        // 1. status 검증
        guard pregnancy.status == .active else {
            return .failure(.notActive)
        }

        // 2. 이름 검증 (공백·개행·탭 trim 후 빈값 체크) — QA 교차레이어 발견 반영
        let trimmedName = input.childName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .failure(.emptyName)
        }

        // 3. 출생일 vs LMP 검증
        if let lmp = pregnancy.lmpDate {
            let cal = Calendar(identifier: .gregorian)
            let lmpDay  = cal.startOfDay(for: lmp)
            let birthDay = cal.startOfDay(for: input.birthDate)
            if birthDay < lmpDay {
                return .failure(.birthDateBeforeLMP)
            }
        }

        // 4. Child 생성
        let child = Child(
            name: trimmedName,
            birthDate: input.birthDate,
            gender: input.gender,
            pregnancyId: pregnancy.id
        )

        return .success(child)
    }
}
