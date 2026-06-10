// DataExportTests.swift
// BabyLogTests
//
// QA — DataExporter.exportJSON(_:) / importJSON(_:) 라운드트립 및
//       exportToTemporaryFile 파일 생성·읽기 계약 검증
//
// ===== 코더와 어긋날 수 있는 지점 =====
//
// [1] DataExporter 타입이 아직 존재하지 않는다. 코더가 아래 계약대로 구현해야 컴파일된다.
//     최소 계약:
//       enum DataExporter {
//           /// PersistableState → JSON Data 변환. 실패 시 throw.
//           static func exportJSON(_ state: PersistableState) throws -> Data
//
//           /// JSON Data → PersistableState 복원. 실패 시 throw.
//           static func importJSON(_ data: Data) throws -> PersistableState
//
//           /// PersistableState를 임시 디렉토리에 JSON 파일로 저장하고 URL을 반환.
//           /// 파일 이름 규칙: "babylog-export-<timestamp>.json" (코더 재량).
//           static func exportToTemporaryFile(_ state: PersistableState) throws -> URL
//       }
//
// [2] PersistableState.Equatable 동일성은 모든 프로퍼티(pregnancies, children) 배열의
//     순서 포함 동일성을 요구한다. JSONEncoder가 배열 순서를 보존하므로 일반적으로 안전하지만
//     코더가 Set 기반 저장을 쓰면 순서가 달라질 수 있다.
//
// [3] Date 직렬화: exportJSON이 ISO 8601을 사용할 것으로 가정한다.
//     코더가 timeIntervalSince1970(Double)을 사용하면 부동소수점 오차로
//     Equatable 비교 실패 가능성이 있다. ISO 8601 권장.
//
// [4] exportToTemporaryFile의 파일 이름 패턴은 코더 재량이지만
//     .json 확장자를 가져야 한다는 것을 테스트로 검증한다.
//
// [5] tearDown에서 임시파일을 삭제한다. exportToTemporaryFile이 예외를 던지면
//     tempExportURL이 nil로 유지되어 tearDown이 안전하게 skip한다.
//
// [6] PersistableState는 현재 { pregnancies: [Pregnancy], children: [Child] }만 포함.
//     코더가 VaccineRecord 등 다른 필드를 추가하면 fixture를 갱신해야 한다.

import XCTest
@testable import BabyLog

final class DataExportTests: XCTestCase {

    // MARK: - 프로퍼티

    /// exportToTemporaryFile 테스트에서 생성된 임시파일 URL (tearDown에서 삭제)
    private var tempExportURL: URL?

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        tempExportURL = nil
    }

    override func tearDown() {
        // 임시파일 정리 [주의 §5]
        if let url = tempExportURL, FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        tempExportURL = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private var seoulCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func d(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = seoulCalendar
        fmt.timeZone = TimeZone(identifier: "Asia/Seoul")!
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return date
    }

    /// 재현 가능한 샘플 PersistableState (UUID 고정)
    private func makeSampleState() -> PersistableState {
        let pregnancyId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let childId     = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        let pregnancy = Pregnancy(
            id: pregnancyId,
            lmpDate: d("2025-01-10"),
            eddDate: d("2025-10-17"),
            fetusCount: 1,
            nickname: "별이",
            clinic: "행복산부인과",
            status: .active
        )
        let child = Child(
            id: childId,
            name: "김별이",
            birthDate: d("2025-10-17"),
            gender: .girl,
            profileImageRef: nil,
            caregiverRole: "엄마",
            pregnancyId: pregnancyId
        )
        return PersistableState(pregnancies: [pregnancy], children: [child])
    }

    private func makeEmptyState() -> PersistableState {
        PersistableState(pregnancies: [], children: [])
    }

    // MARK: - exportJSON → importJSON 라운드트립

    func test_exportImport_roundTrip_equatable() throws {
        let original = makeSampleState()

        let data = try DataExporter.exportJSON(original)
        let restored = try DataExporter.importJSON(data)

        XCTAssertEqual(restored, original,
            "exportJSON → importJSON 라운드트립 결과가 원본과 Equatable 동일해야 한다")
    }

    // MARK: - 빈 상태 라운드트립

    func test_exportImport_emptyState_roundTrip() throws {
        let empty = makeEmptyState()

        let data = try DataExporter.exportJSON(empty)
        let restored = try DataExporter.importJSON(data)

        XCTAssertEqual(restored, empty,
            "빈 PersistableState도 라운드트립 후 동일해야 한다")
    }

    // MARK: - exportJSON 결과는 유효한 JSON

    func test_exportJSON_producesValidJSON() throws {
        let state = makeSampleState()
        let data = try DataExporter.exportJSON(state)

        XCTAssertFalse(data.isEmpty, "exportJSON 결과 Data가 비어있지 않아야 한다")

        // JSON 파싱 가능 여부 확인
        let json = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(json, "exportJSON 결과는 유효한 JSON이어야 한다")
    }

    // MARK: - exportJSON Data는 UTF-8 인코딩

    func test_exportJSON_isUTF8Decodable() throws {
        let state = makeSampleState()
        let data = try DataExporter.exportJSON(state)
        let string = String(data: data, encoding: .utf8)
        XCTAssertNotNil(string, "exportJSON Data는 UTF-8 문자열로 디코딩 가능해야 한다")
    }

    // MARK: - importJSON: 유효하지 않은 Data → throw

    func test_importJSON_invalidData_throws() {
        let garbage = "not-json".data(using: .utf8)!
        XCTAssertThrowsError(try DataExporter.importJSON(garbage),
            "유효하지 않은 JSON Data를 importJSON에 전달하면 에러를 throw해야 한다")
    }

    // MARK: - 복수 Child/Pregnancy 포함 상태 라운드트립

    func test_exportImport_multipleRecords_roundTrip() throws {
        let p1 = Pregnancy(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            lmpDate: d("2024-03-01"),
            eddDate: d("2024-12-05"),
            fetusCount: 2,
            nickname: "쌍둥이",
            clinic: "서울병원",
            status: .delivered
        )
        let p2 = Pregnancy(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            lmpDate: d("2026-01-15"),
            eddDate: d("2026-10-22"),
            fetusCount: 1,
            nickname: nil,
            clinic: nil,
            status: .active
        )
        let c1 = Child(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            name: "첫째",
            birthDate: d("2024-12-01"),
            gender: .boy,
            profileImageRef: nil,
            caregiverRole: nil,
            pregnancyId: p1.id
        )
        let state = PersistableState(pregnancies: [p1, p2], children: [c1])

        let data = try DataExporter.exportJSON(state)
        let restored = try DataExporter.importJSON(data)

        XCTAssertEqual(restored, state,
            "복수 임신·아이 포함 상태도 라운드트립 후 동일해야 한다")
        XCTAssertEqual(restored.pregnancies.count, 2)
        XCTAssertEqual(restored.children.count, 1)
    }

    // MARK: - exportToTemporaryFile: 파일 생성

    func test_exportToTemporaryFile_createsFile() throws {
        let state = makeSampleState()
        let url = try DataExporter.exportToTemporaryFile(state)
        tempExportURL = url // tearDown에서 삭제 [주의 §5]

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
            "exportToTemporaryFile은 실제 파일을 생성해야 한다")
    }

    // MARK: - exportToTemporaryFile: .json 확장자 [주의 §4]

    func test_exportToTemporaryFile_hasJsonExtension() throws {
        let state = makeSampleState()
        let url = try DataExporter.exportToTemporaryFile(state)
        tempExportURL = url

        XCTAssertEqual(url.pathExtension, "json",
            "exportToTemporaryFile이 반환하는 파일 URL은 .json 확장자를 가져야 한다")
    }

    // MARK: - exportToTemporaryFile: 파일 읽기 후 importJSON → 원본과 동일

    func test_exportToTemporaryFile_fileContent_roundTrip() throws {
        let original = makeSampleState()
        let url = try DataExporter.exportToTemporaryFile(original)
        tempExportURL = url

        let data = try Data(contentsOf: url)
        let restored = try DataExporter.importJSON(data)

        XCTAssertEqual(restored, original,
            "exportToTemporaryFile로 저장된 파일을 읽어 importJSON하면 원본과 동일해야 한다")
    }

    // MARK: - exportToTemporaryFile: 빈 상태도 파일 생성

    func test_exportToTemporaryFile_emptyState_createsFile() throws {
        let empty = makeEmptyState()
        let url = try DataExporter.exportToTemporaryFile(empty)
        tempExportURL = url

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
            "빈 상태도 임시파일로 저장되어야 한다")

        let data = try Data(contentsOf: url)
        let restored = try DataExporter.importJSON(data)
        XCTAssertEqual(restored, empty,
            "빈 상태의 임시파일 라운드트립도 동일해야 한다")
    }

    // MARK: - exportJSON → PersistableState 배열 순서 보존 [주의 §2]

    func test_exportImport_preservesArrayOrder() throws {
        // 5개 Child를 특정 순서로 배치
        let children = (1...5).map { idx in
            Child(id: UUID(), name: "아이\(idx)", birthDate: d("2025-0\(idx)-01"),
                  gender: nil, profileImageRef: nil, caregiverRole: nil, pregnancyId: nil)
        }

        let state = PersistableState(pregnancies: [], children: children)
        let data = try DataExporter.exportJSON(state)
        let restored = try DataExporter.importJSON(data)

        XCTAssertEqual(restored.children.map { $0.id }, state.children.map { $0.id },
            "children 배열의 순서가 라운드트립 후 보존되어야 한다")
    }
}
