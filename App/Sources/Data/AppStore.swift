import Foundation
import Combine
import UserNotifications   // 기록 삭제 시 "N년 전 오늘" 추억 알림 취소용
import WidgetKit           // 저장 직후 위젯 타임라인 갱신용

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
    /// Pro 구독 여부 — 가족 피드(좋아요·댓글·가족공유)의 단일 게이트.
    /// 지금은 로컬 플래그(설정의 개발용 토글로 두 모드 검증). 출시 시 StoreKit 엔타이틀먼트로 대체.
    @Published var isPro: Bool = UserDefaults.standard.bool(forKey: "bl_is_pro") {
        didSet { UserDefaults.standard.set(isPro, forKey: "bl_is_pro") }
    }
    /// 가족 피드 변경 신호(공유 완료 등). 증가 시 타임라인이 가족 반응을 다시 읽는다(메모리 전용).
    @Published var familyFeedVersion = 0
    /// 가족 공유 의도/진행 중인 기록 id — 업로드가 끝나기 전에도 카드가 즉시 '공유 중'을 보이게(메모리 전용).
    @Published var sharedFeedEntryIds: Set<String> = []
    func markFeedShared(_ id: String)   { sharedFeedEntryIds.insert(id) }
    func unmarkFeedShared(_ id: String) { sharedFeedEntryIds.remove(id) }

    // MARK: - 내 동네 (당근식 대표 동네 — 마켓·크루 기준. 주변/응급은 실시간 GPS)
    /// 내 동네(행정동 이름) — 최대 2개. 현재 위치에서만 추가(인증) → 어뷰징·스팸 방지.
    @Published var myNeighborhoods: [String] =
        (UserDefaults.standard.array(forKey: "bl_my_hoods") as? [String]) ?? [] {
        didSet { UserDefaults.standard.set(myNeighborhoods, forKey: "bl_my_hoods") }
    }
    /// 마켓·크루에 적용 중인 내 동네 인덱스(0/1).
    @Published var selectedHoodIndex: Int = UserDefaults.standard.integer(forKey: "bl_selected_hood") {
        didSet { UserDefaults.standard.set(selectedHoodIndex, forKey: "bl_selected_hood") }
    }
    /// 현재 선택된 내 동네(없으면 nil → 화면이 GPS 폴백/설정 유도).
    var selectedHood: String? {
        guard !myNeighborhoods.isEmpty else { return nil }
        return myNeighborhoods[min(max(0, selectedHoodIndex), myNeighborhoods.count - 1)]
    }
    /// 내 동네 추가(현재 위치 기준 인증). 최대 2개·중복 불가. 추가하면 자동 선택.
    func addNeighborhood(_ name: String) {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t != "우리 동네", !myNeighborhoods.contains(t), myNeighborhoods.count < 2 else { return }
        myNeighborhoods.append(t)
        selectedHoodIndex = myNeighborhoods.count - 1
    }
    func removeNeighborhood(at index: Int) {
        guard myNeighborhoods.indices.contains(index) else { return }
        myNeighborhoods.remove(at: index)
        if selectedHoodIndex >= myNeighborhoods.count { selectedHoodIndex = max(0, myNeighborhoods.count - 1) }
    }
    func selectNeighborhood(_ index: Int) {
        guard myNeighborhoods.indices.contains(index) else { return }
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
                try? self.persistence?.save(self.snapshot())
                // 저장 직후 위젯 타임라인 갱신 — 호출하지 않으면 위젯이 시스템 재량
                // 주기(수 시간)까지 스테일 데이터를 표시한다.
                WidgetCenter.shared.reloadAllTimelines()
            }
            .store(in: &cancellables)
    }

    /// 즉시 저장 — 백그라운드 전환/복원 직후 등 debounce(0.5s)를 기다릴 수 없는 시점용.
    /// (마지막 기록이 앱 강제종료로 유실되는 것을 방지)
    func persistNow() {
        guard !loadDidFail else { return }
        try? persistence?.save(snapshot())
        // 백그라운드 전환 등 즉시 저장 직후에도 위젯을 갱신해 최신 기록을 반영한다.
        WidgetCenter.shared.reloadAllTimelines()
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
            selectedChildId: selectedChildId
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
        // 저장된 선택 아이가 아직 존재하면 복원, 아니면 첫 아이로 폴백.
        selectedChildId    = state.selectedChildId.flatMap { id in children.contains(where: { $0.id == id }) ? id : nil }
        seedMarketIfNeeded()
        seedCrewIfNeeded()
        seedCrewPostsIfNeeded()
        // 손상 파일로 자동저장이 막혀 있던 경우(백업 복원 시나리오) — 복원본을 신뢰하고
        // 자동저장을 되살린 뒤 즉시 디스크에 기록한다. 안 하면 복원이 메모리에만 남아
        // 다음 실행에서 다시 손상 파일을 읽어 "복원했는데 또 사라짐"이 된다.
        loadDidFail = false
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
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: deletedEntryIds.map { "memory-\($0.uuidString)" }
        )
        diaryEntries.removeAll { $0.childId == id }
        growthRecords.removeAll { $0.childId == id }
        // 접종 완료 키·병원 메모 정리
        let prefix = "\(id.uuidString)|"
        vaccineCompletions = vaccineCompletions.filter { !$0.hasPrefix(prefix) }
        vaccineHospitals = vaccineHospitals.filter { !$0.key.hasPrefix(prefix) }
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
    }

    /// 임신 정보(태명·예정일·LMP) 수정.
    func updatePregnancy(id: UUID, nickname: String?, lmp: Date?, edd: Date?) {
        guard let idx = pregnancies.firstIndex(where: { $0.id == id }) else { return }
        pregnancies[idx].nickname = nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        pregnancies[idx].lmpDate = lmp
        pregnancies[idx].eddDate = edd
    }

    /// 임신 기록 삭제 (관련 로그·배 사진·검진 키 정리).
    /// 민감영역: 상실 후 삭제하는 사용자는 배 사진도 기기에서 지워졌다고 기대한다.
    func deletePregnancy(id: UUID) {
        for log in pregnancyLogs where log.pregnancyId == id {
            if let ref = log.photoRef { PhotoStore.delete(ref) }
        }
        let prefix = "\(id.uuidString)|"
        checkupDoneKeys = checkupDoneKeys.filter { !$0.hasPrefix(prefix) }
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

    // MARK: - 정부지원금 '받음' 체크 (영속)

    func isSubsidyClaimed(id: String) -> Bool {
        claimedSubsidyIds.contains(id)
    }

    /// 지원금 '받음' 상태를 토글한다(받았다고 체크 ↔ 해제).
    func toggleSubsidyClaimed(id: String) {
        if claimedSubsidyIds.contains(id) { claimedSubsidyIds.remove(id) }
        else { claimedSubsidyIds.insert(id) }
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

    /// 임신 메모를 추가한다(빠른기록 임신 모드 — 데이터 손실 방지).
    func addPregnancyMemo(pregnancyId: UUID, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pregnancyLogs.append(PregnancyLog(pregnancyId: pregnancyId, date: Date(),
                                          kind: .memo, value: 0, note: trimmed))
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
        // 삭제된 기록의 "N년 전 오늘" 추억 알림 취소 — 지운 기록이 알림으로
        // 되살아나면 안 된다(상실 등 민감 상황 포함).
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["memory-\(id.uuidString)"]
        )
    }

    /// 다이어리 항목 수정 (캡션·이정표). 사진/영상은 유지.
    func updateDiaryEntry(id: UUID, content: String?, milestone: String?) {
        guard let idx = diaryEntries.firstIndex(where: { $0.id == id }) else { return }
        let childId = diaryEntries[idx].childId
        diaryEntries[idx].content = content
        diaryEntries[idx].milestone = milestone
        bus.publish(.recordSaved(childId: childId))
    }

    /// 성장 기록을 삭제한다.
    func deleteGrowthRecord(id: UUID) {
        growthRecords.removeAll { $0.id == id }
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
