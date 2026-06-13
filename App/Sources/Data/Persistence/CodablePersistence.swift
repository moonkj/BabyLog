import Foundation

// MARK: - ChatMessage (마켓 로컬 채팅)

struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var text: String
    var mine: Bool
    var date: Date = Date()
}

// 하위 호환 디코딩 — 신규 키 추가/누락에도 전체 상태 디코딩이 깨지지 않게(decodeIfPresent+기본값).
// ⚠️ 정책: 영속되는 모든 중첩 모델은 이 패턴을 따른다(필드 추가 시 구 저장파일 keyNotFound → 전체 데이터 소실 방지).
extension ChatMessage {
    enum CodingKeys: String, CodingKey { case id, text, mine, date }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id   = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        mine = try c.decodeIfPresent(Bool.self, forKey: .mine) ?? false
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
    }
}

// MARK: - TradeReport (거래 신고 + 증거 보존)

/// 거래 사고 신고 기록. 신고 시점의 대화를 스냅샷으로 보존하므로,
/// 매물/채팅이 이후 삭제돼도 증거가 유지된다(경찰 제출·분쟁 대응용).
/// 현재는 로컬 보관 — 백엔드 연결 시 서버 업로드로 확장(적법 절차 시 관리자 제출).
struct TradeReport: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var itemId: String
    var itemTitle: String
    var counterpartName: String
    var reason: String
    var note: String
    /// 신고 시점 대화 스냅샷(증거). 이후 원본 채팅이 삭제돼도 보존.
    var transcript: [ChatMessage]
    var createdAt: Date = Date()
    /// 서버 업로드 완료 여부(백엔드 연결 후 사용). 로컬에선 false 유지.
    var uploaded: Bool = false
}

// 하위 호환 디코딩 — 필드 추가에도 구 저장파일 전체가 깨지지 않게.
extension TradeReport {
    enum CodingKeys: String, CodingKey {
        case id, itemId, itemTitle, counterpartName, reason, note, transcript, createdAt, uploaded
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        itemId          = try c.decodeIfPresent(String.self, forKey: .itemId) ?? ""
        itemTitle       = try c.decodeIfPresent(String.self, forKey: .itemTitle) ?? ""
        counterpartName = try c.decodeIfPresent(String.self, forKey: .counterpartName) ?? ""
        reason          = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        note            = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        transcript      = try c.decodeIfPresent([ChatMessage].self, forKey: .transcript) ?? []
        createdAt       = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        uploaded        = try c.decodeIfPresent(Bool.self, forKey: .uploaded) ?? false
    }
}

// MARK: - PersistableState

/// 앱 전체 인메모리 상태의 Codable 스냅샷.
/// Pregnancy·Child·GrowthRecord·DiaryEntry 는 이미 Codable(Models.swift 참조).
struct PersistableState: Codable, Equatable {
    var pregnancies: [Pregnancy]
    var children: [Child]
    var growthRecords: [GrowthRecord]
    var diaryEntries: [DiaryEntry]
    var expenses: [Expense]
    /// 접종 완료 키 집합. 키 = "childId|vaccineId" (provider가 매 로드마다 새 UUID를 만들어
    /// VaccineRecord.id가 불안정하므로 안정 키로 영속한다).
    var vaccineCompletions: Set<String>
    var pregnancyLogs: [PregnancyLog]
    /// 좋아요한 다이어리 id 집합 (가족/조부모 모드 대비 — 현재 로컬)
    var likedDiaryIds: Set<String>
    /// 다이어리별 댓글 (key = 다이어리 uuid 문자열)
    var diaryComments: [String: [String]]
    // 마켓 (로컬 백본 — 추후 Supabase 동기화)
    var marketItems: [MarketItem]
    var savedMarketIds: Set<String>
    var marketChats: [String: [ChatMessage]]
    var marketSeeded: Bool
    // 크루 (로컬 백본)
    var crews: [CrewMeetup]
    var joinedCrewIds: Set<String>
    var crewSeeded: Bool
    /// 크루 그룹 가입 / 게시판 좋아요 (로컬)
    var joinedCrewGroupIds: Set<String>
    var likedCrewPostIds: Set<String>
    /// 접종 병원 (key="childId|vaccineId") / 산전검진 완료 (key="pregnancyId|checkupId")
    var vaccineHospitals: [String: String]
    var checkupDoneKeys: Set<String>
    // 크루 게시판/채팅 (로컬)
    var crewPosts: [CrewPost]
    var crewPostComments: [String: [String]]
    var crewChats: [String: [ChatMessage]]
    var crewPostSeeded: Bool
    /// 거래 신고 + 증거 보존 (로컬, 추후 서버 업로드)
    var tradeReports: [TradeReport]
    /// 사용자가 '받았다'고 체크한 정부지원금 id 집합 (가계부 지원금 완료 표시).
    var claimedSubsidyIds: Set<String>
    /// 현재 선택된 아이 — 다자녀 가정이 매 실행 첫 아이로 리셋되지 않도록 영속.
    var selectedChildId: UUID?

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
        marketItems: [MarketItem] = [],
        savedMarketIds: Set<String> = [],
        marketChats: [String: [ChatMessage]] = [:],
        marketSeeded: Bool = false,
        crews: [CrewMeetup] = [],
        joinedCrewIds: Set<String> = [],
        crewSeeded: Bool = false,
        joinedCrewGroupIds: Set<String> = [],
        likedCrewPostIds: Set<String> = [],
        vaccineHospitals: [String: String] = [:],
        checkupDoneKeys: Set<String> = [],
        crewPosts: [CrewPost] = [],
        crewPostComments: [String: [String]] = [:],
        crewChats: [String: [ChatMessage]] = [:],
        crewPostSeeded: Bool = false,
        tradeReports: [TradeReport] = [],
        claimedSubsidyIds: Set<String> = [],
        selectedChildId: UUID? = nil
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
        self.marketItems = marketItems
        self.savedMarketIds = savedMarketIds
        self.marketChats = marketChats
        self.marketSeeded = marketSeeded
        self.crews = crews
        self.joinedCrewIds = joinedCrewIds
        self.crewSeeded = crewSeeded
        self.joinedCrewGroupIds = joinedCrewGroupIds
        self.likedCrewPostIds = likedCrewPostIds
        self.vaccineHospitals = vaccineHospitals
        self.checkupDoneKeys = checkupDoneKeys
        self.crewPosts = crewPosts
        self.crewPostComments = crewPostComments
        self.crewChats = crewChats
        self.crewPostSeeded = crewPostSeeded
        self.tradeReports = tradeReports
        self.claimedSubsidyIds = claimedSubsidyIds
        self.selectedChildId = selectedChildId
    }

    // MARK: - Codable (하위 호환 디코딩)
    // 기존 저장 파일에 신규 키가 없어도 디코딩 실패하지 않도록 decodeIfPresent + 기본값 사용.

    enum CodingKeys: String, CodingKey {
        case pregnancies, children, growthRecords, diaryEntries, expenses, vaccineCompletions, pregnancyLogs
        case likedDiaryIds, diaryComments
        case marketItems, savedMarketIds, marketChats, marketSeeded
        case crews, joinedCrewIds, crewSeeded
        case joinedCrewGroupIds, likedCrewPostIds
        case vaccineHospitals, checkupDoneKeys
        case crewPosts, crewPostComments, crewChats, crewPostSeeded
        case tradeReports, claimedSubsidyIds, selectedChildId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 핵심 키도 strict decode 대신 decodeIfPresent — 키 하나 빠졌다고 전체 상태
        // 디코딩이 실패하면 나머지 멀쩡한 데이터까지 전부 소실되기 때문(다른 키와 정책 통일).
        pregnancies    = try container.decodeIfPresent([Pregnancy].self, forKey: .pregnancies) ?? []
        children       = try container.decodeIfPresent([Child].self,     forKey: .children)    ?? []
        growthRecords  = try container.decodeIfPresent([GrowthRecord].self, forKey: .growthRecords) ?? []
        diaryEntries   = try container.decodeIfPresent([DiaryEntry].self,   forKey: .diaryEntries)  ?? []
        expenses       = try container.decodeIfPresent([Expense].self,      forKey: .expenses)      ?? []
        vaccineCompletions = try container.decodeIfPresent(Set<String>.self, forKey: .vaccineCompletions) ?? []
        pregnancyLogs  = try container.decodeIfPresent([PregnancyLog].self, forKey: .pregnancyLogs) ?? []
        likedDiaryIds  = try container.decodeIfPresent(Set<String>.self, forKey: .likedDiaryIds) ?? []
        diaryComments  = try container.decodeIfPresent([String: [String]].self, forKey: .diaryComments) ?? [:]
        marketItems    = try container.decodeIfPresent([MarketItem].self, forKey: .marketItems) ?? []
        savedMarketIds = try container.decodeIfPresent(Set<String>.self, forKey: .savedMarketIds) ?? []
        marketChats    = try container.decodeIfPresent([String: [ChatMessage]].self, forKey: .marketChats) ?? [:]
        marketSeeded   = try container.decodeIfPresent(Bool.self, forKey: .marketSeeded) ?? false
        crews          = try container.decodeIfPresent([CrewMeetup].self, forKey: .crews) ?? []
        joinedCrewIds  = try container.decodeIfPresent(Set<String>.self, forKey: .joinedCrewIds) ?? []
        crewSeeded     = try container.decodeIfPresent(Bool.self, forKey: .crewSeeded) ?? false
        joinedCrewGroupIds = try container.decodeIfPresent(Set<String>.self, forKey: .joinedCrewGroupIds) ?? []
        likedCrewPostIds   = try container.decodeIfPresent(Set<String>.self, forKey: .likedCrewPostIds) ?? []
        vaccineHospitals   = try container.decodeIfPresent([String: String].self, forKey: .vaccineHospitals) ?? [:]
        checkupDoneKeys    = try container.decodeIfPresent(Set<String>.self, forKey: .checkupDoneKeys) ?? []
        crewPosts          = try container.decodeIfPresent([CrewPost].self, forKey: .crewPosts) ?? []
        crewPostComments   = try container.decodeIfPresent([String: [String]].self, forKey: .crewPostComments) ?? [:]
        crewChats          = try container.decodeIfPresent([String: [ChatMessage]].self, forKey: .crewChats) ?? [:]
        crewPostSeeded     = try container.decodeIfPresent(Bool.self, forKey: .crewPostSeeded) ?? false
        tradeReports       = try container.decodeIfPresent([TradeReport].self, forKey: .tradeReports) ?? []
        claimedSubsidyIds  = try container.decodeIfPresent(Set<String>.self, forKey: .claimedSubsidyIds) ?? []
        selectedChildId    = try container.decodeIfPresent(UUID.self, forKey: .selectedChildId)
    }
}

// MARK: - LocalPersistence

/// JSON 파일 기반 로컬 영속화 헬퍼.
///
/// - Note: CoreData + CloudKit 영속화는 후속 인프라 단계에서 추가 예정.
///   데이터 주권(표준 익스포트) 측면에서 현재 JSON 파일은 사용자가 직접 접근 가능한
///   Application Support 하위에 위치한다.
struct LocalPersistence {

    // MARK: Properties

    var url: URL

    // MARK: Init

    /// - Parameter url: 저장 경로. nil이면 `Application Support/BabyLog/state.json` 사용.
    init(url: URL? = nil) {
        if let url = url {
            self.url = url
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.url = appSupport
                .appendingPathComponent("BabyLog", isDirectory: true)
                .appendingPathComponent("state.json")
        }
    }

    // MARK: - App Group (위젯 공유)

    /// 위젯과 공유하는 App Group 컨테이너의 state.json.
    /// 엔타이틀먼트가 없으면(containerURL nil) 기본 경로로 안전 폴백.
    /// 그룹 파일이 없고 구(Application Support) 파일이 있으면 1회 마이그레이션 복사.
    static func appGroup(_ groupId: String = "group.com.babylog.app") -> LocalPersistence {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            return LocalPersistence()   // 엔타이틀먼트 미적용 폴백
        }
        let groupURL = container.appendingPathComponent("state.json")
        let legacy = LocalPersistence().url
        if !FileManager.default.fileExists(atPath: groupURL.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.copyItem(at: legacy, to: groupURL)
        }
        return LocalPersistence(url: groupURL)
    }

    // MARK: - Save

    /// 상태를 JSON 파일로 저장한다. 디렉토리가 없으면 자동 생성한다.
    func save(_ state: PersistableState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Load

    /// 디코딩 실패 등으로 신뢰할 수 없는 상태일 때, 원본을 타임스탬프 백업으로 복사해 보존한다.
    /// (자동저장이 원본을 덮어쓰기 전에 호출 — 데이터 복구 여지 확보)
    /// - Returns: 원본이 안전하게 보존됐는지. true면 호출부가 자동저장을 다시 허용해도 된다
    ///   (보존 실패 시에만 false — 원본을 덮어쓰면 복구 여지가 사라지므로 저장을 막아야 함).
    @discardableResult
    func backupCorrupt() -> Bool {
        // 원본 파일 자체가 없으면 보존할 것도 없다 → true (신규 저장 허용)
        guard FileManager.default.fileExists(atPath: url.path) else { return true }
        let ts = Int(Date().timeIntervalSince1970)
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("state.corrupt-\(ts).json")
        do {
            try FileManager.default.copyItem(at: url, to: backup)
            return true
        } catch {
            return false
        }
    }

    /// JSON 파일에서 상태를 복원한다. 파일이 없으면 nil 반환.
    func load() throws -> PersistableState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistableState.self, from: data)
    }
}
