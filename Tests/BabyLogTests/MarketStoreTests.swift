// MarketStoreTests.swift
// BabyLogTests — 마켓 로컬 백본

import XCTest
@testable import BabyLog

@MainActor
final class MarketStoreTests: XCTestCase {

    private func newStore() -> AppStore {
        let s = AppStore()
        s.seedMarketIfNeeded()
        return s
    }

    func test_seedsSamplesOnce() {
        let s = newStore()
        XCTAssertFalse(s.marketItems.isEmpty)
        let count = s.marketItems.count
        s.seedMarketIfNeeded()              // 두 번째 호출은 무시
        XCTAssertEqual(s.marketItems.count, count)
    }

    func test_addAndDeleteItem() {
        let s = newStore()
        let item = MarketItem(title: "테스트 유모차", category: .ride, grade: .a,
                              monthsTag: "0–36개월", price: 50_000, originalPrice: nil,
                              isFree: false, hasRecall: false, isGraduate: true,
                              sellerName: "나", sellerTier: .new, distanceText: "내 동네",
                              favoriteCount: 0, photoSeed: 0, mine: true)
        s.addMarketItem(item)
        XCTAssertEqual(s.marketItems.first?.id, item.id)   // 최신이 맨 앞
        s.deleteMarketItem(id: item.id)
        XCTAssertFalse(s.marketItems.contains { $0.id == item.id })
    }

    func test_toggleSavedAndChat() {
        let s = newStore()
        let id = s.marketItems[0].id
        XCTAssertFalse(s.isMarketSaved(id))
        s.toggleMarketSaved(id)
        XCTAssertTrue(s.isMarketSaved(id))

        s.sendMarketMessage(itemId: id, text: "안녕하세요")
        XCTAssertEqual(s.marketMessages(itemId: id).count, 1)
        XCTAssertTrue(s.marketMessages(itemId: id)[0].mine)
    }
}
