// EventBusIsolationTests.swift
// BabyLogTests
//
// QA — EventBus 인스턴스 격리 검증
// 계약: EventBus.init()이 internal 접근제어로 열려야 한다.
//   독립 인스턴스(a, b)는 서로의 이벤트를 공유하지 않는다.
//
// 주의: 현재 구현에서 EventBus.init()은 private이다.
//   코더가 internal로 변경해야 이 파일의 인스턴스 생성 코드가 컴파일된다.

import XCTest
import Combine
@testable import BabyLog

final class EventBusIsolationTests: XCTestCase {

    private var cancellables: Set<AnyCancellable> = []

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    // MARK: - init() 접근제어 검증

    /// EventBus()를 두 번 호출해 독립 인스턴스 두 개를 생성할 수 있어야 한다.
    /// 컴파일 성공 자체가 init()이 internal 이상임을 증명한다.
    func test_eventBus_initIsInternal_twoInstancesCanBeCreated() {
        // 코더 계약: init()이 internal이어야 아래 두 줄이 컴파일된다.
        let a = EventBus()
        let b = EventBus()

        // 두 인스턴스가 서로 다른 객체임을 확인
        XCTAssertFalse(a === b,
            "두 EventBus() 인스턴스는 서로 다른 객체여야 한다")
    }

    // MARK: - 격리: b.publish → a 구독자에 도달 안 함

    /// a에만 sink를 달고 b.publish(...)를 호출하면 a의 구독자에 이벤트가 전달되지 않아야 한다.
    func test_eventBus_publishOnB_doesNotReachSinkOnA() {
        let a = EventBus()
        let b = EventBus()

        var receivedOnA = false
        a.events
            .sink { _ in receivedOnA = true }
            .store(in: &cancellables)

        b.publish(.recordSaved(childId: UUID()))

        // Combine PassthroughSubject는 동기 전달 → 별도 비동기 대기 불필요
        XCTAssertFalse(receivedOnA,
            "b.publish()는 a의 구독자에 도달해서는 안 된다 — 인스턴스 격리 검증")
    }

    // MARK: - 격리: a.publish → a 구독자에 도달

    /// a에 sink를 달고 a.publish(...)를 호출하면 a의 구독자에 이벤트가 전달되어야 한다.
    func test_eventBus_publishOnA_reachesSinkOnA() {
        let a = EventBus()

        let expectedChildId = UUID()
        var receivedChildId: UUID?

        a.events
            .sink { event in
                if case .recordSaved(let childId) = event {
                    receivedChildId = childId
                }
            }
            .store(in: &cancellables)

        a.publish(.recordSaved(childId: expectedChildId))

        XCTAssertEqual(receivedChildId, expectedChildId,
            "a.publish()는 a의 구독자에 정확히 전달되어야 한다")
    }

    // MARK: - 격리: a·b 동시 구독 교차 검증

    /// a, b 각자에 sink를 달고 서로 다른 이벤트를 발행하면 교차 수신이 없어야 한다.
    func test_eventBus_crossIsolation_noLeakBetweenInstances() {
        let a = EventBus()
        let b = EventBus()

        let idForA = UUID()
        let idForB = UUID()

        var eventsOnA: [AppEvent] = []
        var eventsOnB: [AppEvent] = []

        a.events.sink { eventsOnA.append($0) }.store(in: &cancellables)
        b.events.sink { eventsOnB.append($0) }.store(in: &cancellables)

        a.publish(.recordSaved(childId: idForA))
        b.publish(.milestoneAchieved(childId: idForB, milestone: "첫 걸음"))

        // a에는 a.publish 이벤트만
        XCTAssertEqual(eventsOnA.count, 1,
            "a는 자신이 발행한 이벤트 1개만 수신해야 한다")
        if case .recordSaved(let cid) = eventsOnA.first {
            XCTAssertEqual(cid, idForA)
        } else {
            XCTFail("a가 수신한 이벤트가 recordSaved가 아니다")
        }

        // b에는 b.publish 이벤트만
        XCTAssertEqual(eventsOnB.count, 1,
            "b는 자신이 발행한 이벤트 1개만 수신해야 한다")
        if case .milestoneAchieved(let cid, let ms) = eventsOnB.first {
            XCTAssertEqual(cid, idForB)
            XCTAssertEqual(ms, "첫 걸음")
        } else {
            XCTFail("b가 수신한 이벤트가 milestoneAchieved가 아니다")
        }
    }
}
