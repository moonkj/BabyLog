// AppStoreCrewMarketMiscTests.swift
// 크루 게시판·그룹·좋아요, 마켓 상태, 다이어리 좋아요/댓글, 임신 메모 — 미검증 CRUD 경로.

import XCTest
@testable import BabyLog

final class AppStoreCrewMarketMiscTests: XCTestCase {

    private func newStore() -> AppStore {
        AppStore(pregnancies: [], children: [], bus: EventBus(), persistence: nil)
    }

    // MARK: 크루 게시판
    func test_addCrewPost_insertsAtFront_trimsTitle_isMine() {
        let s = newStore()
        s.addCrewPost(category: .info, title: "  새 글  ", body: "내용")
        XCTAssertEqual(s.crewPosts.first?.title, "새 글")
        XCTAssertTrue(s.crewPosts.first?.mine ?? false)
    }
    func test_addCrewPost_emptyTitleIgnored() {
        let s = newStore()
        let before = s.crewPosts.count
        s.addCrewPost(category: .info, title: "   ", body: "x")
        XCTAssertEqual(s.crewPosts.count, before)
    }
    func test_deleteCrewPost_removesPost_like_comments() {
        let s = newStore()
        s.addCrewPost(category: .consult, title: "삭제대상", body: "b")
        let id = s.crewPosts.first!.id
        s.toggleCrewPostLike(id)
        s.addCrewPostComment(postId: id, text: "댓글")
        s.deleteCrewPost(id: id)
        XCTAssertFalse(s.crewPosts.contains { $0.id == id })
        XCTAssertFalse(s.isCrewPostLiked(id))
        XCTAssertTrue(s.crewPostCommentList(postId: id).isEmpty)
    }
    func test_toggleCrewPostLike() {
        let s = newStore()
        s.toggleCrewPostLike("P1"); XCTAssertTrue(s.isCrewPostLiked("P1"))
        s.toggleCrewPostLike("P1"); XCTAssertFalse(s.isCrewPostLiked("P1"))
    }
    func test_addCrewPostComment_trimsAndGuardsEmpty() {
        let s = newStore()
        s.addCrewPostComment(postId: "P1", text: "  좋아요  ")
        s.addCrewPostComment(postId: "P1", text: "   ")
        XCTAssertEqual(s.crewPostCommentList(postId: "P1"), ["좋아요"])
    }
    func test_toggleJoinGroup() {
        let s = newStore()
        s.toggleJoinGroup("G1"); XCTAssertTrue(s.isJoinedGroup("G1"))
        s.toggleJoinGroup("G1"); XCTAssertFalse(s.isJoinedGroup("G1"))
    }

    // MARK: 마켓 상태
    func test_setMarketStatus_updatesItem() {
        let s = newStore()
        let item = MarketItem(title: "유모차", category: .ride, grade: .a,
                              monthsTag: "0–36개월", price: 1, originalPrice: nil,
                              isFree: false, hasRecall: false, isGraduate: false,
                              sellerName: "나", sellerTier: .new, distanceText: "x",
                              favoriteCount: 0, photoSeed: 0, mine: true)
        s.addMarketItem(item)
        s.setMarketStatus(id: item.id, .sold)
        XCTAssertEqual(s.marketItems.first { $0.id == item.id }?.status, .sold)
    }

    // MARK: 다이어리 좋아요/댓글
    func test_toggleDiaryLike() {
        let s = newStore(); let id = UUID()
        s.toggleDiaryLike(id); XCTAssertTrue(s.likedDiaryIds.contains(id.uuidString))
        s.toggleDiaryLike(id); XCTAssertFalse(s.likedDiaryIds.contains(id.uuidString))
    }
    func test_addAndDeleteDiaryComment() {
        let s = newStore(); let id = UUID()
        s.addComment(entryId: id, text: "  안녕  ")
        s.addComment(entryId: id, text: "  ")
        XCTAssertEqual(s.comments(for: id), ["안녕"])
        s.deleteComment(entryId: id, at: 0)
        XCTAssertTrue(s.comments(for: id).isEmpty)
    }

    // MARK: 임신 메모
    func test_addPregnancyMemo_trimsAndGuardsEmpty() {
        let s = newStore()
        s.startPregnancy(lmp: nil, edd: Date(), nickname: "콩")
        let pid = s.activePregnancy!.id
        s.addPregnancyMemo(pregnancyId: pid, text: "  태동 느낌  ")
        s.addPregnancyMemo(pregnancyId: pid, text: "   ")
        XCTAssertEqual(s.pregnancyMemos(pregnancyId: pid).count, 1)
    }
}
