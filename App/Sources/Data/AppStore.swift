import Foundation
import Combine

// MARK: - AppStore

/// 임신 → 출산 전환을 원자적으로 관리하는 인메모리 스토어.
///
/// - Note: `persistence` 인자를 주입하면 init 시 저장된 상태를 자동 복원하고,
///   `enableAutoPersist()`를 호출하면 상태 변경 시 0.5s debounce 후 자동 저장된다.
final class AppStore: ObservableObject {

    // MARK: Published State

    @Published private(set) var pregnancies: [Pregnancy]
    @Published private(set) var children: [Child]
    @Published var selectedChildId: UUID?

    // MARK: - Private

    private let bus: EventBus
    private let persistence: LocalPersistence?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    /// - Parameters:
    ///   - pregnancies: 초기 임신 목록 (기본값 `[]`)
    ///   - children:    초기 아이 목록 (기본값 `[]`)
    ///   - bus:         이벤트 버스 (기본값 `.shared`)
    ///   - persistence: 로컬 영속화 헬퍼. 주입 시 init에서 저장 파일을 읽어 상태를 복원한다.
    ///                  nil이면 영속화를 사용하지 않는다 (기존 동작 유지).
    init(
        pregnancies: [Pregnancy] = [],
        children: [Child] = [],
        bus: EventBus = .shared,
        persistence: LocalPersistence? = nil
    ) {
        self.pregnancies = pregnancies
        self.children = children
        self.bus = bus
        self.persistence = persistence

        // persistence가 주입된 경우 저장된 상태로 복원 (파일 없으면 무시)
        if let persistence = persistence,
           let saved = try? persistence.load() {
            self.pregnancies = saved.pregnancies
            self.children = saved.children
        }
    }

    // MARK: - Auto Persist

    /// 상태 변경을 감지해 0.5s debounce 후 자동으로 영속화한다.
    ///
    /// `persistence`가 nil이면 아무 동작도 하지 않는다.
    /// 구독은 내부 `cancellables`에 보관되므로 store 생존 중 유지된다.
    func enableAutoPersist() {
        guard persistence != nil else { return }

        // pregnancies와 children 두 Publisher를 combineLatest로 묶어
        // 어느 한 쪽이 바뀌어도 저장이 트리거되도록 한다.
        $pregnancies
            .combineLatest($children)
            .dropFirst()                          // init 시 초기값 방출 무시
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self else { return }
                try? self.persistence?.save(self.snapshot())
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence Convenience

    /// 현재 인메모리 상태를 스냅샷으로 반환한다.
    func snapshot() -> PersistableState {
        PersistableState(pregnancies: pregnancies, children: children)
    }

    /// 저장된 스냅샷으로 상태를 복원한다.
    func restore(_ state: PersistableState) {
        pregnancies = state.pregnancies
        children = state.children
    }

    // MARK: - 선택 아이 / 온보딩

    /// 현재 선택된 아이 (selectedChildId 우선, 없으면 첫 아이).
    var selectedChild: Child? {
        if let id = selectedChildId, let c = children.first(where: { $0.id == id }) { return c }
        return children.first
    }

    /// 진행 중인 임신 (status == .active 첫 항목).
    var activePregnancy: Pregnancy? {
        pregnancies.first(where: { $0.status == .active })
    }

    /// 아이 또는 임신 기록 존재 여부 (온보딩 게이트).
    var hasContent: Bool { !children.isEmpty || !pregnancies.isEmpty }

    /// 출산 온보딩 — 아이 생성·추가·선택. 빈 이름은 무시.
    func completeBabyOnboarding(name: String, birthDate: Date, gender: Gender?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let child = Child(id: UUID(), name: trimmed, birthDate: birthDate, gender: gender,
                          profileImageRef: nil, caregiverRole: nil, pregnancyId: nil)
        children.append(child)
        selectedChildId = child.id
    }

    /// 임신 온보딩 — active 임신 생성·추가.
    func startPregnancy(lmp: Date?, edd: Date?, nickname: String?) {
        let preg = Pregnancy(id: UUID(), lmpDate: lmp, eddDate: edd, fetusCount: 1,
                             nickname: nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
                             clinic: nil, status: .active)
        pregnancies.append(preg)
    }

    // MARK: - Atomic Birth Transition

    /// 임신 → 출산 전환을 원자적으로 수행한다.
    ///
    /// 성공 조건이 모두 충족될 때만 상태를 변경한다.
    /// 검증 실패 또는 Child 생성 실패 시 pregnancies·children 어느 쪽도 변경하지 않는다.
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
            bus.publish(.recordSaved(childId: child.id))
            return .success(child)
        }
    }
}
