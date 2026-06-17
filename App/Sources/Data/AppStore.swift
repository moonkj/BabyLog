import Foundation
import Combine
import UserNotifications   // 기록 삭제 시 "N년 전 오늘" 추억 알림 취소용
import WidgetKit           // 저장 직후 위젯 타임라인 갱신용

// MARK: - AppStore

/// 임신 → 출산 전환을 원자적으로 관리하는 인메모리 스토어.
///
/// - Note: `persistence` 인자를 주입하면 init 시 저장된 상태를 자동 복원하고,
///   `enableAutoPersist()`를 호출하면 상태 변경 시 0.5s debounce 후 자동 저장된다.
@MainActor
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
    /// Pro 여부 — 가족 피드·마켓 다중판매 등 클라 게이트의 단일 소스.
    /// StoreKit 실제 구독 엔타이틀먼트(subscriptionActive) 또는 개발/운영자 강제(devProOverride)로 결정.
    /// 마지막 값을 캐시해 앱 시작 직후(엔타이틀먼트 로드 전) Pro 사용자가 잠깐 무료로 보이지 않게 한다.
    @Published private(set) var isPro: Bool = UserDefaults.standard.bool(forKey: "bl_is_pro") {
        didSet { UserDefaults.standard.set(isPro, forKey: "bl_is_pro") }
    }
    /// StoreKit 실제 구독 엔타이틀먼트(StoreManager가 갱신). 서버 등급과 별개의 클라 신뢰 소스.
    @Published private(set) var subscriptionActive = false
    /// 개발/운영자 로컬 Pro 강제(클라 UI 검증용). 서버 등급은 StoreKit 구독으로만 부여된다.
    @Published var devProOverride: Bool = UserDefaults.standard.bool(forKey: "bl_dev_pro") {
        didSet { UserDefaults.standard.set(devProOverride, forKey: "bl_dev_pro"); recomputePro() }
    }
    /// StoreManager가 엔타이틀먼트 변화 시 호출 — 실제 구독 상태를 반영.
    func setSubscriptionActive(_ active: Bool) {
        guard subscriptionActive != active else { return }
        subscriptionActive = active
        recomputePro()
    }
    private func recomputePro() { isPro = subscriptionActive || devProOverride }
    /// 가족 피드 변경 신호(공유 완료 등). 증가 시 타임라인이 가족 반응을 다시 읽는다(메모리 전용).
    @Published var familyFeedVersion = 0
    /// 저장 실패 안내(메모리 전용) — 디스크 실패 시 '저장됨' 위장 금지(정직·데이터손실 방지). UI가 알럿으로 노출.
    @Published var lastPersistError: String? = nil
    /// 불러오기 실패(파일 손상) 안내 — 원본은 .corrupt-* 로 보존됨. 사용자가 빈 화면을 데이터 소실로 오인하지 않게 1회 안내.
    @Published var loadFailedNotice: String? = nil
    /// 임신 홈에서 '검진 일정 보기' 탭 시 기록 화면을 검진 세그먼트로 여는 딥링크 신호(메모리 전용).
    @Published var openPregnancyCheckup = false
    /// 홈 '접종 확인하기' 탭 시 기록 화면을 예방접종 세그먼트로 여는 딥링크 신호(메모리 전용).
    @Published var openVaccineSegment = false
    /// 빈 타임라인 등에서 '빠른 기록'을 띄우라는 신호 — MainTabView가 mode에 맞춰 처리(메모리 전용).
    @Published var requestQuickRecord = false
    /// 검진 알림 켜짐 여부(영속). 켜면 권장 시기 전 로컬 알림.
    @Published var checkupRemindersOn: Bool = UserDefaults.standard.bool(forKey: "bl_checkup_reminders") {
        didSet { UserDefaults.standard.set(checkupRemindersOn, forKey: "bl_checkup_reminders") }
    }
    /// 가족 공유 의도/진행 중인 기록 id — 업로드가 끝나기 전에도 카드가 즉시 '공유 중'을 보이게(메모리 전용).
    @Published var sharedFeedEntryIds: Set<String> = []
    func markFeedShared(_ id: String)   { sharedFeedEntryIds.insert(id) }
    func unmarkFeedShared(_ id: String) { sharedFeedEntryIds.remove(id) }

    // MARK: - 내 동네 (당근식 대표 동네. 크루=동 단위, 마켓=시 단위. 주변/응급은 실시간 GPS)
    /// 내 동네 한 개 = 동(인증·표시·크루 범위) + 시(마켓 노출 범위).
    struct MyHood: Codable, Equatable, Identifiable {
        let dong: String     // 미평동 — 표시/인증/크루
        let city: String     // 순천시 — 마켓 노출 범위
        var id: String { dong }
    }
    /// 내 동네 — 최대 2개. 현재 위치에서만 추가(인증) → 어뷰징·스팸 방지.
    @Published var myHoods: [MyHood] = AppStore.loadMyHoods() {
        didSet {
            if let data = try? JSONEncoder().encode(myHoods) {
                UserDefaults.standard.set(data, forKey: "bl_my_hoods_v2")
            }
        }
    }
    private static func loadMyHoods() -> [MyHood] {
        guard let d = UserDefaults.standard.data(forKey: "bl_my_hoods_v2"),
              let arr = try? JSONDecoder().decode([MyHood].self, from: d) else { return [] }
        return arr
    }
    /// 적용 중인 내 동네 인덱스(0/1).
    @Published var selectedHoodIndex: Int = UserDefaults.standard.integer(forKey: "bl_selected_hood") {
        didSet { UserDefaults.standard.set(selectedHoodIndex, forKey: "bl_selected_hood") }
    }
    private var selectedHoodEntry: MyHood? {
        guard !myHoods.isEmpty else { return nil }
        return myHoods[min(max(0, selectedHoodIndex), myHoods.count - 1)]
    }
    /// 선택된 동(크루 범위·표시). 미설정 시 nil → 화면이 GPS 폴백/설정 유도.
    var selectedDong: String? { selectedHoodEntry?.dong }
    /// 선택된 시(마켓 노출 범위).
    var selectedCity: String? { selectedHoodEntry?.city }
    /// 내 동네 추가(현재 위치 동+시). 최대 2개·동 중복 불가. 추가하면 자동 선택.
    func addHood(dong: String, city: String) {
        let d = dong.trimmingCharacters(in: .whitespaces)
        let c = city.trimmingCharacters(in: .whitespaces)
        guard !d.isEmpty, !c.isEmpty, d != "우리 동네",
              !myHoods.contains(where: { $0.dong == d }), myHoods.count < 2 else { return }
        myHoods.append(MyHood(dong: d, city: c))
        selectedHoodIndex = myHoods.count - 1
    }
    func removeHood(at index: Int) {
        guard myHoods.indices.contains(index) else { return }
        myHoods.remove(at: index)
        if selectedHoodIndex >= myHoods.count { selectedHoodIndex = max(0, myHoods.count - 1) }
    }
    func selectHood(_ index: Int) {
        guard myHoods.indices.contains(index) else { return }
        selectedHoodIndex = index
    }
    // 마켓 (로컬 백본)
    @Published private(set) var marketItems: [MarketItem] = []
    @Published private(set) var savedMarketIds: Set<String> = []
    /// 관심(좋아요)한 매물 스냅샷(id→매물). 다른 동네로 이동하거나 현재 fetch에 없어도
    /// '관심 목록'에서 계속 볼 수 있도록 저장 시점 사본을 보관(영속).
    @Published private(set) var savedMarketSnapshots: [String: MarketItem] = [:]
    @Published private(set) var marketChats: [String: [ChatMessage]] = [:]
    private var marketSeeded: Bool = false
    // 크루 (로컬 백본)
    @Published private(set) var crews: [CrewMeetup] = []
    @Published private(set) var joinedCrewIds: Set<String> = []
    @Published private(set) var joinedCrewGroupIds: Set<String> = []
    @Published private(set) var likedCrewPostIds: Set<String> = []
    @Published private(set) var vaccineHospitals: [String: String] = [:]
    @Published private(set) var checkupDoneKeys: Set<String> = []
    @Published private(set) var crewPosts: [CrewPost] = []
    @Published private(set) var crewPostComments: [String: [String]] = [:]
    @Published private(set) var crewChats: [String: [ChatMessage]] = [:]
    @Published private(set) var tradeReports: [TradeReport] = []
    /// 사용자가 '받았다'고 체크한 정부지원금 id 집합 (가계부 지원금 완료 표시, 영속).
    @Published private(set) var claimedSubsidyIds: Set<String> = []
    /// 성장 보드(아이당 1개). 폴라로이드 카드 레이아웃·연결·스티커.
    @Published private(set) var growthBoards: [GrowthBoard] = []
    private var crewSeeded: Bool = false
    private var crewPostSeeded: Bool = false
    /// 저장 파일 디코딩 실패 여부 — true면 자동저장으로 원본을 덮어쓰지 않는다(데이터 보존).
    private var loadDidFail: Bool = false
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
        let tradeCount = marketItems.filter { $0.mine && $0.status == .sold }.count
        var s = BadgeEngine.earnedBadges(recordCount: recordCount, consecutiveDays: streak,
                                         tradeCount: tradeCount,
                                         crewMeetings: joinedCrewIds.count,
                                         postLikes: likedCrewPostIds.count)
        let now = Date()
        if !children.isEmpty { s.insert("first_child") }
        if children.count >= 2 { s.insert("multi_child") }
        if !pregnancies.isEmpty { s.insert("pregnancy_logged") }
        if diaryEntries.contains(where: { !$0.photoRefList.isEmpty }) { s.insert("first_photo") }
        if diaryEntries.count >= 10 { s.insert("memory_keeper") }
        if growthRecords.count >= 5 { s.insert("growth_tracker") }
        if children.contains(where: { AgeCalculator.dPlusDays(birthDate: $0.birthDate, asOf: now) >= 100 }) { s.insert("hundred_days") }
        if children.contains(where: { AgeCalculator.dPlusDays(birthDate: $0.birthDate, asOf: now) >= 365 }) { s.insert("first_birthday") }
        // 마켓/거래
        if marketItems.contains(where: { $0.mine }) { s.insert("first_listing") }
        if marketItems.contains(where: { $0.status == .sold }) { s.insert("first_trade") }
        if marketItems.filter({ $0.mine && $0.isFree }).count >= 3 { s.insert("share_angel") }
        // 크루
        if !joinedCrewIds.isEmpty { s.insert("first_crew") }
        // 초기 멤버 — 우리 동네 크루(모임/그룹)에 합류하면 부여. 콜드스타트(오픈 전) 화면의
        // '초기 멤버 뱃지' 약속을 실제로 지킨다. (기존 미지급 상태였던 early_member 정합화.)
        if !joinedCrewIds.isEmpty || !joinedCrewGroupIds.isEmpty { s.insert("early_member") }
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
        // 카탈로그에 없는 고아 id도 seen 처리는 유지 — 매 호출 같은 id가 재등장해
        // 무한 재시도되는 것 방지.
        seenBadgeIds = seenBadgeIds.union(current)
        // 첫 id가 카탈로그에 없다고 그냥 return하면 같은 배치의 진짜 뱃지 축하가
        // 통째로 삼켜진다(이미 seen 처리돼 다시 안 뜸) — 카탈로그에 존재하는
        // 첫 항목을 찾을 때까지 순회한다.
        for newId in newlyEarned.sorted() {
            if var item = BadgeCatalogItem.sampleCatalog.first(where: { $0.id == newId }) {
                item.isEarned = true
                pendingBadgeAward = item
                return
            }
        }
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

        // persistence가 주입된 경우 저장된 상태로 복원.
        // 파일이 있는데 디코딩이 실패하면(스키마 손상 등) 빈 상태로 시작하되,
        // 원본을 백업하고 자동저장을 막아 사용자 데이터가 덮어써지지 않게 한다.
        if let persistence = persistence {
            do {
                if let saved = try persistence.load() {
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
                    self.savedMarketSnapshots = saved.savedMarketSnapshots
                    self.marketChats        = saved.marketChats
                    self.marketSeeded       = saved.marketSeeded
                    self.crews              = saved.crews
                    self.joinedCrewIds      = saved.joinedCrewIds
                    self.crewSeeded         = saved.crewSeeded
                    self.joinedCrewGroupIds = saved.joinedCrewGroupIds
                    self.likedCrewPostIds   = saved.likedCrewPostIds
                    self.vaccineHospitals   = saved.vaccineHospitals
                    self.checkupDoneKeys    = saved.checkupDoneKeys
                    self.crewPosts          = saved.crewPosts
                    self.crewPostComments   = saved.crewPostComments
                    self.crewChats          = saved.crewChats
                    self.crewPostSeeded     = saved.crewPostSeeded
                    self.tradeReports       = saved.tradeReports
                    self.claimedSubsidyIds  = saved.claimedSubsidyIds
                    self.growthBoards       = saved.growthBoards
                    self.pruneOrphanBoards()   // 아이가 없는 보드(부분/옛 백업) 정리 — 백업·메모리참조 오염 방지
                    self.normalizePrimaryFlags()   // 대표 보드 영속 고정(레거시·복원 순서 의존 제거)
                    // 저장된 선택 아이가 아직 있으면 복원(다자녀 선택 유지)
                    self.selectedChildId    = saved.selectedChildId.flatMap { id in saved.children.contains(where: { $0.id == id }) ? id : nil }
                }
            } catch {
                // 손상 파일을 .corrupt-<ts>로 보존(복구용). 보존에 성공했으면 원본은 이미
                // 안전하므로 자동저장을 허용한다 — 안 그러면 사용자가 빈 앱에서 새로 쓴
                // 기록이 종료 시 전부 증발하는 '기억상실 모드'가 된다.
                // 보존 실패 시에만 차단 유지(원본 덮어쓰기 = 복구 여지 소멸).
                let preserved = persistence.backupCorrupt()
                self.loadDidFail = !preserved
                // 빈 화면을 '데이터 소실'로 오인하지 않게 안내(원본은 백업으로 보존). 손상은 같은 디코더로
                // 자동 복구가 불가하므로 알림만 — 자동저장이 원본을 덮어쓰기 전 사용자가 인지하게 한다.
                if preserved {
                    self.loadFailedNotice = "이전 기록을 불러오지 못했어요. 안전을 위해 백업해 두었어요. 새 기록은 계속 저장되며, 복구가 필요하면 문의해 주세요."
                }
            }
        }
        seedMarketIfNeeded()
        seedCrewIfNeeded()
        seedCrewPostsIfNeeded()
    }

    // MARK: - 크루 (로컬 백본 — 추후 Supabase)

    func seedCrewIfNeeded() {
        guard !crewSeeded else { return }
        if crews.isEmpty { crews = CrewMeetup.seedSamples }
        crewSeeded = true
    }

    func seedCrewPostsIfNeeded() {
        guard !crewPostSeeded else { return }
        if crewPosts.isEmpty { crewPosts = CrewPost.seedSamples }
        crewPostSeeded = true
    }

    // MARK: - 크루 게시판 (로컬)

    func addCrewPost(category: CrewPostCategory, title: String, body: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let nickname = UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님"
        let post = CrewPost(category: category, authorName: nickname, timeText: "방금 전",
                            title: t, body: body.trimmingCharacters(in: .whitespacesAndNewlines),
                            replyCount: 0, likeCount: 0, mine: true)
        crewPosts.insert(post, at: 0)
    }

    func deleteCrewPost(id: String) {
        crewPosts.removeAll { $0.id == id }
        likedCrewPostIds.remove(id)
        crewPostComments[id] = nil
    }

    func crewPostCommentList(postId: String) -> [String] { crewPostComments[postId] ?? [] }
    func addCrewPostComment(postId: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        crewPostComments[postId, default: []].append(t)
    }
    /// 게시글 댓글 수(기본 + 사용자 추가)
    func crewPostReplyCount(_ post: CrewPost) -> Int {
        post.replyCount + (crewPostComments[post.id]?.count ?? 0)
    }

    // MARK: - 크루 모임 채팅 (로컬, 참가자용)

    func crewChat(meetupId: String) -> [ChatMessage] { crewChats[meetupId] ?? [] }
    func sendCrewChat(meetupId: String, text: String, mine: Bool = true) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        crewChats[meetupId, default: []].append(ChatMessage(text: t, mine: mine))
    }

    func addCrew(_ meetup: CrewMeetup) {
        crews.insert(meetup, at: 0)
        joinedCrewIds.insert(meetup.id)   // 주최자는 자동 참여
        refreshBadgeAwards()
    }

    func deleteCrew(id: String) {
        crews.removeAll { $0.id == id }
        joinedCrewIds.remove(id)
        crewChats[id] = nil
    }

    func isJoinedCrew(_ id: String) -> Bool { joinedCrewIds.contains(id) }

    /// 서버 모임 생성 직후 주최자를 참여 상태로 표시(정원 검사 없이).
    func markCrewJoined(_ id: String) {
        joinedCrewIds.insert(id)
        refreshBadgeAwards()
    }

    /// 표시용 참여 인원 = 기본 인원(나 제외) + (내가 참여 시 +1).
    /// 서버 모임은 fetch 시 본인을 빼서 joined가 항상 "나 제외"를 유지한다.
    func crewJoinedCount(_ meetup: CrewMeetup) -> Int {
        meetup.joined + (joinedCrewIds.contains(meetup.id) ? 1 : 0)
    }

    /// 참여 토글. 정원 초과 시 신규 참여를 막는다.
    func toggleJoinCrew(_ id: String) {
        if joinedCrewIds.contains(id) {
            joinedCrewIds.remove(id)
        } else {
            if let m = crews.first(where: { $0.id == id }), crewJoinedCount(m) >= m.capacity {
                return   // 정원 초과
            }
            joinedCrewIds.insert(id)
        }
        refreshBadgeAwards()
    }

    // 크루 그룹 가입 / 게시판 좋아요 (로컬)
    func isJoinedGroup(_ id: String) -> Bool { joinedCrewGroupIds.contains(id) }
    func toggleJoinGroup(_ id: String) {
        if joinedCrewGroupIds.contains(id) { joinedCrewGroupIds.remove(id) }
        else { joinedCrewGroupIds.insert(id) }
        // 그룹 합류도 early_member('초기 멤버') 조건이므로 즉시 축하 갱신(모임 합류와 동일).
        refreshBadgeAwards()
    }
    func isCrewPostLiked(_ id: String) -> Bool { likedCrewPostIds.contains(id) }
    func toggleCrewPostLike(_ id: String) {
        if likedCrewPostIds.contains(id) { likedCrewPostIds.remove(id) }
        else { likedCrewPostIds.insert(id) }
    }

    // 마켓 구매 (로컬 거래 플로우)
    /// 구매 확정 — 판매완료로 전환 + 거래 메시지 기록.
    func purchaseMarketItem(id: String) {
        guard let idx = marketItems.firstIndex(where: { $0.id == id }) else { return }
        marketItems[idx].status = .sold
        sendMarketMessage(itemId: id, text: "거래를 확정했어요. 감사합니다! 🤍", mine: true)
        refreshBadgeAwards()
    }
    /// 예약중으로 전환.
    func reserveMarketItem(id: String) {
        guard let idx = marketItems.firstIndex(where: { $0.id == id }) else { return }
        marketItems[idx].status = .reserved
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
        refreshBadgeAwards()
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

    /// 찜 토글(매물 전달) — 저장 시 스냅샷도 보관해 '관심 목록'이 동네 이동·만료에도 유지되게.
    func toggleMarketSaved(_ item: MarketItem) {
        if savedMarketIds.contains(item.id) {
            savedMarketIds.remove(item.id)
            savedMarketSnapshots[item.id] = nil
        } else {
            savedMarketIds.insert(item.id)
            savedMarketSnapshots[item.id] = item   // 저장 시점 사본
        }
    }

    /// 찜 토글(id만) — 스냅샷이 이미 있을 때만 보존, 없으면 id만. 가능하면 item 버전을 쓸 것.
    func toggleMarketSaved(_ id: String) {
        if savedMarketIds.contains(id) {
            savedMarketIds.remove(id)
            savedMarketSnapshots[id] = nil
        } else {
            savedMarketIds.insert(id)
            if let it = marketItems.first(where: { $0.id == id }) { savedMarketSnapshots[id] = it }
        }
    }

    /// 관심 매물 스냅샷 목록(최근 저장 추정 순서는 보장 안 함 — 호출부 정렬).
    var savedMarketItemSnapshots: [MarketItem] { Array(savedMarketSnapshots.values) }

    func marketMessages(itemId: String) -> [ChatMessage] { marketChats[itemId] ?? [] }

    func sendMarketMessage(itemId: String, text: String, mine: Bool = true) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        marketChats[itemId, default: []].append(ChatMessage(text: t, mine: mine))
    }

    // MARK: - 거래 신고 + 증거 보존 (로컬, 추후 서버 업로드)

    /// 거래를 신고하고 신고 시점의 대화를 스냅샷으로 보존한다.
    /// 매물/채팅이 이후 삭제돼도 신고 증거(transcript)는 유지된다.
    /// 백엔드 연결 시: 이 시점에 서버로 report+transcript 업로드(보관·적법 제출용) 후 uploaded=true.
    @discardableResult
    /// 신고 기록. transcript는 신고 시점의 화면 대화(서버 모드면 호출부가 전달, 없으면 로컬 폴백).
    func reportTrade(item: MarketItem, reason: String, note: String = "", transcript: [ChatMessage]? = nil) -> TradeReport {
        let report = TradeReport(
            itemId: item.id,
            itemTitle: item.title,
            counterpartName: item.sellerName,
            reason: reason,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            transcript: transcript ?? marketChats[item.id] ?? []
        )
        tradeReports.insert(report, at: 0)
        return report
    }

    /// 해당 매물에 대한 가장 최근 신고(있으면).
    func latestTradeReport(itemId: String) -> TradeReport? {
        tradeReports.first { $0.itemId == itemId }
    }

    /// 서버 업로드 완료 표시.
    func markReportUploaded(_ id: String) {
        if let i = tradeReports.firstIndex(where: { $0.id == id }) {
            tradeReports[i].uploaded = true
        }
    }

    /// 아직 업로드 안 된 신고들(오프라인 등으로 실패한 건 재시도용).
    var pendingReports: [TradeReport] { tradeReports.filter { !$0.uploaded } }

    // MARK: - Auto Persist

    /// 상태 변경을 감지해 0.5s debounce 후 자동으로 영속화한다.
    ///
    /// `persistence`가 nil이면 아무 동작도 하지 않는다.
    /// 구독은 내부 `cancellables`에 보관되므로 store 생존 중 유지된다.
    /// 자동저장 중복 구독 방지 플래그(멱등).
    private var autoPersistEnabled = false

    func enableAutoPersist() {
        guard persistence != nil else { return }
        // 디코딩 실패로 빈 상태일 땐 자동저장을 막아 원본(손상 의심) 파일을 덮어쓰지 않는다.
        guard !loadDidFail else { return }
        guard !autoPersistEnabled else { return }   // 멱등 — 중복 sink로 이중 저장 방지
        autoPersistEnabled = true

        // 모든 @Published 변경(objectWillChange)을 단일 신호로 받아 0.5s debounce 후 저장한다.
        // combineLatest 4-arity 한계 없이 상태 종류가 늘어나도 그대로 확장된다.
        // objectWillChange는 willSet 시점에 방출되지만 debounce 지연 동안 값이 갱신되므로
        // 지연 후 snapshot()은 최신 상태를 담는다.
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                self.persistSnapshot()
                // 저장 직후 위젯 타임라인 갱신 — 단, 위젯이 실제로 쓰는 데이터(아이 이름·생일)가
                // 바뀐 경우에만. UI 전용 @Published(딥링크 토글 등)까지 매번 reload하면
                // WidgetKit 일일 reload 예산을 소진해 정작 필요한 갱신을 굶긴다.
                self.reloadWidgetsIfNeeded()
            }
            .store(in: &cancellables)
    }

    /// 위젯 스냅샷에 들어가는 값(아이 id·이름·생일)의 서명. 바뀐 경우에만 위젯을 reload.
    private var lastWidgetSignature = ""
    private func reloadWidgetsIfNeeded() {
        let sig = children
            .map { "\($0.id.uuidString)|\($0.name)|\($0.birthDate.timeIntervalSince1970)" }
            .joined(separator: ";")
        guard sig != lastWidgetSignature else { return }
        lastWidgetSignature = sig
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 스냅샷 저장 — 실패를 삼키지 않고 lastPersistError로 노출(정직). 성공 시 에러 해제.
    private func persistSnapshot() {
        guard let persistence else { return }
        do {
            try persistence.save(snapshot())
            if lastPersistError != nil { lastPersistError = nil }
        } catch {
            // @Published는 대입마다 objectWillChange를 쏘므로, 같은 값 재대입은 자동저장 sink를
            // 다시 트리거해 디스크풀 상태에서 0.5s마다 무한 재시도 루프가 된다 → 변경 시에만 대입.
            let msg = "기록 저장에 실패했어요. 저장 공간을 확인하고 다시 시도해 주세요."
            if lastPersistError != msg { lastPersistError = msg }
            #if DEBUG
            print("[AppStore] persist save 실패: \(error)")
            #endif
        }
    }

    /// 즉시 저장 — 백그라운드 전환/복원 직후 등 debounce(0.5s)를 기다릴 수 없는 시점용.
    /// (마지막 기록이 앱 강제종료로 유실되는 것을 방지)
    func persistNow() {
        guard !loadDidFail else { return }
        persistSnapshot()
        // 백그라운드 전환 등 즉시 저장 직후에도 위젯을 갱신(아이 이름·생일 변경 시에만).
        reloadWidgetsIfNeeded()
    }

    // MARK: - Persistence Convenience

    /// 현재 인메모리 상태를 스냅샷으로 반환한다.
    func snapshot() -> PersistableState {
        // UserDefaults에만 살던 사용자 설정을 함께 백업(닉네임·검진알림·내동네·본 뱃지).
        // 백업/익스포트(iCloud·파일)에서 누락되면 신규 기기 복원 시 동네 인증·닉네임이 사라진다.
        var prefs: [String: String] = [:]
        let ud = UserDefaults.standard
        if let nick = ud.string(forKey: "bl_nickname"), !nick.isEmpty { prefs["nickname"] = nick }
        prefs["checkupRemindersOn"] = checkupRemindersOn ? "1" : "0"
        // 추억('N년 전 오늘') 알림 토글 — 상실·민감 시기에 끈 사용자가 복원 후 다시 켜져 닦달받지 않게 백업(민감영역).
        if let m = ud.object(forKey: "bl_memory_notif") as? Bool { prefs["memoryNotifOn"] = m ? "1" : "0" }
        prefs["selectedHoodIndex"]  = String(selectedHoodIndex)
        if let hoods = ud.data(forKey: "bl_my_hoods_v2") { prefs["myHoods"] = hoods.base64EncodedString() }
        let badges = ud.stringArray(forKey: "bl_seen_badges") ?? []
        if !badges.isEmpty, let d = try? JSONEncoder().encode(badges),
           let s = String(data: d, encoding: .utf8) { prefs["seenBadges"] = s }
        // 성장 보드 홈 섹션 제목(아이별 라벨) — 백업/복원·익스포트에 포함(데이터 주권).
        for child in children {
            let key = "bl_board_section_\(child.id.uuidString)"
            if let t = ud.string(forKey: key), !t.isEmpty { prefs[key] = t }
        }

        return PersistableState(
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
            savedMarketSnapshots: savedMarketSnapshots,
            marketChats: marketChats,
            marketSeeded: marketSeeded,
            crews: crews,
            joinedCrewIds: joinedCrewIds,
            crewSeeded: crewSeeded,
            joinedCrewGroupIds: joinedCrewGroupIds,
            likedCrewPostIds: likedCrewPostIds,
            vaccineHospitals: vaccineHospitals,
            checkupDoneKeys: checkupDoneKeys,
            crewPosts: crewPosts,
            crewPostComments: crewPostComments,
            crewChats: crewChats,
            crewPostSeeded: crewPostSeeded,
            tradeReports: tradeReports,
            claimedSubsidyIds: claimedSubsidyIds,
            selectedChildId: selectedChildId,
            growthBoards: growthBoards,
            prefs: prefs.isEmpty ? nil : prefs
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
        savedMarketSnapshots = state.savedMarketSnapshots
        marketChats        = state.marketChats
        marketSeeded       = state.marketSeeded
        crews              = state.crews
        joinedCrewIds      = state.joinedCrewIds
        crewSeeded         = state.crewSeeded
        joinedCrewGroupIds = state.joinedCrewGroupIds
        likedCrewPostIds   = state.likedCrewPostIds
        vaccineHospitals   = state.vaccineHospitals
        checkupDoneKeys    = state.checkupDoneKeys
        crewPosts          = state.crewPosts
        crewPostComments   = state.crewPostComments
        crewChats          = state.crewChats
        crewPostSeeded     = state.crewPostSeeded
        tradeReports       = state.tradeReports
        claimedSubsidyIds  = state.claimedSubsidyIds
        growthBoards       = state.growthBoards
        pruneOrphanBoards()   // 아이 없는 보드(부분 백업) 정리
        normalizePrimaryFlags()   // 대표 보드 영속 고정
        // 주의: 복원 시 툼스톤을 해제하지 않는다 — '지운 사진 부활 금지'(민감영역·절대원칙)가
        // 옛 백업 복원으로 빈 카드가 생기는 불편보다 우선. 의도적으로 지운 사진은 복원으로도 되살리지 않는다.
        // 저장된 선택 아이가 아직 존재하면 복원, 아니면 첫 아이로 폴백.
        selectedChildId    = state.selectedChildId.flatMap { id in children.contains(where: { $0.id == id }) ? id : nil }
        // UserDefaults 설정 복원 — restore()는 매 실행마다 호출되므로, 해당 키가 '없을 때만' 적용한다.
        // (키가 있으면 라이브 값이 최신이라 신뢰; 무조건 덮으면 닉네임 등이 옛 스냅샷으로 회귀.)
        // → 사실상 신규 기기·백업 복구 시나리오에서만 동작.
        if let prefs = state.prefs {
            let ud = UserDefaults.standard
            if ud.string(forKey: "bl_nickname") == nil, let nick = prefs["nickname"], !nick.isEmpty {
                ud.set(nick, forKey: "bl_nickname")
            }
            if ud.object(forKey: "bl_checkup_reminders") == nil, let c = prefs["checkupRemindersOn"] {
                checkupRemindersOn = (c == "1")
            }
            // 추억 알림 토글 — 라이브 값이 없을 때만(신규 기기·복구). 민감 시기에 끈 설정을 존중.
            if ud.object(forKey: "bl_memory_notif") == nil, let m = prefs["memoryNotifOn"] {
                ud.set(m == "1", forKey: "bl_memory_notif")
            }
            if ud.object(forKey: "bl_selected_hood") == nil, let s = prefs["selectedHoodIndex"], let i = Int(s) {
                selectedHoodIndex = i
            }
            if ud.data(forKey: "bl_my_hoods_v2") == nil, let b64 = prefs["myHoods"],
               let d = Data(base64Encoded: b64), let arr = try? JSONDecoder().decode([MyHood].self, from: d) {
                myHoods = arr
            }
            if ud.object(forKey: "bl_seen_badges") == nil, let s = prefs["seenBadges"],
               let d = s.data(using: .utf8), let arr = try? JSONDecoder().decode([String].self, from: d) {
                ud.set(arr, forKey: "bl_seen_badges")
            }
            // 성장 보드 섹션 제목 복원(아이별 키) — 라이브 값이 없을 때만.
            for (key, value) in prefs where key.hasPrefix("bl_board_section_") {
                if ud.string(forKey: key) == nil, !value.isEmpty { ud.set(value, forKey: key) }
            }
        }
        seedMarketIfNeeded()
        seedCrewIfNeeded()
        seedCrewPostsIfNeeded()
        // 손상 파일로 자동저장이 막혀 있던 경우(백업 복원 시나리오) — 복원본을 신뢰하고
        // 자동저장을 되살린 뒤 즉시 디스크에 기록한다. 안 하면 복원이 메모리에만 남아
        // 다음 실행에서 다시 손상 파일을 읽어 "복원했는데 또 사라짐"이 된다.
        loadDidFail = false
        // 복원에 성공했으므로 이전(손상 로드) 안내를 해제 — 정상 복원 후에도 "이전 기록을
        // 불러오지 못했어요" 알림이 남아 사용자를 혼란시키던 문제 방지.
        loadFailedNotice = nil
        enableAutoPersist()
        persistNow()
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

    /// 클라우드 자동복원 안전 판정 — 사용자가 입력한 어떤 데이터도 없을 때만 true.
    /// (children/pregnancies만 보면 가계부·성장만 입력한 로컬을 자동복원이 덮어쓰는 사고 방지.)
    var isEffectivelyEmpty: Bool {
        children.isEmpty && pregnancies.isEmpty && diaryEntries.isEmpty
            && growthRecords.isEmpty && expenses.isEmpty && pregnancyLogs.isEmpty
            && vaccineCompletions.isEmpty && claimedSubsidyIds.isEmpty
            // 성장 보드만 만든 사용자도 '비어있지 않음' — 백업 제외/복원 덮어쓰기 방지.
            && growthBoards.allSatisfy { $0.cards.isEmpty && $0.stickers.isEmpty }
    }

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
        persistNow()   // 온보딩 핵심 생성 — 디바운스 전 종료에도 유실 방지
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
            // 교체 시 기존 파일 정리(고아 파일 방지)
            if let old = children[idx].profileImageRef, old != newRef { PhotoStore.delete(old) }
            children[idx].profileImageRef = newRef
        }
    }

    /// 아이를 삭제한다. 연결된 기록(성장·다이어리 사진 포함)도 함께 정리한다.
    func deleteChild(id: UUID) {
        // 사진·영상 전부 정리 — 첫 장만 지우면 나머지가 기기에 고아로 남음(프라이버시+용량).
        for entry in diaryEntries where entry.childId == id {
            for ref in entry.photoRefList { PhotoStore.delete(ref) }
            if entry.photoRefList.isEmpty { PhotoStore.delete(entry.photoRef) }
            if let v = entry.videoRef { PhotoStore.delete(v) }
        }
        if let child = children.first(where: { $0.id == id }), let p = child.profileImageRef {
            PhotoStore.delete(p)
        }
        // 다이어리 좋아요/댓글 고아 정리(deleteDiaryEntry와 동일 정책) +
        // "N년 전 오늘" 추억 알림 취소 — 사별·이별 후 고인이 된 아이의 알림이
        // 도착하는 일은 절대 없어야 한다(민감영역).
        let deletedEntryIds = diaryEntries.filter { $0.childId == id }.map(\.id)
        for entryId in deletedEntryIds {
            likedDiaryIds.remove(entryId.uuidString)
            diaryComments[entryId.uuidString] = nil
        }
        // 가족 피드(서버 R2)에 공유된 기록도 함께 삭제 — 지운 아이 기록이 조부모/서버에 남는 것 방지(민감영역·프라이버시).
        cleanupSharedFeedPosts(deletedEntryIds)
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: deletedEntryIds.map { "memory-\($0.uuidString)" }
        )
        diaryEntries.removeAll { $0.childId == id }
        growthRecords.removeAll { $0.childId == id }
        // 접종 완료 키·병원 메모 정리
        let prefix = "\(id.uuidString)|"
        vaccineCompletions = vaccineCompletions.filter { !$0.hasPrefix(prefix) }
        vaccineHospitals = vaccineHospitals.filter { !$0.key.hasPrefix(prefix) }
        // 성장 보드도 정리 — 먼저 레코드를 제거한 뒤 보드 전용 사진(고아)을 ref-count로 삭제(공유 사진 보존).
        // 기록 참조 사진(sourceEntryId)은 위 다이어리 삭제에서 이미 정리됨.
        let removedBoardCards = growthBoards.filter { $0.childId == id }.flatMap { $0.cards }
        growthBoards.removeAll { $0.childId == id }
        for card in removedBoardCards { cleanupBoardCardPhoto(card) }
        UserDefaults.standard.removeObject(forKey: "bl_board_section_\(id.uuidString)")   // 홈 섹션 제목 라벨 정리(좀비 부활·누적 방지)
        children.removeAll { $0.id == id }
        if selectedChildId == id { selectedChildId = children.first?.id }
        persistNow()   // 민감영역 — 지운 기록이 다음 실행에 부활하지 않도록 즉시 저장
    }

    /// 임신 상태 변경 (민감 영역 — 상실·일시중단 포함).
    /// `.loss` 전환 시 `pregnancyEndedInLoss` 이벤트를 발행해 권유 알림을 즉시 자동 차단한다.
    func updatePregnancyStatus(pregnancyId: UUID, to status: PregnancyStatus) {
        guard let idx = pregnancies.firstIndex(where: { $0.id == pregnancyId }) else { return }
        var updated = pregnancies[idx]
        updated.status = status
        pregnancies[idx] = updated
        // active를 벗어나면(상실·멈춤·출산) 검진 알림 토글을 끈다 — 알림은 이미 취소되는데
        // UI가 "켜짐"으로 거짓 표시되고, 재개해도 재예약되지 않아 무음 상태가 되던 문제 방지.
        if status != .active && checkupRemindersOn {
            CheckupReminderService.cancel(pregnancyId: pregnancyId)
            checkupRemindersOn = false
        }
        if status == .loss {
            bus.publish(.pregnancyEndedInLoss(pregnancyId: pregnancyId))
        } else if status == .paused {
            // 기록 멈춤 — 상실은 아니지만 주차 알림·태아 가이드·권유 알림을 즉시 중단
            bus.publish(.pregnancyPaused(pregnancyId: pregnancyId))
        }
    }

    /// 임신 온보딩 — active 임신 생성·추가.
    /// 이미 활성 임신이 있으면 중복 생성하지 않는다(둘째 active의 데이터가 보이지 않게 되는 문제 방지).
    func startPregnancy(lmp: Date?, edd: Date?, nickname: String?) {
        guard !pregnancies.contains(where: { $0.status == .active }) else { return }
        let preg = Pregnancy(id: UUID(), lmpDate: lmp, eddDate: edd, fetusCount: 1,
                             nickname: nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
                             clinic: nil, status: .active)
        pregnancies.append(preg)
        refreshBadgeAwards()
        persistNow()   // 임신 시작 핵심 생성 — 유실 방지
    }

    /// 임신 정보(태명·예정일·LMP) 수정.
    func updatePregnancy(id: UUID, nickname: String?, lmp: Date?, edd: Date?) {
        guard let idx = pregnancies.firstIndex(where: { $0.id == id }) else { return }
        pregnancies[idx].nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        pregnancies[idx].lmpDate = lmp
        pregnancies[idx].eddDate = edd
        // 예정일/LMP가 바뀌면 켜져 있던 검진 알림을 새 기준으로 재예약 — 안 하면 옛 날짜 알림이 그대로 발송.
        if checkupRemindersOn, pregnancies[idx].status == .active {
            CheckupReminderService.cancel(pregnancyId: id)
            let ref = CheckupReminderService.referenceLMP(lmpDate: lmp, eddDate: edd)
            Task { @MainActor in _ = await CheckupReminderService.enable(pregnancyId: id, lmp: ref) }
        }
    }

    /// 임신 기록 삭제 (관련 로그·배 사진·검진 키 정리).
    /// 민감영역: 상실 후 삭제하는 사용자는 배 사진도 기기에서 지워졌다고 기대한다.
    func deletePregnancy(id: UUID) {
        // 민감영역 — 예약된 산전검진 알림을 즉시 취소한다. 상실 후 기록을 통째로 삭제하는
        // 사용자에게 며칠~몇 주 뒤 검진 권유 알림이 발송되는 일을 막는다(기록 멈춤 원칙).
        CheckupReminderService.cancel(pregnancyId: id)
        for log in pregnancyLogs where log.pregnancyId == id {
            if let ref = log.photoRef { PhotoStore.delete(ref) }
        }
        let prefix = "\(id.uuidString)|"
        checkupDoneKeys = checkupDoneKeys.filter { !$0.hasPrefix(prefix) }
        pregnancyLogs.removeAll { $0.pregnancyId == id }
        pregnancies.removeAll { $0.id == id }
        // 남은 활성 임신이 없으면 검진 알림 토글도 끈다(거짓 '켜짐' 표시 방지).
        if checkupRemindersOn && !pregnancies.contains(where: { $0.status == .active }) {
            checkupRemindersOn = false
        }
        persistNow()   // 민감영역 — 지운 임신 기록 부활 방지
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
            // 출산 완료 — 검진 알림 정리(임신 종료)
            if checkupRemindersOn {
                CheckupReminderService.cancel(pregnancyId: pregnancyId)
                checkupRemindersOn = false
            }
            // 배 사진 → 성장 사진 승계: 태아 시절 배 사진을 아이 타임라인에 잇는다
            // (CLAUDE.md 핵심 데이터 전환 — "끊김 없는 하나의 여정"). 원본은 임신 기록에 그대로 보존.
            carryOverBellyPhotos(from: pregnancy, to: child)
            bus.publish(.recordSaved(childId: child.id))
            refreshBadgeAwards()
            persistNow()   // 핵심 데이터 전환(출산 승계) — 디바운스 전 종료에도 유실 방지
            return .success(child)
        }
    }

    /// 임신 기록의 배 사진을 아이 다이어리로 승계한다.
    /// - 날짜: LMP 기준 추정 임신일(lmp + 주차×7)로 설정해 출생 이전에 시간순 배치. LMP가 없으면 원본 날짜.
    ///         어떤 경우든 출생일 이전으로 클램프해 타임라인이 출생 뒤로 새지 않게 한다.
    /// - 사진: 원본 파일을 복제(PhotoStore.copy)해 임신/성장 기록의 파일 수명을 분리(한쪽 삭제가 다른 쪽을 깨지 않게).
    private func carryOverBellyPhotos(from pregnancy: Pregnancy, to child: Child) {
        let cal = Calendar(identifier: .gregorian)
        let bellies = pregnancyLogs
            .filter { $0.pregnancyId == pregnancy.id && $0.kind == .belly }
            .sorted { $0.value < $1.value }
        guard !bellies.isEmpty else { return }
        // 자체 멱등성 — 이미 이 임신에서 이 아이로 옮겨온 기록이 있으면 중복 생성 금지.
        // 구조적 필드(carriedFromPregnancyId)로 판정 → 사용자가 캡션을 수정해도 안전(이전 content 접미사 방식의 취약점 제거).
        let pregKey = pregnancy.id.uuidString
        if diaryEntries.contains(where: { $0.childId == child.id && $0.carriedFromPregnancyId == pregKey }) {
            return
        }
        // 출생일 직전(하루 전 정오)을 상한선으로 둬 출생 기록보다 항상 앞서게 한다.
        let birthDay = cal.startOfDay(for: child.birthDate)
        let upperBound = cal.date(byAdding: .day, value: -1, to: birthDay)
            .flatMap { cal.date(bySettingHour: 12, minute: 0, second: 0, of: $0) } ?? child.birthDate

        for log in bellies {
            guard let copiedRef = PhotoStore.copy(log.photoRef) else { continue }
            // value(주차)가 NaN/Inf/비정상이면 Int() 변환이 트랩될 수 있어 방어 후 0~45주로 클램프.
            let week = log.value.isFinite ? min(max(Int(log.value), 0), 45) : 0
            // 승계 날짜 추정 — 주차 순서를 항상 보존(여러 배사진을 출산 후 한 번에 백필해도 뭉치지 않게).
            //  LMP 있으면 LMP+주차, 없으면 예정일(EDD) 역산, 둘 다 없으면 상한선에서 주차순으로 분산.
            let estimated: Date
            if let lmp = pregnancy.lmpDate {
                estimated = cal.date(byAdding: .day, value: week * 7, to: lmp) ?? upperBound
            } else if let edd = pregnancy.eddDate {
                estimated = cal.date(byAdding: .day, value: -((40 - week) * 7), to: edd) ?? upperBound
            } else {
                estimated = cal.date(byAdding: .day, value: -(45 - week), to: upperBound) ?? upperBound
            }
            let date = min(estimated, upperBound)
            let entry = DiaryEntry(
                childId: child.id,
                date: date,
                recordType: "photo",
                content: "임신 \(week)주차 · 태아 시절",
                photoRef: copiedRef,
                photoRefs: [copiedRef],
                carriedFromPregnancyId: pregKey
            )
            diaryEntries.append(entry)
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
    @discardableResult
    func addDiaryEntry(
        childId: UUID,
        content: String?,
        milestone: String?,
        photoRef: String?,
        photoRefs: [String] = [],
        videoRef: String? = nil
    ) -> UUID {
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
        // 이정표 달성 이벤트 발행(CLAUDE.md 공통 이벤트 버스) — 기능 간 연결의 표준 훅.
        if let milestone, !milestone.trimmingCharacters(in: .whitespaces).isEmpty {
            bus.publish(.milestoneAchieved(childId: childId, milestone: milestone))
        }
        refreshBadgeAwards()
        persistNow()   // 사용자 명시 저장(2탭 기록) — 디바운스 대기 중 종료에도 유실 방지
        return entry.id
    }

    /// 성장 기록을 추가한다.
    ///
    /// - Parameters:
    ///   - childId:              대상 아이 ID
    ///   - heightCm:             신장(cm) (옵션)
    ///   - weightKg:             체중(kg) (옵션)
    ///   - headCircumferenceCm:  두위(cm) (옵션)
    ///   - date:                 측정일 (기본 = 지금). 과거 검진 기록 소급 입력용.
    func addGrowthRecord(
        childId: UUID,
        heightCm: Double?,
        weightKg: Double?,
        headCircumferenceCm: Double?,
        date: Date = Date()
    ) {
        let record = GrowthRecord(
            id: UUID(),
            childId: childId,
            date: date,
            heightCm: heightCm,
            weightKg: weightKg,
            headCircumferenceCm: headCircumferenceCm
        )
        growthRecords.append(record)
        bus.publish(.recordSaved(childId: childId))
        refreshBadgeAwards()
        persistNow()
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
        persistNow()
    }

    /// 지출 항목을 수정한다(금액·카테고리·날짜·메모). 0 이하 금액 무시.
    func updateExpense(id: UUID, amount: Int, category: ExpenseCategory, date: Date, memo: String?) {
        guard amount > 0, let idx = expenses.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = memo?.trimmingCharacters(in: .whitespacesAndNewlines)
        var e = expenses[idx]
        e.amount = amount
        e.category = category
        e.date = date
        e.memo = (trimmed?.isEmpty ?? true) ? nil : trimmed
        expenses[idx] = e
        persistNow()   // 수정 즉시 저장 — 디바운스 대기 중 종료에도 유실 방지
    }

    /// 지출 항목을 삭제한다.
    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
        persistNow()   // 지운 지출이 종료 후 부활하지 않도록 즉시 저장
    }

    // MARK: - 정부지원금 '받음' 체크 (영속)

    func isSubsidyClaimed(childId: UUID?, id: String) -> Bool {
        guard let childId else { return false }
        return claimedSubsidyIds.contains("\(childId.uuidString)|\(id)")
    }

    /// 지원금 '받음' 상태를 토글한다(받았다고 체크 ↔ 해제). 아이별로 분리(다자녀: 한 아이 체크가 형제에 전염 방지).
    func toggleSubsidyClaimed(childId: UUID?, id: String) {
        guard let childId else { return }
        let key = "\(childId.uuidString)|\(id)"
        if claimedSubsidyIds.contains(key) { claimedSubsidyIds.remove(key) }
        else { claimedSubsidyIds.insert(key) }
        persistNow()
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

    // MARK: - 임신 기록 (체중·배 사진)

    /// 체중 기록을 추가한다 (kg). 0 이하 무시.
    func addPregnancyWeight(pregnancyId: UUID, kg: Double, on date: Date = Date()) {
        guard kg > 0 else { return }
        pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: date,
                                          kind: .weight, value: kg))
        persistNow()
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
        persistNow()
    }

    /// 임신 메모를 추가한다(빠른기록 임신 모드 — 데이터 손실 방지).
    func addPregnancyMemo(pregnancyId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: Date(),
                                          kind: .memo, value: 0, note: trimmed))
        persistNow()
    }

    /// 특정 임신의 메모를 최신순으로 반환한다.
    func pregnancyMemos(pregnancyId: UUID) -> [PregnancyLog] {
        pregnancyLogs
            .filter { $0.pregnancyId == pregnancyId && $0.kind == .memo }
            .sorted { $0.date > $1.date }
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

    /// 사진 앱 자동 저장 대상 — 영구 보존 가치가 있는 사진 refs(다이어리·배사진·아이 프로필).
    /// 마켓 등 일시 사진은 제외(개인 사진 앨범 오염 방지).
    func memoryPhotoRefs() -> [String] {
        var refs: [String] = []
        for e in diaryEntries { refs.append(contentsOf: e.photoRefList) }
        for log in pregnancyLogs where log.kind == .belly { if let r = log.photoRef, !r.isEmpty { refs.append(r) } }
        for c in children { if let r = c.profileImageRef, !r.isEmpty { refs.append(r) } }
        for b in growthBoards { for card in b.cards where card.sourceEntryId == nil {
            if let r = card.photoRef, !r.isEmpty { refs.append(r) }   // 보드 전용 사진만(참조분은 위에서 이미 포함)
        }}
        return refs
    }

    // MARK: - 성장 보드 CRUD (무료 1개 / Pro 최대 100개 — UI에서 게이팅)

    /// 아이의 모든 보드(최근 수정 순). 없으면 빈 배열.
    func boards(for childId: UUID) -> [GrowthBoard] {
        growthBoards.filter { $0.childId == childId }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 보드 id로 조회(없으면 nil).
    func board(id: UUID) -> GrowthBoard? {
        growthBoards.first(where: { $0.id == id })
    }

    /// 아이의 대표 보드 id — isPrimary 우선, 미설정(레거시/다운그레이드)이면 가장 먼저 만든 보드.
    func primaryBoardId(for childId: UUID) -> UUID? {
        let cb = growthBoards.filter { $0.childId == childId }   // 삽입(생성) 순서 보존
        return cb.first(where: { $0.isPrimary })?.id ?? cb.first?.id
    }

    /// 이 보드를 편집할 수 있는가 — Pro면 모두, 무료면 대표 보드만.
    func isBoardEditable(_ boardId: UUID, childId: UUID) -> Bool {
        isPro || primaryBoardId(for: childId) == boardId
    }

    /// 새 보드를 더 만들 수 있는가 — 무료는 0개일 때만(대표 1개), Pro는 최대 100개.
    func canCreateBoard(for childId: UUID) -> Bool {
        let count = growthBoards.filter { $0.childId == childId }.count
        return isPro ? count < GrowthBoard.maxPerChild : count == 0
    }

    /// 대표 보드 변경 — Pro 전용. 같은 아이의 다른 보드 isPrimary를 모두 끄고 대상만 켠다.
    func setPrimaryBoard(childId: UUID, boardId: UUID) {
        guard isPro else { return }
        guard growthBoards.contains(where: { $0.id == boardId && $0.childId == childId }) else { return }
        for i in growthBoards.indices where growthBoards[i].childId == childId {
            growthBoards[i].isPrimary = (growthBoards[i].id == boardId)
        }
        persistNow()
    }

    /// 새 보드를 만들어 저장하고 반환. 기본 이름은 "성장 보드 N"(이미 있는 개수+1) — 사용자가 변경 가능.
    @discardableResult
    func createBoard(childId: UUID, title: String = "") -> GrowthBoard {
        var t = title
        if t.isEmpty {   // 삭제 후 재생성에도 이름이 겹치지 않게 빈 번호를 찾는다.
            let existing = Set(growthBoards.filter { $0.childId == childId }.map { $0.title })
            var n = existing.count + 1
            while existing.contains("성장 보드 \(n)") { n += 1 }
            t = "성장 보드 \(n)"
        }
        // 그 아이의 첫 보드는 대표(무료 편집 가능 보드)로 지정.
        let isFirst = growthBoards.allSatisfy { $0.childId != childId }
        let b = GrowthBoard(childId: childId, title: t, isPrimary: isFirst)
        growthBoards.append(b)
        persistNow()
        return b
    }

    /// 보드 1개 삭제 — 먼저 제거한 뒤 보드 전용 사진 정리(공유 사진은 ref-count로 보존).
    func deleteBoard(id: UUID) {
        guard let i = growthBoards.firstIndex(where: { $0.id == id }) else { return }
        let removed = growthBoards.remove(at: i)
        for card in removed.cards { cleanupBoardCardPhoto(card) }
        // 대표를 지웠고 남은 보드가 있으면, 가장 먼저 만든 보드를 새 대표로 '고정'(순서 의존 아닌 영속 플래그).
        if removed.isPrimary, let n = growthBoards.firstIndex(where: { $0.childId == removed.childId }) {
            growthBoards[n].isPrimary = true
        }
        persistNow()
    }

    /// 보드 저장 — 보드 자체 id로 업서트(아이당 여러 개 가능). 드래그 등은 화면 로컬 상태로 처리하고 커밋 시 호출.
    /// `immediate`=true(기본)는 추가·삭제·내용편집처럼 유실되면 안 되는 변경용(즉시 저장).
    /// 드래그·회전 등 초당 수십 번 일어나는 기하 변경은 `immediate:false`로 호출 — @Published 변경이
    /// 0.5s debounce 자동저장에 위임돼, 매 제스처마다 전체 상태를 동기 직렬화하던 쓰기 폭주를 막는다.
    func upsertBoard(_ board: GrowthBoard, immediate: Bool = true) {
        guard !loadDidFail else { return }
        var b = board; b.updatedAt = Date()
        if let i = growthBoards.firstIndex(where: { $0.id == b.id }) { growthBoards[i] = b }
        else {
            // 없던 보드를 새로 추가(create) — 단, 아이가 존재할 때만. 삭제된 보드가 뒤늦은 커밋으로 부활하는 것 방지.
            guard children.contains(where: { $0.id == b.childId }) else { return }
            growthBoards.append(b)
        }
        if immediate { persistNow() }
    }

    /// 보드 전용 사진만 정리(기록 참조 카드의 사진은 원본 소유라 보존). 카드/보드 삭제 시 호출.
    /// ⚠️ 호출 전에 대상 카드는 이미 growthBoards에서 제거돼 있어야 한다 — 같은 사진을 다른 보드/카드가
    /// 아직 참조하면(같은 기록 사진을 여러 보드에 넣은 뒤 기록 삭제로 승계된 경우 등) 삭제하지 않는다(공유 사진 보호).
    func cleanupBoardCardPhoto(_ card: BoardCard) {
        guard let ref = card.photoRef, !ref.isEmpty, card.sourceEntryId == nil else { return }
        let inBoards  = growthBoards.contains { $0.cards.contains { $0.photoRef == ref } }
        // 같은 파일을 기록(일기)·아이 프로필이 아직 쓰고 있으면 삭제 금지 — 정상 경로엔 없지만
        // 익스포트/병합·승계 엣지에서 살아있는 사진을 지우지 않도록 방어(데이터 보존 우선).
        let inDiary   = diaryEntries.contains { $0.photoRefList.contains(ref) || $0.photoRef == ref }
        let inProfile = children.contains { $0.profileImageRef == ref }
        if !inBoards && !inDiary && !inProfile { PhotoStore.delete(ref) }
    }

    /// children에 없는 childId의 보드(부분/옛 백업 복원 등으로 생긴 고아)를 제거하고 보드전용 사진도 정리.
    /// 로드·복원 직후 호출 — 보이지 않는 고아 보드가 백업·메모리참조·익스포트를 오염시키지 않게.
    private func pruneOrphanBoards() {
        // 안전장치: children가 비었는데 보드가 있으면 '부분/실패 디코드' 신호일 수 있다 →
        // 사진을 지우지 않는다(아이 전체 삭제는 deleteChild가 이미 보드까지 정리하므로 정상 경로에선 도달 안 함).
        guard !children.isEmpty else { return }
        let liveIds = Set(children.map { $0.id })
        let orphans = growthBoards.filter { !liveIds.contains($0.childId) }
        guard !orphans.isEmpty else { return }
        for b in orphans { for c in b.cards { cleanupBoardCardPhoto(c) } }
        growthBoards.removeAll { !liveIds.contains($0.childId) }
    }

    /// 대표 플래그 정규화 — 보드가 있는데 대표(isPrimary)가 하나도 없는 아이는 가장 먼저 만든 보드를 대표로 고정.
    /// 레거시(플래그 없던 시절)·복원 시 배열 순서에 의존하지 않고 '편집 가능 보드 1개'를 영속 보장한다.
    private func normalizePrimaryFlags() {
        for cid in Set(growthBoards.map { $0.childId }) {
            let idxs = growthBoards.indices.filter { growthBoards[$0].childId == cid }
            guard let first = idxs.first else { continue }
            let primaries = idxs.filter { growthBoards[$0].isPrimary }
            if primaries.isEmpty {
                growthBoards[first].isPrimary = true                 // 대표 없음 → 첫(가장 먼저 만든) 보드를 대표로
            } else if primaries.count > 1 {
                // 대표가 둘 이상(손상·병합 백업) → 첫 대표만 남기고 나머지 해제(불변식: 아이당 대표 1개).
                for j in primaries.dropFirst() { growthBoards[j].isPrimary = false }
            }
        }
    }

    /// 삭제되는 기록(entryId)의 사진 중, 성장 보드 카드가 참조 중인 것을 보드 소유로 승계한다.
    /// 승계된 카드는 sourceEntryId를 비워 보드가 파일을 소유(이후 보드 카드 삭제 시 정상 정리)하게 하고,
    /// 호출부는 해당 ref를 삭제·툼스톤하지 않는다. 반환값 = 승계되어 보존해야 하는 ref 집합.
    private func adoptBoardPhotos(referencing entryId: UUID, refs: [String]) -> Set<String> {
        guard !refs.isEmpty else { return [] }
        let eid = entryId.uuidString
        let refSet = Set(refs)
        var adopted = Set<String>()
        for bi in growthBoards.indices {
            for ci in growthBoards[bi].cards.indices {
                let card = growthBoards[bi].cards[ci]
                guard card.sourceEntryId == eid, let r = card.photoRef, !r.isEmpty, refSet.contains(r) else { continue }
                growthBoards[bi].cards[ci].sourceEntryId = nil   // 보드가 파일 소유 → 원본 삭제/툼스톤 금지
                adopted.insert(r)
            }
        }
        return adopted
    }

    /// 다이어리 항목을 삭제한다. 연결된 로컬 사진도 함께 정리한다.
    func deleteDiaryEntry(id: UUID) {
        if let entry = diaryEntries.first(where: { $0.id == id }) {
            var refs = entry.photoRefList
            if refs.isEmpty, let r = entry.photoRef, !r.isEmpty { refs = [r] }
            // 성장 보드가 이 기록 사진을 참조 중이면, 파일을 보드 소유로 승계하고 삭제·툼스톤하지 않는다.
            // (안 하면 보드 카드가 빈칸이 되고, 툼스톤 때문에 복원으로도 되살아나지 못함 — 데이터 유실.)
            let adopted = adoptBoardPhotos(referencing: id, refs: refs)
            for ref in refs where !adopted.contains(ref) { PhotoStore.delete(ref) }
            PhotoStore.delete(entry.videoRef)
        }
        diaryEntries.removeAll { $0.id == id }
        likedDiaryIds.remove(id.uuidString)
        diaryComments[id.uuidString] = nil
        cleanupSharedFeedPosts([id])   // 가족 피드(서버)에 공유됐으면 함께 삭제
        // 삭제된 기록의 "N년 전 오늘" 추억 알림 취소 — 지운 기록이 알림으로
        // 되살아나면 안 된다(상실 등 민감 상황 포함).
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["memory-\(id.uuidString)"]
        )
        // 민감영역 — 지운 기록이 강제종료(0.5s debounce 이전)로 부활하지 않게, 보드 사진 승계와 함께 즉시 저장.
        persistNow()
    }

    /// 삭제되는 기록 중 가족 피드(서버 R2)에 공유된 것을 함께 제거 — 지운 사진이 가족/서버에 남지 않게.
    /// (postId = 기록 entry.id. 로컬 공유 표식이 있는 것만 시도 — deletePostFully는 작성자 본인만 삭제.)
    private func cleanupSharedFeedPosts(_ ids: [UUID]) {
        let shared = ids.map(\.uuidString).filter { sharedFeedEntryIds.contains($0) }
        guard !shared.isEmpty else { return }
        for pid in shared { unmarkFeedShared(pid) }
        Task { for pid in shared { await FamilyFeedBackend.deletePostFully(postId: pid) } }
    }

    /// 다이어리 항목 수정 (캡션·이정표). 사진/영상은 유지.
    func updateDiaryEntry(id: UUID, content: String?, milestone: String?) {
        guard let idx = diaryEntries.firstIndex(where: { $0.id == id }) else { return }
        let childId = diaryEntries[idx].childId
        diaryEntries[idx].content = content
        diaryEntries[idx].milestone = milestone
        bus.publish(.recordSaved(childId: childId))
        persistNow()   // 수정 즉시 저장 — 디바운스 대기 중 종료에도 유실 방지
    }

    /// 성장 기록을 삭제한다.
    func deleteGrowthRecord(id: UUID) {
        growthRecords.removeAll { $0.id == id }
        persistNow()   // 지운 성장기록이 종료 후 부활하지 않도록 즉시 저장
    }

    // MARK: - 접종 병원 / 산전검진 완료

    func vaccineHospital(childId: UUID, vaccineId: String) -> String? {
        vaccineHospitals["\(childId.uuidString)|\(vaccineId)"]
    }
    func setVaccineHospital(childId: UUID, vaccineId: String, hospital: String?) {
        let key = "\(childId.uuidString)|\(vaccineId)"
        let trimmed = hospital?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { vaccineHospitals[key] = trimmed }
        else { vaccineHospitals[key] = nil }
    }
    func isCheckupDone(pregnancyId: UUID, checkupId: String) -> Bool {
        checkupDoneKeys.contains("\(pregnancyId.uuidString)|\(checkupId)")
    }
    func toggleCheckupDone(pregnancyId: UUID, checkupId: String) {
        let key = "\(pregnancyId.uuidString)|\(checkupId)"
        if checkupDoneKeys.contains(key) { checkupDoneKeys.remove(key) }
        else { checkupDoneKeys.insert(key) }
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

    func deleteComment(entryId: UUID, at index: Int) {
        let key = entryId.uuidString
        guard var list = diaryComments[key], list.indices.contains(index) else { return }
        list.remove(at: index)
        diaryComments[key] = list.isEmpty ? nil : list
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
