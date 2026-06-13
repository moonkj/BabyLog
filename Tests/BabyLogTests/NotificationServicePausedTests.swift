// NotificationServicePausedTests.swift
// 민감영역: '기록 멈춤'(.pregnancyPaused)도 상실과 동일하게 해당 임신 알림을 즉시 취소해야 한다.
// 기존 NotificationServiceTests는 .pregnancyEndedInLoss만 검증 → paused 경로 보강.

import XCTest
import Combine
@testable import BabyLog

final class NotificationServicePausedTests: XCTestCase {

    private final class Spy: NotificationScheduling {
        private(set) var cancelled: [UUID] = []
        func cancelPregnancyNotifications(pregnancyId: UUID) { cancelled.append(pregnancyId) }
    }

    func test_pausedEvent_cancelsThatPregnancyNotifications() {
        let spy = Spy()
        let bus = EventBus()
        let service = NotificationService(scheduler: spy, bus: bus)
        service.start()

        let pid = UUID()
        bus.publish(.pregnancyPaused(pregnancyId: pid))

        XCTAssertEqual(spy.cancelled, [pid], "기록 멈춤 시 해당 임신 알림이 즉시 취소되어야 함")
    }

    func test_pausedThenLoss_bothCancel() {
        let spy = Spy()
        let bus = EventBus()
        let service = NotificationService(scheduler: spy, bus: bus)
        service.start()

        let a = UUID(); let b = UUID()
        bus.publish(.pregnancyPaused(pregnancyId: a))
        bus.publish(.pregnancyEndedInLoss(pregnancyId: b))

        XCTAssertEqual(spy.cancelled, [a, b])
    }

    func test_unrelatedEvent_doesNotCancel() {
        let spy = Spy()
        let bus = EventBus()
        let service = NotificationService(scheduler: spy, bus: bus)
        service.start()

        bus.publish(.recordSaved(childId: UUID()))

        XCTAssertTrue(spy.cancelled.isEmpty)
    }
}
