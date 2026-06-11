import Foundation

// MARK: - ChatMessage (마켓 로컬 채팅)

struct ChatMessage: Identifiable, Codable, Equatable, Hashable {
    var id: String = UUID().uuidString
    var text: String
    var mine: Bool
    var date: Date = Date()
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
        marketSeeded: Bool = false
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
    }

    // MARK: - Codable (하위 호환 디코딩)
    // 기존 저장 파일에 신규 키가 없어도 디코딩 실패하지 않도록 decodeIfPresent + 기본값 사용.

    enum CodingKeys: String, CodingKey {
        case pregnancies, children, growthRecords, diaryEntries, expenses, vaccineCompletions, pregnancyLogs
        case likedDiaryIds, diaryComments
        case marketItems, savedMarketIds, marketChats, marketSeeded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pregnancies    = try container.decode([Pregnancy].self, forKey: .pregnancies)
        children       = try container.decode([Child].self,     forKey: .children)
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

    /// JSON 파일에서 상태를 복원한다. 파일이 없으면 nil 반환.
    func load() throws -> PersistableState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistableState.self, from: data)
    }
}
