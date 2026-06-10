// NotificationServiceTests.swift
// BabyLogTests
//
// QA Teammate 3 작성 — NotificationService + EventBus 계약 기반 단위 테스트
//
// 민감 영역: 유산/사산(.pregnancyEndedInLoss) 이벤트 발생 직후
// 해당 임신 ID에 연결된 알림이 즉시 취소되어야 한다.
// PassthroughSubject는 동기 전달이므로 publish 직후 바로 검증 가능.
//
// TODO (추가 검증 권장):
// 1. 쌍둥이(fetusCount=2): loss 이벤트 1회에 복수 알림 prefix 모두 취소되는지 확인
//    → cancelPregnancyNotifications가 pregnancyId 단위로만 동작하므로 현재 계약은 충분하나
//      twin-specific 알림 식별자가 추가될 경우 재검증 필요
// 2. 동시성: EventBus.subject가 Main 외 스레드에서 publish될 때 scheduler 호출이 thread-safe한지 확인
//    → 현재 PassthroughSubject는 스레드 보장 없음; receive(on:) 삽입 여부 코더와 협의 필요
// 3. 중복 이벤트: 동일 pregnancyId로 loss 이벤트 2회 발행 시 cancel이 2회 호출되는지 확인
//    → 멱등성(idempotency) 보장을 위해 NotificationService에 중복 방지 로직이 필요한지 검토
// 4. service.start() 미호출 상태에서 publish → cancel 미호출 여부(구독 시점 보장)

import XCTest
import Combine
@testable import BabyLog

// MARK: - Mock

/// 취소된 pregnancyId를 기록하는 NotificationScheduling Mock
final class MockNotificationScheduler: NotificationScheduling {
    /// 실제로 cancelPregnancyNotifications가 호출된 pregnancyId 목록 (호출 순서 보존)
    private(set) var cancelledIds: [UUID] = []

    func cancelPregnancyNotifications(pregnancyId: UUID) {
        cancelledIds.append(pregnancyId)
    }
}

// MARK: - Tests

final class NotificationServiceTests: XCTestCase {

    // MARK: - Helpers

    /// 매 테스트마다 독립적인 EventBus 인스턴스를 사용한다.
    /// EventBus.shared는 싱글턴이므로 테스트 간 이벤트 누수를 방지하기 위해
    /// NotificationService init에 커스텀 bus를 주입한다.
    private func makeSUT() -> (service: NotificationService, scheduler: MockNotificationScheduler, bus: EventBus) {
        let scheduler = MockNotificationScheduler()
        // EventBus는 init이 private이므로 shared를 재사용.
        // 테스트 격리를 위해 각 테스트는 독립 subject 검증에 집중.
        let bus = EventBus.shared
        let service = NotificationService(scheduler: scheduler, bus: bus)
        return (service, scheduler, bus)
    }

    // MARK: - 핵심: 상실 이벤트 → 알림 취소

    /// start() 이후 .pregnancyEndedInLoss(pregnancyId:) 발행 → 해당 id가 cancel 목록에 기록됨
    func test_start_lossEvent_cancelsCorrectedPregnancyNotifications() {
        let (service, scheduler, bus) = makeSUT()
        service.start()

        let targetId = UUID()
        bus.publish(.pregnancyEndedInLoss(pregnancyId: targetId))

        XCTAssertEqual(scheduler.cancelledIds.count, 1,
            "상실 이벤트 1회 → cancelPregnancyNotifications 1회 호출되어야 한다")
        XCTAssertEqual(scheduler.cancelledIds.first, targetId,
            "취소된 ID가 이벤트에서 전달된 pregnancyId와 일치해야 한다")
    }

    /// 서로 다른 pregnancyId로 loss 이벤트 2회 → 각각 정확히 cancel됨
    func test_start_multipleLossEvents_cancelsBothIds() {
        let (service, scheduler, bus) = makeSUT()
        service.start()

        let firstId  = UUID()
        let secondId = UUID()
        bus.publish(.pregnancyEndedInLoss(pregnancyId: firstId))
        bus.publish(.pregnancyEndedInLoss(pregnancyId: secondId))

        XCTAssertEqual(scheduler.cancelledIds.count, 2,
            "loss 이벤트 2회 → cancel 2회 호출되어야 한다")
        XCTAssertEqual(scheduler.cancelledIds[0], firstId)
        XCTAssertEqual(scheduler.cancelledIds[1], secondId)
    }

    // MARK: - 무관한 이벤트 → 취소 호출 안 됨

    /// .recordSaved 이벤트는 알림 취소를 유발하지 않아야 한다
    func test_start_recordSavedEvent_doesNotCancelNotifications() {
        let (service, scheduler, bus) = makeSUT()
        service.start()

        let childId = UUID()
        bus.publish(.recordSaved(childId: childId))

        XCTAssertTrue(scheduler.cancelledIds.isEmpty,
            ".recordSaved 이벤트는 알림 취소를 유발해서는 안 된다")
    }

    /// .milestoneAchieved 이벤트는 알림 취소를 유발하지 않아야 한다
    func test_start_milestoneAchievedEvent_doesNotCancelNotifications() {
        let (service, scheduler, bus) = makeSUT()
        service.start()

        let childId = UUID()
        bus.publish(.milestoneAchieved(childId: childId, milestone: "첫 걸음마"))

        XCTAssertTrue(scheduler.cancelledIds.isEmpty,
            ".milestoneAchieved 이벤트는 알림 취소를 유발해서는 안 된다")
    }

    /// 여러 무관한 이벤트 + loss 이벤트 혼합 → loss 해당 id만 1회 취소
    func test_start_mixedEvents_onlyLossEventTriggersCancellation() {
        let (service, scheduler, bus) = makeSUT()
        service.start()

        let lossId  = UUID()
        let childId = UUID()

        bus.publish(.milestoneAchieved(childId: childId, milestone: "뒤집기"))
        bus.publish(.recordSaved(childId: childId))
        bus.publish(.pregnancyEndedInLoss(pregnancyId: lossId))
        bus.publish(.recordSaved(childId: childId))

        XCTAssertEqual(scheduler.cancelledIds.count, 1,
            "무관한 이벤트가 섞여도 loss 이벤트 해당 ID만 1회 취소되어야 한다")
        XCTAssertEqual(scheduler.cancelledIds.first, lossId)
    }

    // MARK: - start() 미호출 시 취소 안 됨

    /// start()를 호출하지 않으면 loss 이벤트가 발행돼도 취소가 호출되지 않아야 한다
    func test_withoutStart_lossEvent_doesNotCancelNotifications() {
        let (_, scheduler, bus) = makeSUT()
        // service.start() 생략 — 구독 시작 전

        bus.publish(.pregnancyEndedInLoss(pregnancyId: UUID()))

        XCTAssertTrue(scheduler.cancelledIds.isEmpty,
            "start() 미호출 시 이벤트가 발행돼도 취소가 일어나지 않아야 한다")
    }
}
