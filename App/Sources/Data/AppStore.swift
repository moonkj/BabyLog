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
    @Published private(set) var growthRecords: [GrowthRecord]
    @Published private(set) var diaryEntries: [DiaryEntry]
    @Published var selectedChildId: UUID?

    // MARK: - Private

    private let bus: EventBus
    private let persistence: LocalPersistence?
    private var cancellables = Set<AnyCancellable>()

    // MARK: Init

    /// - Parameters:
    ///   - pregnancies:   초기 임신 목록 (기본값 `[]`)
    ///   - children:      초기 아이 목록 (기본값 `[]`)
    ///   - growthRecords: 초기 성장 기록 목록 (기본값 `[]`)
    ///   - diaryEntries:  초기 다이어리 항목 목록 (기본값 `[]`)
    ///   - bus:           이벤트 버스 (기본값 `.shared`)
    ///   - persistence:   로컬 영속화 헬퍼. 주입 시 init에서 저장 파일을 읽어 상태를 복원한다.
    ///                    nil이면 영속화를 사용하지 않는다 (기존 동작 유지).
    init(
        pregnancies: [Pregnancy] = [],
        children: [Child] = [],
        growthRecords: [GrowthRecord] = [],
        diaryEntries: [DiaryEntry] = [],
        bus: EventBus = .shared,
        persistence: LocalPersistence? = nil
    ) {
        self.pregnancies = pregnancies
        self.children = children
        self.growthRecords = growthRecords
        self.diaryEntries = diaryEntries
        self.bus = bus
        self.persistence = persistence

        // persistence가 주입된 경우 저장된 상태로 복원 (파일 없으면 무시)
        if let persistence = persistence,
           let saved = try? persistence.load() {
            self.pregnancies    = saved.pregnancies
            self.children       = saved.children
            self.growthRecords  = saved.growthRecords
            self.diaryEntries   = saved.diaryEntries
        }
    }

    // MARK: - Auto Persist

    /// 상태 변경을 감지해 0.5s debounce 후 자동으로 영속화한다.
    ///
    /// `persistence`가 nil이면 아무 동작도 하지 않는다.
    /// 구독은 내부 `cancellables`에 보관되므로 store 생존 중 유지된다.
    func enableAutoPersist() {
        guard persistence != nil else { return }

        // pregnancies·children·growthRecords·diaryEntries 네 Publisher를 combineLatest로 묶어
        // 어느 한 쪽이 바뀌어도 저장이 트리거되도록 한다.
        $pregnancies
            .combineLatest($children, $growthRecords, $diaryEntries)
            .dropFirst()                          // init 시 초기값 방출 무시
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _, _, _, _ in
                guard let self else { return }
                try? self.persistence?.save(self.snapshot())
            }
            .store(in: &cancellables)
    }

    // MARK: - Persistence Convenience

    /// 현재 인메모리 상태를 스냅샷으로 반환한다.
    func snapshot() -> PersistableState {
        PersistableState(
            pregnancies:   pregnancies,
            children:      children,
            growthRecords: growthRecords,
            diaryEntries:  diaryEntries
        )
    }

    /// 저장된 스냅샷으로 상태를 복원한다.
    func restore(_ state: PersistableState) {
        pregnancies    = state.pregnancies
        children       = state.children
        growthRecords  = state.growthRecords
        diaryEntries   = state.diaryEntries
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

    /// 임신 상태 변경 (민감 영역 — 상실·일시중단 포함).
    /// `.loss` 전환 시 `pregnancyEndedInLoss` 이벤트를 발행해 권유 알림을 즉시 자동 차단한다.
    func updatePregnancyStatus(pregnancyId: UUID, to status: PregnancyStatus) {
        guard let idx = pregnancies.firstIndex(where: { $0.id == pregnancyId }) else { return }
        var updated = pregnancies[idx]
        updated.status = status
        pregnancies[idx] = updated
        if status == .loss {
            bus.publish(.pregnancyEndedInLoss(pregnancyId: pregnancyId))
        }
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

    // MARK: - 기록 CRUD

    /// 다이어리/사진 항목을 추가한다.
    ///
    /// - Parameters:
    ///   - childId:   대상 아이 ID
    ///   - content:   텍스트 내용 (옵션)
    ///   - milestone: 마일스톤 텍스트 (옵션)
    ///   - photoRef:  사진 참조 문자열. nil이 아니면 recordType = "photo", 아니면 "diary".
    func addDiaryEntry(
        childId: UUID,
        content: String?,
        milestone: String?,
        photoRef: String?
    ) {
        let entry = DiaryEntry(
            id: UUID(),
            childId: childId,
            date: Date(),
            recordType: photoRef != nil ? "photo" : "diary",
            content: content,
            milestone: milestone
        )
        diaryEntries.append(entry)
        bus.publish(.recordSaved(childId: childId))
    }

    /// 성장 기록을 추가한다.
    ///
    /// - Parameters:
    ///   - childId:              대상 아이 ID
    ///   - heightCm:             신장(cm) (옵션)
    ///   - weightKg:             체중(kg) (옵션)
    ///   - headCircumferenceCm:  두위(cm) (옵션)
    func addGrowthRecord(
        childId: UUID,
        heightCm: Double?,
        weightKg: Double?,
        headCircumferenceCm: Double?
    ) {
        let record = GrowthRecord(
            id: UUID(),
            childId: childId,
            date: Date(),
            heightCm: heightCm,
            weightKg: weightKg,
            headCircumferenceCm: headCircumferenceCm
        )
        growthRecords.append(record)
        bus.publish(.recordSaved(childId: childId))
    }

    // MARK: - 기록 조회

    /// 특정 아이의 다이어리 항목을 날짜 내림차순으로 반환한다.
    func diaryEntries(for childId: UUID) -> [DiaryEntry] {
        diaryEntries
            .filter { $0.childId == childId }
            .sorted { $0.date > $1.date }
    }

    /// 특정 아이의 성장 기록을 날짜 오름차순으로 반환한다.
    func growthRecords(for childId: UUID) -> [GrowthRecord] {
        growthRecords
            .filter { $0.childId == childId }
            .sorted { $0.date < $1.date }
    }
}
