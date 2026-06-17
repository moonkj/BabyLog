// AppStoreGrowthBoardTests.swift
// 성장 보드 핵심 로직 검증 — 아이당 여러 보드(무료1/Pro무제한), 보드 id 키잉, 삭제 정리, 기록사진 승계.

import XCTest
@testable import BabyLog

@MainActor
final class AppStoreGrowthBoardTests: XCTestCase {

    private func newStore() -> AppStore {
        AppStore(pregnancies: [], children: [], bus: EventBus(), persistence: nil)
    }

    // MARK: createBoard + board(id:) + upsert(id 키잉)

    func test_createBoard_lookupAndUpsertById() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id

        var board = store.createBoard(childId: cid, title: "첫 보드")
        XCTAssertEqual(board.childId, cid)
        XCTAssertNotNil(store.board(id: board.id))

        board.cards.append(BoardCard(kind: "memo", title: "메모"))
        store.upsertBoard(board)   // 같은 id → 업데이트(중복 생성 아님)
        XCTAssertEqual(store.board(id: board.id)?.cards.count, 1)
        XCTAssertEqual(store.boards(for: cid).count, 1, "보드 1개 유지")
    }

    // MARK: 아이당 여러 보드

    func test_multipleBoardsPerChild() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id

        let b1 = store.createBoard(childId: cid)
        let b2 = store.createBoard(childId: cid)
        let b3 = store.createBoard(childId: cid)

        XCTAssertEqual(store.boards(for: cid).count, 3, "아이당 여러 보드 생성 가능")
        XCTAssertEqual(Set([b1.id, b2.id, b3.id]).count, 3, "보드 id는 서로 다름")
    }

    // MARK: 다자녀 — 보드가 섞이지 않음

    func test_multiChild_boardsAreIsolated() {
        let store = newStore()
        store.completeBabyOnboarding(name: "첫째", birthDate: Date(), gender: .boy)
        store.completeBabyOnboarding(name: "둘째", birthDate: Date(), gender: .girl)
        let a = store.children[0].id, b = store.children[1].id

        store.createBoard(childId: a)
        store.createBoard(childId: b)
        store.createBoard(childId: b)

        XCTAssertEqual(store.boards(for: a).count, 1)
        XCTAssertEqual(store.boards(for: b).count, 2)
    }

    // MARK: 보드 1개 삭제 — 다른 보드는 유지

    func test_deleteBoard_removesOnlyThatBoard() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        let keep = store.createBoard(childId: cid)
        let drop = store.createBoard(childId: cid)

        store.deleteBoard(id: drop.id)

        XCTAssertNil(store.board(id: drop.id), "삭제한 보드는 사라짐")
        XCTAssertNotNil(store.board(id: keep.id), "다른 보드는 유지")
        XCTAssertEqual(store.boards(for: cid).count, 1)
    }

    // MARK: 아이 삭제 → 그 아이의 모든 보드 제거

    func test_deleteChild_removesAllBoards() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        store.createBoard(childId: cid)
        var b = store.createBoard(childId: cid)
        b.cards.append(BoardCard(kind: "photo", photoRef: "board-only.jpg"))
        store.upsertBoard(b)
        XCTAssertEqual(store.boards(for: cid).count, 2)

        store.deleteChild(id: cid)
        XCTAssertTrue(store.boards(for: cid).isEmpty, "아이 삭제 시 모든 보드 제거")
    }

    // MARK: 기록 삭제 시, 그 사진을 참조하던 보드 카드는 사진을 '승계'(빈 카드/유실 방지)

    func test_deleteDiaryEntry_boardAdoptsReferencedPhoto() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        store.addDiaryEntry(childId: cid, content: "첫 기록", milestone: nil, photoRef: "shared.jpg")
        let entry = store.diaryEntries.first { $0.childId == cid }!

        var board = store.createBoard(childId: cid)
        board.cards.append(BoardCard(kind: "photo", photoRef: "shared.jpg", sourceEntryId: entry.id.uuidString))
        store.upsertBoard(board)

        store.deleteDiaryEntry(id: entry.id)

        let card = store.board(id: board.id)?.cards.first
        XCTAssertEqual(card?.photoRef, "shared.jpg", "참조 사진은 보드에 유지(빈 카드 안 됨)")
        XCTAssertNil(card?.sourceEntryId, "기록이 사라지면 보드가 사진을 소유로 승계")
    }

    // MARK: 대표 보드 — 첫 보드가 대표, 무료는 대표만 편집

    func test_firstBoardIsPrimary_andFreeEditabilityRule() {
        let store = newStore()   // 무료(isPro=false)
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id

        let b1 = store.createBoard(childId: cid)   // 첫 보드 = 대표
        XCTAssertTrue(store.board(id: b1.id)?.isPrimary == true)
        XCTAssertEqual(store.primaryBoardId(for: cid), b1.id)

        // Pro 시절 둘째 보드 생성 → 다운그레이드.
        store.setSubscriptionActive(true)
        let b2 = store.createBoard(childId: cid)   // 비대표
        XCTAssertFalse(store.board(id: b2.id)?.isPrimary == true)
        store.setSubscriptionActive(false)         // 무료로 변경

        XCTAssertEqual(store.boards(for: cid).count, 2, "다운그레이드해도 보드는 모두 보존(데이터 인질극 금지)")
        XCTAssertTrue(store.isBoardEditable(b1.id, childId: cid), "대표 보드는 무료도 편집 가능")
        XCTAssertFalse(store.isBoardEditable(b2.id, childId: cid), "무료 비대표 보드는 보기 전용")
    }

    // MARK: 대표 변경은 Pro만

    func test_setPrimaryBoard_proOnly() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        store.setSubscriptionActive(true)
        let b1 = store.createBoard(childId: cid)
        let b2 = store.createBoard(childId: cid)

        store.setPrimaryBoard(childId: cid, boardId: b2.id)   // Pro: 변경 가능
        XCTAssertEqual(store.primaryBoardId(for: cid), b2.id)

        store.setSubscriptionActive(false)                   // 무료
        store.setPrimaryBoard(childId: cid, boardId: b1.id)  // 무료: 무시돼야 함
        XCTAssertEqual(store.primaryBoardId(for: cid), b2.id, "무료는 대표 변경 불가")
    }

    // MARK: 생성 한도 — 무료 1개 / Pro 최대 100

    func test_canCreateBoard_gates() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id

        XCTAssertTrue(store.canCreateBoard(for: cid), "무료 0개 → 생성 가능")
        store.createBoard(childId: cid)
        XCTAssertFalse(store.canCreateBoard(for: cid), "무료 1개 → 추가 불가")

        store.setSubscriptionActive(true)
        XCTAssertTrue(store.canCreateBoard(for: cid), "Pro → 생성 가능")
    }

    // MARK: 삭제된 아이의 보드는 뒤늦은 upsert로 부활하지 않음(안전장치)

    func test_upsertBoard_doesNotResurrectDeletedChildBoard() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        let b = store.createBoard(childId: cid)

        store.deleteChild(id: cid)
        XCTAssertTrue(store.growthBoards.isEmpty)

        store.upsertBoard(b)   // 화면이 닫히며 뒤늦게 커밋 — 아이가 없으니 추가되면 안 됨
        XCTAssertTrue(store.growthBoards.isEmpty, "삭제된 아이의 보드는 upsert로 부활하지 않아야 함")
    }

    // MARK: 복원 시 대표가 둘 이상이면 1개로 정규화(손상·병합 백업 방어)

    func test_restore_collapsesMultiplePrimaries() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        let b1 = GrowthBoard(childId: cid, title: "A", isPrimary: true)
        let b2 = GrowthBoard(childId: cid, title: "B", isPrimary: true)
        var snap = store.snapshot()
        snap.growthBoards = [b1, b2]

        store.restore(snap)

        XCTAssertEqual(store.boards(for: cid).filter { $0.isPrimary }.count, 1, "복원 후 대표는 정확히 1개")
        XCTAssertEqual(store.primaryBoardId(for: cid), b1.id, "첫(가장 먼저) 보드가 대표로 유지")
    }

    // MARK: Pro 생성 한도 경계 — 99→가능, 100→불가

    func test_canCreateBoard_proCapBoundary() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        store.setSubscriptionActive(true)

        for _ in 0..<(GrowthBoard.maxPerChild - 1) { store.createBoard(childId: cid) }
        XCTAssertTrue(store.canCreateBoard(for: cid), "99개 → 1개 더 생성 가능")

        store.createBoard(childId: cid)   // 100개째
        XCTAssertEqual(store.boards(for: cid).count, GrowthBoard.maxPerChild)
        XCTAssertFalse(store.canCreateBoard(for: cid), "100개(상한) → 추가 불가")
    }

    // MARK: 보드 전용(참조 아님) 카드는 기록 삭제와 무관

    func test_deleteDiaryEntry_doesNotTouchBoardOwnedCard() {
        let store = newStore()
        store.completeBabyOnboarding(name: "라온", birthDate: Date(), gender: .girl)
        let cid = store.children[0].id
        store.addDiaryEntry(childId: cid, content: "기록", milestone: nil, photoRef: "diary.jpg")
        let entry = store.diaryEntries.first { $0.childId == cid }!

        var board = store.createBoard(childId: cid)
        board.cards.append(BoardCard(kind: "photo", photoRef: "board-only.jpg"))
        store.upsertBoard(board)

        store.deleteDiaryEntry(id: entry.id)

        let card = store.board(id: board.id)?.cards.first
        XCTAssertEqual(card?.photoRef, "board-only.jpg")
        XCTAssertNil(card?.sourceEntryId)
    }
}
