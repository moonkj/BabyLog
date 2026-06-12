// BackupStreamingTests.swift
// BabyLogTests — 스트리밍 백업 포맷(v2) 라운드트립.
// 상태(지출)와 실제 사진 파일이 백업→복원으로 보존되는지, 매직 헤더가 맞는지 검증.

import XCTest
import UIKit
@testable import BabyLog

final class BackupStreamingTests: XCTestCase {

    @MainActor
    func test_streamingBackup_roundTrip_preservesStateAndPhotoFile() async throws {
        // given: 디스크에 사진 1장
        let img = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { ctx in
            UIColor.systemPink.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        guard let photoName = PhotoStore.save(img) else { return XCTFail("사진 저장 실패") }
        defer { PhotoStore.delete(photoName) }

        // 상태에 알려진 지출
        let store = AppStore()
        store.addExpense(amount: 12345, category: .diaper, date: Date(), memo: "백업테스트")

        // when: 백업 생성
        guard let url = await BackupService.makeArchive(store) else { return XCTFail("makeArchive nil") }
        defer { try? FileManager.default.removeItem(at: url) }

        // 새 포맷 매직 헤더("BLBK") 확인
        let head = try FileHandle(forReadingFrom: url).read(upToCount: 4)
        XCTAssertEqual(head, Data("BLBK".utf8), "스트리밍 포맷 매직 헤더가 아님")

        // 사진을 지워 복원이 되살리는지 검증
        PhotoStore.delete(photoName)
        XCTAssertNil(PhotoStore.image(photoName))

        // then: 새 스토어로 복원
        let fresh = AppStore()
        let ok = await BackupService.restore(from: url, into: fresh)
        XCTAssertTrue(ok, "복원 실패")

        // 상태(지출) 보존
        XCTAssertTrue(fresh.expenses.contains { $0.amount == 12345 && $0.memo == "백업테스트" },
                      "지출이 복원되지 않음")
        // 사진 파일 보존(스트리밍 기록)
        XCTAssertNotNil(PhotoStore.image(photoName), "사진이 복원되지 않음")
    }

    @MainActor
    func test_restore_rejectsGarbageFile() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("garbage-\(UUID().uuidString).babylogbackup")
        try? Data("not a real backup".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let ok = await BackupService.restore(from: url, into: AppStore())
        XCTAssertFalse(ok, "손상 파일을 복원 성공으로 처리하면 안 됨")
    }
}
