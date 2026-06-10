import Foundation

// MARK: - PersistableState

/// 앱 전체 인메모리 상태의 Codable 스냅샷.
/// Pregnancy·Child·GrowthRecord·DiaryEntry 는 이미 Codable(Models.swift 참조).
struct PersistableState: Codable, Equatable {
    var pregnancies: [Pregnancy]
    var children: [Child]
    var growthRecords: [GrowthRecord]
    var diaryEntries: [DiaryEntry]

    init(
        pregnancies: [Pregnancy] = [],
        children: [Child] = [],
        growthRecords: [GrowthRecord] = [],
        diaryEntries: [DiaryEntry] = []
    ) {
        self.pregnancies = pregnancies
        self.children = children
        self.growthRecords = growthRecords
        self.diaryEntries = diaryEntries
    }

    // MARK: - Codable (하위 호환 디코딩)
    // 기존 저장 파일에 growthRecords/diaryEntries 키가 없어도 디코딩 실패하지 않도록
    // decodeIfPresent + 기본값 [] 사용.

    enum CodingKeys: String, CodingKey {
        case pregnancies, children, growthRecords, diaryEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pregnancies    = try container.decode([Pregnancy].self, forKey: .pregnancies)
        children       = try container.decode([Child].self,     forKey: .children)
        growthRecords  = try container.decodeIfPresent([GrowthRecord].self, forKey: .growthRecords) ?? []
        diaryEntries   = try container.decodeIfPresent([DiaryEntry].self,   forKey: .diaryEntries)  ?? []
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
