// BackupArchiveTests.swift
// BabyLogTests — 전체 백업 아카이브 라운드트립 (사진 포함)

import XCTest
@testable import BabyLog

final class BackupArchiveTests: XCTestCase {

    func test_archiveRoundTrip_preservesStateAndPhotos() throws {
        let cid = UUID()
        let state = PersistableState(
            children: [Child(id: cid, name: "지호", birthDate: Date(), gender: nil,
                             profileImageRef: "p.jpg", caregiverRole: nil, pregnancyId: nil)],
            diaryEntries: [DiaryEntry(childId: cid, date: Date(), recordType: "photo",
                                      photoRef: "a.jpg", photoRefs: ["a.jpg"])]
        )
        let photoBytes = Data([0xFF, 0xD8, 0xFF, 0x01, 0x02, 0x03])   // 더미 JPEG 헤더
        let archive = BackupArchive(state: state, photos: ["a.jpg": photoBytes, "p.jpg": photoBytes])

        let enc = PropertyListEncoder(); enc.outputFormat = .binary
        let data = try enc.encode(archive)
        let back = try PropertyListDecoder().decode(BackupArchive.self, from: data)

        XCTAssertEqual(back.state.children.first?.name, "지호")
        XCTAssertEqual(back.state.diaryEntries.first?.photoRefList, ["a.jpg"])
        XCTAssertEqual(back.photos["a.jpg"], photoBytes)   // 사진 바이트 보존
        XCTAssertEqual(back.photos.count, 2)
        XCTAssertEqual(back.version, 1)
    }
}
