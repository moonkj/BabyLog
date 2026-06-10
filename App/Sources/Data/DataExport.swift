import Foundation

// MARK: - DataExporter

/// 데이터 주권 원칙(CLAUDE.md)에 따라 사용자가 언제든 표준 포맷으로
/// 데이터를 내보내고 다시 불러올 수 있도록 지원하는 순수 익스포트 유틸리티.
///
/// - Note: 현재 구현은 인메모리 Codable(PersistableState) 기반이다.
///   CoreData + CloudKit 실영속화 레이어가 추가되면,
///   NSManagedObjectContext → PersistableState 변환 어댑터를 별도 파일로 구현하고
///   이 타입의 API 계약(exportJSON / importJSON / exportToTemporaryFile)은 그대로 유지한다.
enum DataExporter {

    // MARK: - Encoder / Decoder Factory

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Export

    /// `PersistableState`를 사람이 읽을 수 있는 JSON `Data`로 직렬화한다.
    ///
    /// - 날짜: ISO 8601 문자열 (예: `"2025-03-01T00:00:00Z"`)
    /// - 서식: prettyPrinted + sortedKeys (버전 비교·diff 친화적)
    ///
    /// - Parameter state: 직렬화할 앱 전체 상태 스냅샷.
    /// - Returns: UTF-8 인코딩된 JSON `Data`.
    /// - Throws: `EncodingError` — 인코딩 실패 시.
    static func exportJSON(_ state: PersistableState) throws -> Data {
        return try makeEncoder().encode(state)
    }

    // MARK: - Import

    /// JSON `Data`를 `PersistableState`로 역직렬화한다.
    ///
    /// `exportJSON(_:)` → `importJSON(_:)` 라운드트립은 동일성을 보장한다:
    /// ```swift
    /// let exported = try DataExporter.exportJSON(original)
    /// let restored = try DataExporter.importJSON(exported)
    /// assert(original == restored)
    /// ```
    ///
    /// - Parameter data: `exportJSON(_:)`이 생성한 JSON `Data`.
    /// - Returns: 복원된 `PersistableState`.
    /// - Throws: `DecodingError` — 스키마 불일치·손상 데이터 등.
    static func importJSON(_ data: Data) throws -> PersistableState {
        return try makeDecoder().decode(PersistableState.self, from: data)
    }

    // MARK: - Temporary File Export

    /// 상태를 임시 디렉토리의 JSON 파일로 내보내고 그 `URL`을 반환한다.
    ///
    /// 파일명 형식: `babylog-export-yyyyMMdd.json` (현재 기기 로컬 시각 기준).
    /// `FileManager.default.temporaryDirectory`에 기록되므로, 시스템이 임의로
    /// 제거할 수 있다. 공유 시트(UIActivityViewController)에 즉시 전달하거나
    /// 사용자가 선택한 위치로 복사한 뒤 파일을 삭제하는 것을 권장한다.
    ///
    /// - Parameter state: 내보낼 앱 전체 상태 스냅샷.
    /// - Returns: 임시 파일 `URL`.
    /// - Throws: `EncodingError` 또는 파일 쓰기 오류.
    static func exportToTemporaryFile(_ state: PersistableState) throws -> URL {
        let jsonData = try exportJSON(state)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let fileName = "babylog-export-\(dateString).json"

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try jsonData.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
