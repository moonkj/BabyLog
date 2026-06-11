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
    @Published private(set) var expenses: [Expense]
    /// 접종 완료 키 집합 (키 = "childId|vaccineId").
    @Published private(set) var vaccineCompletions: Set<String>
    @Published private(set) var pregnancyLogs: [PregnancyLog]
    /// 좋아요한 다이어리 id(문자열) — 가족/조부모 모드 대비, 현재 로컬
    @Published private(set) var likedDiaryIds: Set<String>
    /// 다이어리별 댓글 (key = uuid 문자열)
    @Published private(set) var diaryComments: [String: [String]]
    // 마켓 (로컬 백본)
    @Published private(set) var marketItems: [MarketItem] = []
    @Published private(set) var savedMarketIds: Set<String> = []
    @Published private(set) var marketChats: [String: [ChatMessage]] = [:]
    private var marketSeeded: Bool = false
    // 크루 (로컬 백본)
    @Published private(set) var crews: [CrewMeetup] = []
    @Published private(set) var joinedCrewIds: Set<String> = []
    private var crewSeeded: Bool = false
    @Published var selectedChildId: UUID?

    /// 방금 획득한 뱃지 — 어느 화면에서든 전역 축하 카드로 표시(설정 시 MainTabView가 띄움)
    @Published var pendingBadgeAward: BadgeCatalogItem? = nil

    // MARK: - Private

    private let bus: EventBus
    private let persistence: LocalPersistence?

    // MARK: - 뱃지 획득 감지 (UserDefaults 로컬 상태)

    private var seenBadgeIds: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "bl_seen_badges") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "bl_seen_badges") }
    }
    private var badgesSeeded: Bool {
        get { UserDefaults.standard.bool(forKey: "bl_badges_seeded") }
        set { UserDefaults.standard.set(newValue, forKey: "bl_badges_seeded") }
    }

    /// 현재 획득 상태인 모든 뱃지 ID (엔진 + 마일스톤). ProfileScreen 표시와 동일 기준.
    var currentEarnedBadgeIds: Set<String> {
        let recordCount = diaryEntries.count + growthRecords.count
        let streak = ProfileStreak.currentStreak(diaryDates: diaryEntries.map(\.date))
        var s = BadgeEngine.earnedBadges(recordCount: recordCount, consecutiveDays: streak,
                                         tradeCount: 0, crewMeetings: 0, postLikes: 0)
        let now = Date()
        if !children.isEmpty { s.insert("first_child") }
        if children.count >= 2 { s.insert("multi_child") }
        if !pregnancies.isEmpty { s.insert("pregnancy_logged") }
        if diaryEntries.contains(where: { !$0.photoRefList.isEmpty }) { s.insert("first_photo") }
        if diaryEntries.count >= 10 { s.insert("memory_keeper") }
        if growthRecords.count >= 5 { s.insert("growth_tracker") }
        if children.contains(where: { AgeCalculator.dPlusDays(birthDate: $0.birthDate, asOf: now) >= 100 }) { s.insert("hundred_days") }
        if children.contains(where: { AgeCalculator.dPlusDays(birthDate: $0.birthDate, asOf: now) >= 365 }) { s.insert("first_birthday") }
        return s
    }

    /// 새로 획득한 뱃지를 감지해 pendingBadgeAward에 올린다. 첫 실행은 축하 없이 시드.
    func refreshBadgeAwards() {
        let current = currentEarnedBadgeIds
        guard badgesSeeded else {
            seenBadgeIds = current
            badgesSeeded = true
            return
        }
        let newlyEarned = current.subtracting(seenBadgeIds)
        seenBadgeIds = seenBadgeIds.union(current)
        guard let firstId = newlyEarned.sorted().first,
              var item = BadgeCatalogItem.sampleCatalog.first(where: { $0.id == firstId })
        else { return }
        item.isEarned = true
        pendingBadgeAward = item
    }
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
        expenses: [Expense] = [],
        vaccineCompletions: Set<String> = [],
        pregnancyLogs: [PregnancyLog] = [],
        likedDiaryIds: Set<String> = [],
        diaryComments: [String: [String]] = [:],
        bus: EventBus = .shared,
        persistence: LocalPersistence? = nil
    ) {
        self.pregnancies = pregnancies
        self.children = children
        self.growthRecords = growthRecords
        self.diaryEntries = diaryEntries
        self.expenses = expenses
        self.vaccineCompletions = vaccineCompletions
        self.pregnancyLogs = pregnancyLogs
        self.likedDiaryIds = likedDiaryIds
        self.diaryComments = diaryComments
        self.bus = bus
        self.persistence = persistence

        // persistence가 주입된 경우 저장된 상태로 복원 (파일 없으면 무시)
        if let persistence = persistence,
           let saved = try? persistence.load() {
            self.pregnancies        = saved.pregnancies
            self.children           = saved.children
            self.growthRecords      = saved.growthRecords
            self.diaryEntries       = saved.diaryEntries
            self.expenses           = saved.expenses
            self.vaccineCompletions = saved.vaccineCompletions
            self.pregnancyLogs      = saved.pregnancyLogs
            self.likedDiaryIds      = saved.likedDiaryIds
            self.diaryComments      = saved.diaryComments
            self.marketItems        = saved.marketItems
            self.savedMarketIds     = saved.savedMarketIds
            self.marketChats        = saved.marketChats
            self.marketSeeded       = saved.marketSeeded
            self.crews              = saved.crews
            self.joinedCrewIds      = saved.joinedCrewIds
            self.crewSeeded         = saved.crewSeeded
        }
        seedMarketIfNeeded()
        seedCrewIfNeeded()
    }

    // MARK: - 크루 (로컬 백본 — 추후 Supabase)

    func seedCrewIfNeeded() {
        guard !crewSeeded else { return }
        if crews.isEmpty { crews = CrewMeetup.seedSamples }
        crewSeeded = true
    }

    func addCrew(_ meetup: CrewMeetup) {
        crews.insert(meetup, at: 0)
        joinedCrewIds.insert(meetup.id)   // 주최자는 자동 참여
    }

    func deleteCrew(id: String) {
        crews.removeAll { $0.id == id }
        joinedCrewIds.remove(id)
    }

    func isJoinedCrew(_ id: String) -> Bool { joinedCrewIds.contains(id) }

    /// 표시용 참여 인원 = 기본 인원 + (내가 참여 시 +1)
    func crewJoinedCount(_ meetup: CrewMeetup) -> Int {
        meetup.joined + (joinedCrewIds.contains(meetup.id) && !meetup.mine ? 1 : 0)
    }

    func toggleJoinCrew(_ id: String) {
        if joinedCrewIds.contains(id) { joinedCrewIds.remove(id) }
        else { joinedCrewIds.insert(id) }
    }

    // MARK: - 마켓 (로컬 백본 — 추후 Supabase 동기화)

    /// 첫 실행 시 데모 매물 시드(1회). 이후 사용자가 등록/삭제 가능.
    func seedMarketIfNeeded() {
        guard !marketSeeded else { return }
        if marketItems.isEmpty { marketItems = MarketItem.seedSamples }
        marketSeeded = true
    }

    func addMarketItem(_ item: MarketItem) {
        marketItems.insert(item, at: 0)
    }

    func deleteMarketItem(id: String) {
        if let item = marketItems.first(where: { $0.id == id }) {
            for ref in item.photoRefs { PhotoStore.delete(ref) }
        }
        marketItems.removeAll { $0.id == id }
        savedMarketIds.remove(id)
        marketChats[id] = nil
    }

    func setMarketStatus(id: String, _ status: MarketStatus) {
        guard let idx = marketItems.firstIndex(where: { $0.id == id }) else { return }
        marketItems[idx].status = status
    }

    func isMarketSaved(_ id: String) -> Bool { savedMarketIds.contains(id) }

    func toggleMarketSaved(_ id: String) {
        guard let idx = marketItems.firstIndex(where: { $0.id == id }) else { return }
        if savedMarketIds.contains(id) {
            savedMarketIds.remove(id)
            marketItems[idx].favoriteCount = max(0, marketItems[idx].favoriteCount - 1)
        } else {
            savedMarketIds.insert(id)
            marketItems[idx].favoriteCount += 1
        }
    }

    func marketMessages(itemId: String) -> [ChatMessage] { marketChats[itemId] ?? [] }

    func sendMarketMessage(itemId: String, text: String, mine: Bool = true) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        marketChats[itemId, default: []].append(ChatMessage(text: t, mine: mine))
    }

    // MARK: - Auto Persist

    /// 상태 변경을 감지해 0.5s debounce 후 자동으로 영속화한다.
    ///
    /// `persistence`가 nil이면 아무 동작도 하지 않는다.
    /// 구독은 내부 `cancellables`에 보관되므로 store 생존 중 유지된다.
    func enableAutoPersist() {
        guard persistence != nil else { return }

        // 모든 @Published 변경(objectWillChange)을 단일 신호로 받아 0.5s debounce 후 저장한다.
        // combineLatest 4-arity 한계 없이 상태 종류가 늘어나도 그대로 확장된다.
        // objectWillChange는 willSet 시점에 방출되지만 debounce 지연 동안 값이 갱신되므로
        // 지연 후 snapshot()은 최신 상태를 담는다.
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] in
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
            diaryEntries:  diaryEntries,
            expenses:      expenses,
            vaccineCompletions: vaccineCompletions,
            pregnancyLogs: pregnancyLogs,
            likedDiaryIds: likedDiaryIds,
            diaryComments: diaryComments,
            marketItems: marketItems,
            savedMarketIds: savedMarketIds,
            marketChats: marketChats,
            marketSeeded: marketSeeded,
            crews: crews,
            joinedCrewIds: joinedCrewIds,
            crewSeeded: crewSeeded
        )
    }

    /// 저장된 스냅샷으로 상태를 복원한다.
    func restore(_ state: PersistableState) {
        pregnancies        = state.pregnancies
        children           = state.children
        growthRecords      = state.growthRecords
        diaryEntries       = state.diaryEntries
        expenses           = state.expenses
        vaccineCompletions = state.vaccineCompletions
        pregnancyLogs      = state.pregnancyLogs
        likedDiaryIds      = state.likedDiaryIds
        diaryComments      = state.diaryComments
        marketItems        = state.marketItems
        savedMarketIds     = state.savedMarketIds
        marketChats        = state.marketChats
        marketSeeded       = state.marketSeeded
        crews              = state.crews
        joinedCrewIds      = state.joinedCrewIds
        crewSeeded         = state.crewSeeded
        seedMarketIfNeeded()
        seedCrewIfNeeded()
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
    func completeBabyOnboarding(name: String, birthDate: Date, gender: Gender?,
                                profileImageRef: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let child = Child(id: UUID(), name: trimmed, birthDate: birthDate, gender: gender,
                          profileImageRef: profileImageRef, caregiverRole: nil, pregnancyId: nil)
        children.append(child)
        selectedChildId = child.id
        refreshBadgeAwards()
    }

    /// 아이 정보를 수정한다. 빈 이름은 무시(기존 유지). profileImageRef는 .some일 때만 갱신.
    func updateChild(id: UUID, name: String, birthDate: Date, gender: Gender?,
                     profileImageRef: String?? = nil) {
        guard let idx = children.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { children[idx].name = trimmed }
        children[idx].birthDate = birthDate
        children[idx].gender = gender
        if let newRef = profileImageRef {   // 이중 옵셔널: 전달된 경우에만 변경(nil로도 초기화 가능)
            children[idx].profileImageRef = newRef
        }
    }

    /// 아이를 삭제한다. 연결된 기록(성장·다이어리 사진 포함)도 함께 정리한다.
    func deleteChild(id: UUID) {
        for entry in diaryEntries where entry.childId == id {
            PhotoStore.delete(entry.photoRef)
        }
        diaryEntries.removeAll { $0.childId == id }
        growthRecords.removeAll { $0.childId == id }
        // 접종 완료 키 정리
        let prefix = "\(id.uuidString)|"
        vaccineCompletions = vaccineCompletions.filter { !$0.hasPrefix(prefix) }
        children.removeAll { $0.id == id }
        if selectedChildId == id { selectedChildId = children.first?.id }
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
        refreshBadgeAwards()
    }

    /// 임신 정보(태명·예정일·LMP) 수정.
    func updatePregnancy(id: UUID, nickname: String?, lmp: Date?, edd: Date?) {
        guard let idx = pregnancies.firstIndex(where: { $0.id == id }) else { return }
        pregnancies[idx].nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        pregnancies[idx].lmpDate = lmp
        pregnancies[idx].eddDate = edd
    }

    /// 임신 기록 삭제 (관련 로그 정리).
    func deletePregnancy(id: UUID) {
        pregnancyLogs.removeAll { $0.pregnancyId == id }
        pregnancies.removeAll { $0.id == id }
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
            refreshBadgeAwards()
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
        photoRef: String?,
        photoRefs: [String] = [],
        videoRef: String? = nil
    ) {
        let hasMedia = photoRef != nil || !photoRefs.isEmpty || videoRef != nil
        let entry = DiaryEntry(
            id: UUID(),
            childId: childId,
            date: Date(),
            recordType: hasMedia ? "photo" : "diary",
            content: content,
            milestone: milestone,
            photoRef: photoRef ?? photoRefs.first,
            photoRefs: photoRefs,
            videoRef: videoRef
        )
        diaryEntries.append(entry)
        bus.publish(.recordSaved(childId: childId))
        refreshBadgeAwards()
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
        refreshBadgeAwards()
    }

    // MARK: - 가계부 CRUD

    /// 지출 항목을 추가한다. 금액이 0 이하이면 무시.
    func addExpense(amount: Int, category: ExpenseCategory, date: Date = Date(),
                    memo: String? = nil, autoCollected: Bool = false) {
        guard amount > 0 else { return }
        let trimmed = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        let expense = Expense(amount: amount, category: category, date: date,
                              memo: (trimmed?.isEmpty ?? true) ? nil : trimmed,
                              autoCollected: autoCollected)
        expenses.append(expense)
    }

    /// 지출 항목을 삭제한다.
    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
    }

    // MARK: - 접종 완료 (안정 키 영속)

    /// 접종 완료 안정 키. provider UUID가 매 로드 달라지므로 childId+vaccineId로 식별한다.
    static func vaccineKey(childId: UUID, vaccineId: String) -> String {
        "\(childId.uuidString)|\(vaccineId)"
    }

    func isVaccineDone(childId: UUID, vaccineId: String) -> Bool {
        vaccineCompletions.contains(Self.vaccineKey(childId: childId, vaccineId: vaccineId))
    }

    /// 접종 완료 상태를 토글한다.
    func toggleVaccine(childId: UUID, vaccineId: String) {
        let key = Self.vaccineKey(childId: childId, vaccineId: vaccineId)
        if vaccineCompletions.contains(key) {
            vaccineCompletions.remove(key)
        } else {
            vaccineCompletions.insert(key)
        }
    }

    // MARK: - 임신 기록 (태동·체중)

    /// 특정 임신의 오늘 태동 횟수.
    func todayMovementCount(pregnancyId: UUID, on date: Date = Date()) -> Int {
        let cal = Calendar.current
        let log = pregnancyLogs.first {
            $0.pregnancyId == pregnancyId && $0.kind == .movement
                && cal.isDate($0.date, inSameDayAs: date)
        }
        return Int(log?.value ?? 0)
    }

    /// 오늘 태동 횟수를 upsert한다 (0 이하면 해당 로그 제거).
    func setMovementCount(pregnancyId: UUID, count: Int, on date: Date = Date()) {
        let cal = Calendar.current
        let idx = pregnancyLogs.firstIndex {
            $0.pregnancyId == pregnancyId && $0.kind == .movement
                && cal.isDate($0.date, inSameDayAs: date)
        }
        if count <= 0 {
            if let idx { pregnancyLogs.remove(at: idx) }
            return
        }
        if let idx {
            pregnancyLogs[idx].value = Double(count)
        } else {
            pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: date,
                                              kind: .movement, value: Double(count)))
        }
    }

    /// 체중 기록을 추가한다 (kg). 0 이하 무시.
    func addPregnancyWeight(pregnancyId: UUID, kg: Double, on date: Date = Date()) {
        guard kg > 0 else { return }
        pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: date,
                                          kind: .weight, value: kg))
    }

    /// 특정 임신의 체중 기록을 날짜 오름차순으로 반환한다.
    func pregnancyWeights(pregnancyId: UUID) -> [PregnancyLog] {
        pregnancyLogs
            .filter { $0.pregnancyId == pregnancyId && $0.kind == .weight }
            .sorted { $0.date < $1.date }
    }

    /// 배 사진을 추가한다(로컬 파일명 필요). week는 주차.
    func addBellyPhoto(pregnancyId: UUID, week: Int, photoRef: String) {
        pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: Date(),
                                          kind: .belly, value: Double(week), photoRef: photoRef))
    }

    /// 특정 임신의 배 사진을 주차 오름차순으로 반환한다.
    func bellyPhotos(pregnancyId: UUID) -> [PregnancyLog] {
        pregnancyLogs
            .filter { $0.pregnancyId == pregnancyId && $0.kind == .belly }
            .sorted { $0.value < $1.value }
    }

    /// 배 사진 삭제(사진 파일도 정리).
    func deleteBellyPhoto(id: UUID) {
        if let log = pregnancyLogs.first(where: { $0.id == id }) {
            PhotoStore.delete(log.photoRef)
        }
        pregnancyLogs.removeAll { $0.id == id }
    }

    /// 다이어리 항목을 삭제한다. 연결된 로컬 사진도 함께 정리한다.
    func deleteDiaryEntry(id: UUID) {
        if let entry = diaryEntries.first(where: { $0.id == id }) {
            for ref in entry.photoRefList { PhotoStore.delete(ref) }
            if entry.photoRefList.isEmpty { PhotoStore.delete(entry.photoRef) }
            PhotoStore.delete(entry.videoRef)
        }
        diaryEntries.removeAll { $0.id == id }
        likedDiaryIds.remove(id.uuidString)
        diaryComments[id.uuidString] = nil
    }

    /// 성장 기록을 삭제한다.
    func deleteGrowthRecord(id: UUID) {
        growthRecords.removeAll { $0.id == id }
    }

    // MARK: - 좋아요 / 댓글 (가족·조부모 모드 대비, 현재 로컬)

    func isDiaryLiked(_ id: UUID) -> Bool { likedDiaryIds.contains(id.uuidString) }

    func toggleDiaryLike(_ id: UUID) {
        let key = id.uuidString
        if likedDiaryIds.contains(key) { likedDiaryIds.remove(key) }
        else { likedDiaryIds.insert(key) }
    }

    func comments(for id: UUID) -> [String] { diaryComments[id.uuidString] ?? [] }

    func addComment(entryId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        diaryComments[entryId.uuidString, default: []].append(trimmed)
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
