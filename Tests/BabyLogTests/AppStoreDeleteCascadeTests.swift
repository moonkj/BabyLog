// AppStoreDeleteCascadeTests.swift
// 파괴적 경로(아이/임신 삭제, 프로필 사진 교체)와 증거·관심 스냅샷 보존 — 미검증 영역.

import XCTest
@testable import BabyLog

final class AppStoreDeleteCascadeTests: XCTestCase {

    private func newStore() -> AppStore {
        AppStore(pregnancies: [], children: [], bus: EventBus(), persistence: nil)
    }

    // MARK: 아이 삭제 → 연결 데이터 전부 정리 + 선택 폴백

    func test_deleteChild_cascadesAllRelatedData() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id

        store.addDiaryEntry(childId: cid, content: "첫 기록", milestone: nil, photoRef: nil)
        store.addGrowthRecord(childId: cid, heightCm: 70, weightKg: 8, headCircumferenceCm: nil)
        store.toggleVaccine(childId: cid, vaccineId: "bcg")
        store.setVaccineHospital(childId: cid, vaccineId: "bcg", hospital: "동네소아과")

        store.deleteChild(id: cid)

        XCTAssertTrue(store.children.isEmpty)
        XCTAssertTrue(store.diaryEntries.filter { $0.childId == cid }.isEmpty, "다이어리 정리")
        XCTAssertTrue(store.growthRecords.filter { $0.childId == cid }.isEmpty, "성장기록 정리")
        XCTAssertFalse(store.isVaccineDone(childId: cid, vaccineId: "bcg"), "접종완료 키 정리")
        XCTAssertNil(store.selectedChildId, "남은 아이 없으면 선택 nil")
    }

    func test_deleteSelectedChild_fallsBackToAnother() {
        let store = newStore()
        store.completeBabyOnboarding(name: "첫째", birthDate: Date(), gender: .boy)
        store.completeBabyOnboarding(name: "둘째", birthDate: Date(), gender: .girl)
        let first = store.children[0].id
        let second = store.children[1].id
        store.selectedChildId = first

        store.deleteChild(id: first)

        XCTAssertEqual(store.children.count, 1)
        XCTAssertEqual(store.selectedChildId, second, "선택된 아이 삭제 시 남은 아이로 폴백")
    }

    // MARK: 임신 삭제 → 배사진·검진 키 정리

    func test_deletePregnancy_clearsLogsAndCheckups() {
        let store = newStore()
        store.startPregnancy(lmp: nil, edd: Date().addingTimeInterval(60*60*24*100), nickname: "콩이")
        let pid = store.activePregnancy!.id
        store.addBellyPhoto(pregnancyId: pid, week: 10, photoRef: "belly1.jpg")
        store.toggleCheckupDone(pregnancyId: pid, checkupId: "nt")
        XCTAssertTrue(store.isCheckupDone(pregnancyId: pid, checkupId: "nt"))

        store.deletePregnancy(id: pid)

        XCTAssertNil(store.activePregnancy)
        XCTAssertTrue(store.bellyPhotos(pregnancyId: pid).isEmpty, "배사진 로그 정리")
        XCTAssertFalse(store.isCheckupDone(pregnancyId: pid, checkupId: "nt"), "검진 키 정리")
    }

    // MARK: 프로필 사진 교체 시 옛 파일 삭제 / 미전달 시 유지

    func test_updateChild_doubleOptional_nilOuter_keepsExistingRef() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl, profileImageRef: "old.jpg")
        let cid = store.children[0].id

        // 이중옵셔널 외부 nil → 사진 변경 안 함
        store.updateChild(id: cid, name: "라온이", birthDate: Date(), gender: .girl)

        XCTAssertEqual(store.children[0].profileImageRef, "old.jpg", "ref 미전달 시 기존 유지")
        XCTAssertEqual(store.children[0].name, "라온이")
    }

    func test_updateChild_newRef_replacesProfileImage() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl, profileImageRef: "old.jpg")
        let cid = store.children[0].id

        store.updateChild(id: cid, name: "라온", birthDate: Date(), gender: .girl, profileImageRef: .some("new.jpg"))

        XCTAssertEqual(store.children[0].profileImageRef, "new.jpg")
    }

    // MARK: 관심 매물 스냅샷 — 매물 삭제 후에도 유지(동네 이동·만료 대비)

    func test_savedMarketSnapshot_survivesItemDeletion() {
        let store = newStore()
        let item = MarketItem(title: "유모차", category: .ride, grade: .a,
                              monthsTag: "0–36개월", price: 50_000, originalPrice: nil,
                              isFree: false, hasRecall: false, isGraduate: false,
                              sellerName: "이웃", sellerTier: .new, distanceText: "내 동네",
                              favoriteCount: 0, photoSeed: 0, mine: false)
        store.addMarketItem(item)
        store.toggleMarketSaved(item)               // 찜 → 스냅샷 보관
        store.deleteMarketItem(id: item.id)         // 원본 삭제

        XCTAssertTrue(store.savedMarketItemSnapshots.contains { $0.id == item.id },
                      "원본이 삭제돼도 관심 스냅샷은 유지되어야 함")
    }

    // MARK: 거래 신고 증거 — 채팅/매물 삭제 후에도 transcript 보존

    func test_reportTrade_preservesTranscriptAfterDeletion() {
        let store = newStore()
        let item = MarketItem(title: "카시트", category: .safety, grade: .b,
                              monthsTag: "0–12개월", price: 30_000, originalPrice: nil,
                              isFree: false, hasRecall: false, isGraduate: false,
                              sellerName: "판매자", sellerTier: .new, distanceText: "내 동네",
                              favoriteCount: 0, photoSeed: 0, mine: false)
        store.addMarketItem(item)
        store.sendMarketMessage(itemId: item.id, text: "안전결제 가능할까요?", mine: true)
        let report = store.reportTrade(item: item, reason: "사기 의심")

        store.deleteMarketItem(id: item.id)          // 매물·채팅 삭제

        XCTAssertEqual(report.transcript.count, 1, "신고 시점 대화가 증거로 보존")
        XCTAssertEqual(report.transcript.first?.text, "안전결제 가능할까요?")
        XCTAssertTrue(store.tradeReports.contains { $0.id == report.id })
    }
}
