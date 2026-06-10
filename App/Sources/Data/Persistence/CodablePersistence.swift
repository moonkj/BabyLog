import Foundation

// MARK: - PersistableState

/// 앱 전체 인메모리 상태의 Codable 스냅샷.
/// Pregnancy·Child 는 이미 Codable(Models.swift 참조).
struct PersistableState: Codable, Equatable {
    var pregnancies: [Pregnancy]
    var children: [Child]
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
