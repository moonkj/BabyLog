import Foundation
import Combine

// MARK: - AppStore

/// 임신 → 출산 전환을 원자적으로 관리하는 인메모리 스토어.
///
/// - Note: CoreData + CloudKit 영속화는 후속 인프라 단계에서 추가 예정.
///   현재는 런타임 메모리 전용이므로 앱 재시작 시 초기화된다.
final class AppStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var pregnancies: [Pregnancy]
    @Published private(set) var children: [Child]

    // MARK: Init

    init(pregnancies: [Pregnancy] = [], children: [Child] = []) {
        self.pregnancies = pregnancies
        self.children = children
    }

    // MARK: - Atomic Birth Transition

    /// 임신 → 출산 전환을 원자적으로 수행한다.
    ///
    /// 성공 조건이 모두 충족될 때만 상태를 변경한다.
    /// 검증 실패 또는 Child 생성 실패 시 pregnancies·children 어느 쪽도 변경하지 않는다.
    ///
    /// 성공 흐름:
    /// 1. `pregnancyId`로 pregnancy 탐색 — 없으면 `.failure(.notActive)` 반환(무변경).
    /// 2. `PregnancyTransition.makeChild(from:input:)` 호출 — `.failure`면 그대로 반환(무변경).
    /// 3. 위 모두 통과 시, pregnancy.status를 `.delivered`로 교체 + child를 children에 추가
    ///    + `EventBus.shared.publish(.recordSaved(childId:))` 발행 후 `.success(child)` 반환.
    ///
    /// - Parameters:
    ///   - pregnancyId: 전환 대상 임신 레코드의 ID
    ///   - input: 출산 정보 (아이 이름, 출생일, 성별)
    /// - Returns: 성공 시 생성된 `Child`, 실패 시 `BirthTransitionError`
    @discardableResult
    func commitBirthTransition(
        pregnancyId: UUID,
        input: BirthTransitionInput
    ) -> Result<Child, BirthTransitionError> {

        // 1. pregnancy 탐색 — 없으면 즉시 실패(무변경)
        guard let index = pregnancies.firstIndex(where: { $0.id == pregnancyId }) else {
            return .failure(.notActive)
        }

        let pregnancy = pregnancies[index]

        // 2. 검증 + Child 생성 → 3. 원자적 반영 (실패 시 두 배열 모두 무변경)
        switch PregnancyTransition.makeChild(from: pregnancy, input: input) {
        case .failure(let error):
            return .failure(error)          // 변경 없음
        case .success(let child):
            var updatedPregnancy = pregnancy
            updatedPregnancy.status = .delivered
            pregnancies[index] = updatedPregnancy
            children.append(child)
            EventBus.shared.publish(.recordSaved(childId: child.id))
            return .success(child)
        }
    }
}
