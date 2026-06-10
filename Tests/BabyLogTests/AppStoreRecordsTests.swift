// AppStoreRecordsTests.swift
// BabyLogTests
//
// QA — AppStore 성장·다이어리 기록 API 계약 검증
//
// ============================================================
// [계약과 어긋날 수 있는 지점]
//
// 1. addDiaryEntry / addGrowthRecord 메서드 미구현
//    - 계약: AppStore에 아래 두 메서드가 존재해야 한다.
//        func addDiaryEntry(childId: UUID, content: String?,
//                           milestone: String?, photoRef: String?)
//        func addGrowthRecord(childId: UUID, heightCm: Double?,
//                             weightKg: Double?, headCircumferenceCm: Double?)
//    - 현재 AppStore.swift에 없다. coder-data가 추가해야 이 파일이 컴파일된다.
//
// 2. photoRef → recordType 매핑 정책
//    - 계약: photoRef != nil → recordType == "photo",
//             photoRef == nil → recordType == "diary"
//    - DiaryEntry에 photoRef 필드가 없다(Models.swift). addDiaryEntry 구현에서
//      photoRef 유무로 recordType을 결정하는 로직이 추가되어야 한다.
//    - photoRef를 DiaryEntry 어딘가에 저장할지 여부는 코더 재량이나,
//      recordType 결정에는 반드시 사용되어야 한다.
//
// 3. diaryEntries(for:) / growthRecords(for:) 쿼리 메서드 미구현
//    - 계약:
//        func diaryEntries(for childId: UUID) -> [DiaryEntry]   // date 내림차순
//        func growthRecords(for childId: UUID) -> [GrowthRecord] // date 오름차순
//    - 현재 AppStore에 없다. coder-data가 추가해야 한다.
//
// 4. @Published private(set) var growthRecords / diaryEntries
//    - 계약: AppStore에 이미 선언됨 (AppStore.swift 라인 16-17). ✓
//
// 5. PersistableState growthRecords / diaryEntries 포함 여부
//    - 계약: PersistableState에 두 배열이 이미 추가됨. ✓
//    - 하위호환 디코딩(decodeIfPresent)도 이미 구현됨. ✓
//
// 6. snapshot() / restore() — growthRecords·diaryEntries 미포함
//    - 현재 AppStore.snapshot()이 PersistableState(pregnancies:children:) 만
//      초기화하여 growthRecords·diaryEntries를 포함하지 않는다(AppStore.swift 라인 87).
//    - restore()도 pregnancies·children만 반영한다(라인 92-94).
//    - 영속화 라운드트립 테스트가 통과하려면 코더가 이 두 메서드를 수정해야 한다.
//
// 7. 자동 영속화(enableAutoPersist)의 4-way combineLatest
//    - growthRecords·diaryEntries가 바뀔 때도 자동 저장이 트리거되어야 한다.
//    - AppStore.enableAutoPersist()는 이미 4개 Publisher를 묶고 있으므로 계약 충족. ✓
//    - 단, snapshot/restore가 수정되기 전까지는 자동 저장돼도 내용이 빠진다.
//
// 8. DiaryEntry.photoRef 필드 부재
//    - Models.swift의 DiaryEntry에는 photoRef 필드가 없다.
//    - addDiaryEntry 호출 시 photoRef 인자는 recordType 결정에만 쓰이거나,
//      별도 저장 필드(content에 포함 등)로 처리될 수 있다.
//    - 이 테스트는 recordType 결정 계약만 검증하며 photoRef 저장 위치는 무관하다.
//
// 9. 테스트 날짜 제어
//    - addDiaryEntry / addGrowthRecord 내부에서 Date()로 현재 시각을 사용할 수 있다.
//    - 정렬 순서 테스트는 짧은 sleep(0.01s) 없이 고정 날짜를 가진 초기 데이터를
//      AppStore(diaryEntries:growthRecords:) 초기화로 직접 주입하여 테스트한다.
// ============================================================

import XCTest
import Combine
@testable import BabyLog

final class AppStoreRecordsTests: XCTestCase {

    // MARK: - Helpers

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    /// "yyyy-MM-dd HH:mm:ss" 문자열을 UTC 기준 Date로 변환
    private func date(_ s: String) -> Date {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.timeZone = TimeZone(identifier: "UTC")!
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = fmt.date(from: s) else {
            fatalError("날짜 파싱 실패: \(s)")
        }
        return d
    }

    /// 빈 AppStore 픽스처 (영속화 없음)
    private func makeEmptyStore() -> AppStore {
        AppStore(pregnancies: [], children: [], bus: EventBus(), persistence: nil)
    }

    // MARK: - 1. addDiaryEntry → diaryEntries 1개, childId 일치

    /// addDiaryEntry 호출 후 diaryEntries 전역 배열에 1개 추가, childId 일치.
    func test_addDiaryEntry_addsOneEntryWithMatchingChildId() {
        let store = makeEmptyStore()
        let childId = UUID()

        store.addDiaryEntry(childId: childId, content: "첫 기록", milestone: nil, photoRef: nil)

        XCTAssertEqual(
            store.diaryEntries.count, 1,
            "addDiaryEntry 후 diaryEntries에 정확히 1개가 추가되어야 한다"
        )
        XCTAssertEqual(
            store.diaryEntries.first?.childId, childId,
            "추가된 DiaryEntry.childId는 인자로 전달된 childId와 일치해야 한다"
        )
    }

    // MARK: - 2. photoRef 있으면 recordType == "photo"

    /// photoRef가 nil이 아니면 recordType은 "photo"여야 한다.
    func test_addDiaryEntry_withPhotoRef_recordTypeIsPhoto() {
        let store = makeEmptyStore()
        let childId = UUID()

        store.addDiaryEntry(
            childId: childId,
            content: "사진 설명",
            milestone: nil,
            photoRef: "photo://abc123"
        )

        XCTAssertEqual(
            store.diaryEntries.first?.recordType, "photo",
            "photoRef가 non-nil이면 recordType은 \"photo\"여야 한다"
        )
    }

    // MARK: - 3. photoRef 없으면 recordType == "diary"

    /// photoRef가 nil이면 recordType은 "diary"여야 한다.
    func test_addDiaryEntry_withoutPhotoRef_recordTypeIsDiary() {
        let store = makeEmptyStore()
        let childId = UUID()

        store.addDiaryEntry(
            childId: childId,
            content: "일기 내용",
            milestone: nil,
            photoRef: nil
        )

        XCTAssertEqual(
            store.diaryEntries.first?.recordType, "diary",
            "photoRef가 nil이면 recordType은 \"diary\"여야 한다"
        )
    }

    // MARK: - 4. addGrowthRecord → growthRecords 1개, 값 일치

    /// addGrowthRecord 후 growthRecords 1개, childId·수치 일치.
    func test_addGrowthRecord_addsOneRecordWithMatchingValues() {
        let store = makeEmptyStore()
        let childId = UUID()

        store.addGrowthRecord(
            childId: childId,
            heightCm: 75.5,
            weightKg: 9.2,
            headCircumferenceCm: 44.0
        )

        XCTAssertEqual(
            store.growthRecords.count, 1,
            "addGrowthRecord 후 growthRecords에 정확히 1개가 추가되어야 한다"
        )
        let record = store.growthRecords.first
        XCTAssertEqual(record?.childId, childId,
            "GrowthRecord.childId는 인자와 일치해야 한다")
        XCTAssertEqual(record?.heightCm, 75.5,
            "GrowthRecord.heightCm은 인자와 일치해야 한다")
        XCTAssertEqual(record?.weightKg, 9.2,
            "GrowthRecord.weightKg는 인자와 일치해야 한다")
        XCTAssertEqual(record?.headCircumferenceCm, 44.0,
            "GrowthRecord.headCircumferenceCm은 인자와 일치해야 한다")
    }

    // MARK: - 5. addGrowthRecord — 선택 값 nil 허용

    /// 모든 측정값이 nil이어도 growthRecords에 추가되어야 한다.
    func test_addGrowthRecord_allNilMeasurements_stillAddsRecord() {
        let store = makeEmptyStore()
        let childId = UUID()

        store.addGrowthRecord(
            childId: childId,
            heightCm: nil,
            weightKg: nil,
            headCircumferenceCm: nil
        )

        XCTAssertEqual(
            store.growthRecords.count, 1,
            "측정값이 모두 nil이어도 GrowthRecord가 추가되어야 한다"
        )
        XCTAssertNil(store.growthRecords.first?.heightCm)
        XCTAssertNil(store.growthRecords.first?.weightKg)
        XCTAssertNil(store.growthRecords.first?.headCircumferenceCm)
    }

    // MARK: - 6. diaryEntries(for:) — 다른 아이 항목 제외, 같은 아이만 반환

    /// diaryEntries(for:) 는 지정된 childId의 항목만 반환하고 다른 아이 항목은 제외한다.
    func test_diaryEntriesForChildId_excludesOtherChildren() {
        let childA = UUID()
        let childB = UUID()

        let entryA1 = DiaryEntry(id: UUID(), childId: childA,
                                 date: date("2025-01-01 10:00:00"), recordType: "diary",
                                 content: "A의 기록1")
        let entryA2 = DiaryEntry(id: UUID(), childId: childA,
                                 date: date("2025-01-03 10:00:00"), recordType: "diary",
                                 content: "A의 기록2")
        let entryB1 = DiaryEntry(id: UUID(), childId: childB,
                                 date: date("2025-01-02 10:00:00"), recordType: "diary",
                                 content: "B의 기록")

        let store = AppStore(
            pregnancies: [], children: [],
            diaryEntries: [entryA1, entryB1, entryA2],
            bus: EventBus(), persistence: nil
        )

        let results = store.diaryEntries(for: childA)

        XCTAssertEqual(results.count, 2,
            "childA의 diaryEntries는 2개여야 한다 — childB 항목은 제외")
        XCTAssertTrue(results.allSatisfy { $0.childId == childA },
            "반환된 모든 항목의 childId는 childA여야 한다")
        XCTAssertFalse(results.contains(where: { $0.childId == childB }),
            "childB의 항목이 결과에 포함되면 안 된다")
    }

    // MARK: - 7. diaryEntries(for:) — 날짜 내림차순 정렬

    /// diaryEntries(for:) 결과는 date 내림차순(최신 → 과거) 정렬이어야 한다.
    func test_diaryEntriesForChildId_sortedByDateDescending() {
        let childId = UUID()

        let early  = DiaryEntry(id: UUID(), childId: childId,
                                date: date("2025-01-01 08:00:00"), recordType: "diary")
        let middle = DiaryEntry(id: UUID(), childId: childId,
                                date: date("2025-03-15 12:00:00"), recordType: "diary")
        let latest = DiaryEntry(id: UUID(), childId: childId,
                                date: date("2025-06-10 20:00:00"), recordType: "diary")

        // 의도적으로 순서를 섞어서 삽입
        let store = AppStore(
            pregnancies: [], children: [],
            diaryEntries: [middle, early, latest],
            bus: EventBus(), persistence: nil
        )

        let results = store.diaryEntries(for: childId)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].date, latest.date,
            "첫 번째 항목은 가장 최신 날짜여야 한다 (내림차순)")
        XCTAssertEqual(results[1].date, middle.date,
            "두 번째 항목은 중간 날짜여야 한다")
        XCTAssertEqual(results[2].date, early.date,
            "세 번째 항목은 가장 오래된 날짜여야 한다")
    }

    // MARK: - 8. growthRecords(for:) — 같은 아이만 반환

    /// growthRecords(for:) 는 지정된 childId의 기록만 반환한다.
    func test_growthRecordsForChildId_excludesOtherChildren() {
        let childA = UUID()
        let childB = UUID()

        let recA1 = GrowthRecord(id: UUID(), childId: childA,
                                 date: date("2025-01-01 10:00:00"), heightCm: 60.0)
        let recA2 = GrowthRecord(id: UUID(), childId: childA,
                                 date: date("2025-06-01 10:00:00"), heightCm: 70.0)
        let recB  = GrowthRecord(id: UUID(), childId: childB,
                                 date: date("2025-03-01 10:00:00"), heightCm: 65.0)

        let store = AppStore(
            pregnancies: [], children: [],
            growthRecords: [recA1, recB, recA2],
            bus: EventBus(), persistence: nil
        )

        let results = store.growthRecords(for: childA)

        XCTAssertEqual(results.count, 2,
            "childA의 growthRecords는 2개여야 한다 — childB 항목 제외")
        XCTAssertTrue(results.allSatisfy { $0.childId == childA },
            "반환된 모든 기록의 childId는 childA여야 한다")
        XCTAssertFalse(results.contains(where: { $0.childId == childB }),
            "childB의 기록이 결과에 포함되면 안 된다")
    }

    // MARK: - 9. growthRecords(for:) — 날짜 오름차순 정렬

    /// growthRecords(for:) 결과는 date 오름차순(과거 → 최신) 정렬이어야 한다.
    func test_growthRecordsForChildId_sortedByDateAscending() {
        let childId = UUID()

        let first  = GrowthRecord(id: UUID(), childId: childId,
                                  date: date("2025-01-01 00:00:00"), weightKg: 3.5)
        let second = GrowthRecord(id: UUID(), childId: childId,
                                  date: date("2025-04-01 00:00:00"), weightKg: 6.0)
        let third  = GrowthRecord(id: UUID(), childId: childId,
                                  date: date("2025-07-01 00:00:00"), weightKg: 8.5)

        // 의도적으로 순서를 섞어서 삽입
        let store = AppStore(
            pregnancies: [], children: [],
            growthRecords: [third, first, second],
            bus: EventBus(), persistence: nil
        )

        let results = store.growthRecords(for: childId)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].date, first.date,
            "첫 번째 기록은 가장 오래된 날짜여야 한다 (오름차순)")
        XCTAssertEqual(results[1].date, second.date,
            "두 번째 기록은 중간 날짜여야 한다")
        XCTAssertEqual(results[2].date, third.date,
            "세 번째 기록은 가장 최신 날짜여야 한다")
    }

    // MARK: - 10. diaryEntries(for:) — 존재하지 않는 childId → 빈 배열

    /// 등록되지 않은 childId로 조회하면 빈 배열을 반환해야 한다.
    func test_diaryEntriesForChildId_unknownChildId_returnsEmpty() {
        let store = makeEmptyStore()

        let results = store.diaryEntries(for: UUID())

        XCTAssertTrue(results.isEmpty,
            "존재하지 않는 childId로 diaryEntries(for:) 호출 시 빈 배열을 반환해야 한다")
    }

    // MARK: - 11. growthRecords(for:) — 존재하지 않는 childId → 빈 배열

    /// 등록되지 않은 childId로 조회하면 빈 배열을 반환해야 한다.
    func test_growthRecordsForChildId_unknownChildId_returnsEmpty() {
        let store = makeEmptyStore()

        let results = store.growthRecords(for: UUID())

        XCTAssertTrue(results.isEmpty,
            "존재하지 않는 childId로 growthRecords(for:) 호출 시 빈 배열을 반환해야 한다")
    }

    // MARK: - 12. 하위호환: 기록 키 없는 구버전 JSON → 빈 배열 (throw 안 함)

    /// {"pregnancies":[],"children":[]} 형태의 구버전 JSON을 PersistableState로 디코딩하면
    /// growthRecords·diaryEntries는 빈 배열이어야 하고 throw가 발생하면 안 된다.
    func test_backwardCompatibility_legacyJSON_emptyRecords() throws {
        let legacyJSON = """
        {
            "pregnancies": [],
            "children": []
        }
        """.data(using: .utf8)!

        // DataExporter.importJSON 또는 JSONDecoder 직접 사용 — 계약 모두 허용
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 반드시 throw 없이 디코딩되어야 한다
        let state = try decoder.decode(PersistableState.self, from: legacyJSON)

        XCTAssertTrue(
            state.growthRecords.isEmpty,
            "구버전 JSON에 growthRecords 키가 없으면 빈 배열로 디코딩되어야 한다"
        )
        XCTAssertTrue(
            state.diaryEntries.isEmpty,
            "구버전 JSON에 diaryEntries 키가 없으면 빈 배열로 디코딩되어야 한다"
        )
        XCTAssertTrue(
            state.pregnancies.isEmpty,
            "pregnancies는 빈 배열이어야 한다"
        )
        XCTAssertTrue(
            state.children.isEmpty,
            "children은 빈 배열이어야 한다"
        )
    }

    // MARK: - 13. 하위호환: DataExporter.importJSON으로도 검증

    /// DataExporter.importJSON을 통해서도 구버전 JSON이 정상 디코딩되어야 한다.
    func test_backwardCompatibility_dataExporterImportJSON_legacyJSON() throws {
        let legacyJSON = """
        {
            "pregnancies": [],
            "children": []
        }
        """.data(using: .utf8)!

        let state = try DataExporter.importJSON(legacyJSON)

        XCTAssertTrue(
            state.growthRecords.isEmpty,
            "DataExporter.importJSON: 구버전 JSON의 growthRecords는 빈 배열이어야 한다"
        )
        XCTAssertTrue(
            state.diaryEntries.isEmpty,
            "DataExporter.importJSON: 구버전 JSON의 diaryEntries는 빈 배열이어야 한다"
        )
    }

    // MARK: - 14. 영속화 라운드트립: addGrowthRecord 후 snapshot → restore → 기록 유지

    /// addGrowthRecord 후 snapshot → 새 AppStore에 restore하면 기록이 유지되어야 한다.
    func test_persistence_roundTrip_growthRecord_survivesSnapshotRestore() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreRecordsTest_gr_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let persistence = LocalPersistence(url: tempURL)
        let store = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        let childId = UUID()
        store.addGrowthRecord(
            childId: childId,
            heightCm: 68.0,
            weightKg: 7.5,
            headCircumferenceCm: 42.5
        )

        // snapshot → persistence 수동 저장
        let snap = store.snapshot()
        try persistence.save(snap)

        // 동일 persistence로 새 AppStore 초기화 (init에서 자동 복원)
        let restoredStore = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        XCTAssertEqual(
            restoredStore.growthRecords.count, 1,
            "복원된 store의 growthRecords는 1개여야 한다"
        )
        let restored = restoredStore.growthRecords.first
        XCTAssertEqual(restored?.childId, childId,
            "복원된 GrowthRecord.childId는 원본과 일치해야 한다")
        XCTAssertEqual(restored?.heightCm, 68.0,
            "복원된 heightCm은 원본과 일치해야 한다")
        XCTAssertEqual(restored?.weightKg, 7.5,
            "복원된 weightKg는 원본과 일치해야 한다")
        XCTAssertEqual(restored?.headCircumferenceCm, 42.5,
            "복원된 headCircumferenceCm은 원본과 일치해야 한다")
    }

    // MARK: - 15. 영속화 라운드트립: addDiaryEntry 후 snapshot → restore → 기록 유지

    /// addDiaryEntry 후 snapshot → 새 AppStore에 restore하면 기록이 유지되어야 한다.
    func test_persistence_roundTrip_diaryEntry_survivesSnapshotRestore() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreRecordsTest_de_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let persistence = LocalPersistence(url: tempURL)
        let store = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        let childId = UUID()
        store.addDiaryEntry(
            childId: childId,
            content: "오늘 처음 뒤집기 성공!",
            milestone: "첫 뒤집기",
            photoRef: nil
        )

        let snap = store.snapshot()
        try persistence.save(snap)

        let restoredStore = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        XCTAssertEqual(
            restoredStore.diaryEntries.count, 1,
            "복원된 store의 diaryEntries는 1개여야 한다"
        )
        let restored = restoredStore.diaryEntries.first
        XCTAssertEqual(restored?.childId, childId,
            "복원된 DiaryEntry.childId는 원본과 일치해야 한다")
        XCTAssertEqual(restored?.content, "오늘 처음 뒤집기 성공!",
            "복원된 content는 원본과 일치해야 한다")
        XCTAssertEqual(restored?.milestone, "첫 뒤집기",
            "복원된 milestone은 원본과 일치해야 한다")
        XCTAssertEqual(restored?.recordType, "diary",
            "복원된 recordType은 \"diary\"여야 한다")
    }

    // MARK: - 16. 영속화 라운드트립: photoRef 있는 DiaryEntry → recordType "photo" 유지

    /// photoRef를 준 DiaryEntry가 snapshot→restore 후에도 recordType "photo"로 유지되어야 한다.
    func test_persistence_roundTrip_photoEntry_recordTypePhotoSurvives() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStoreRecordsTest_photo_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let persistence = LocalPersistence(url: tempURL)
        let store = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        let childId = UUID()
        store.addDiaryEntry(
            childId: childId,
            content: "사진 설명",
            milestone: nil,
            photoRef: "photo://img-001"
        )

        let snap = store.snapshot()
        try persistence.save(snap)

        let restoredStore = AppStore(
            pregnancies: [], children: [],
            bus: EventBus(),
            persistence: persistence
        )

        XCTAssertEqual(
            restoredStore.diaryEntries.first?.recordType, "photo",
            "snapshot→restore 후 photoRef가 있었던 항목의 recordType은 \"photo\"여야 한다"
        )
    }
}
