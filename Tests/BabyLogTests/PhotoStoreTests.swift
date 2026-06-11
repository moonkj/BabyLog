// PhotoStoreTests.swift
// BabyLogTests — 로컬 사진 저장 + DiaryEntry photoRef 하위호환

import XCTest
import UIKit
@testable import BabyLog

final class PhotoStoreTests: XCTestCase {

    func test_saveAndLoad_roundTrip() throws {
        // 1x1 빨강 이미지 생성
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let img = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        guard let name = PhotoStore.save(img) else {
            return XCTFail("사진 저장 실패")
        }
        defer { PhotoStore.delete(name) }

        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertNotNil(PhotoStore.image(name), "저장한 사진을 다시 로드할 수 있어야 함")
    }

    func test_loadNilOrMissing_returnsNil() {
        XCTAssertNil(PhotoStore.image(nil))
        XCTAssertNil(PhotoStore.image(""))
        XCTAssertNil(PhotoStore.image("does-not-exist.jpg"))
    }

    func test_diaryEntry_backwardCompat_missingPhotoRefDecodesNil() throws {
        // 구버전 저장 JSON: photoRef 키 없음
        let legacy = """
        {"id":"\(UUID().uuidString)","childId":"\(UUID().uuidString)","date":0,"recordType":"diary"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DiaryEntry.self, from: legacy)
        XCTAssertNil(decoded.photoRef)
        XCTAssertEqual(decoded.recordType, "diary")
    }

    func test_diaryEntry_photoRef_roundTrip() throws {
        let entry = DiaryEntry(childId: UUID(), date: Date(), recordType: "photo",
                               photoRef: "abc.jpg")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(DiaryEntry.self, from: data)
        XCTAssertEqual(decoded.photoRef, "abc.jpg")
    }

    func test_deleteDiaryEntry_removesEntry() {
        let store = AppStore()
        let cid = UUID()
        store.addDiaryEntry(childId: cid, content: "오늘", milestone: nil, photoRef: nil)
        let id = store.diaryEntries.first!.id
        store.deleteDiaryEntry(id: id)
        XCTAssertTrue(store.diaryEntries.isEmpty)
    }

    func test_diaryLike_toggle() {
        let store = AppStore()
        let id = UUID()
        XCTAssertFalse(store.isDiaryLiked(id))
        store.toggleDiaryLike(id)
        XCTAssertTrue(store.isDiaryLiked(id))
        store.toggleDiaryLike(id)
        XCTAssertFalse(store.isDiaryLiked(id))
    }

    func test_diaryComment_addAndDeleteCleanup() {
        let store = AppStore()
        let cid = UUID()
        store.addDiaryEntry(childId: cid, content: "사진", milestone: nil, photoRef: nil)
        let id = store.diaryEntries.first!.id
        store.addComment(entryId: id, text: "예쁘다 ❤️")
        store.addComment(entryId: id, text: "  ")  // 공백 무시
        XCTAssertEqual(store.comments(for: id), ["예쁘다 ❤️"])
        store.toggleDiaryLike(id)
        store.deleteDiaryEntry(id: id)
        XCTAssertTrue(store.comments(for: id).isEmpty)
        XCTAssertFalse(store.isDiaryLiked(id))
    }
}
