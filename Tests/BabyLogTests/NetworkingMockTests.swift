// NetworkingMockTests.swift
// BabyLogTests
//
// QA — 네트워킹 Mock 결정적 데이터 반환 검증
//
// ============================================================
// [계약과 어긋날 수 있는 지점]
//
// 1. MockVaccineScheduleProvider
//    - 계약: schedule(birthDate:) async throws -> [VaccineRecord]
//    - VaccineRecord는 현재 Models.swift에 정의되어 있고
//      childId, vaccineId, scheduledDate? 필드를 가진다.
//    - 어긋날 수 있는 점: scheduledDate가 Optional이므로
//      구현이 nil로 채워 반환하면 "birthDate 이후" 검증이 통과하지 못한다.
//      → Mock은 반드시 non-nil scheduledDate를 반환해야 한다.
//    - VaccineRecord.childId가 어떤 값으로 채워지는지 계약 미정.
//      Mock이 UUID()를 채워도 되는지, 아니면 파라미터 birthDate에서
//      연산하는지 코더 합의 필요.
//
// 2. MockPlaceSearcher
//    - 계약: search(_:near:) async throws -> [Place]
//    - Place{id,name,address,phone,category,distanceM,rating} 구조체 기대.
//    - Coordinate{lat,lng} 파라미터가 near: 레이블인지 확인 필요.
//    - rating 타입이 Double인지 Float인지 계약 미정 (테스트는 Double 가정).
//    - category가 String인지 enum인지 미정 (테스트는 String 가정).
//
// 3. MockHospitalInfoProvider
//    - 계약: hospitals(near:openNow:) async throws -> [HospitalInfo]
//    - HospitalInfo{...,isOpenNow,lastCheckedMinutesAgo,distanceM,rating}.
//    - openNow: true 필터 시 isOpenNow==true인 항목만 반환해야 하는지,
//      아니면 전체를 반환하고 클라이언트가 필터링하는지 계약 미정.
//      이 테스트는 Mock이 필터를 적용하는 것을 기대한다.
//    - lastCheckedMinutesAgo의 타입이 Int인지 Double인지 미정
//      (테스트는 Int 가정).
//
// 4. MockSubsidyProvider
//    - 계약: subsidies(childAgeMonths:) async throws -> [SubsidyInfo]
//    - SubsidyInfo{id,name,amountKRW,eligibility,applyURL?}.
//    - applyURL의 타입이 URL인지 String?인지 미정 (테스트는 존재 여부만 검증).
//    - childAgeMonths: Int 가정. 음수나 매우 큰 값에서 에러 vs 빈 배열 반환
//      정책 미정.
//    - 각 월령대(신생아/6개월/12개월)에서 반드시 비어있지 않은 결과를
//      반환한다고 가정하나, 특정 월령이 지원금 대상 외라면 빈 배열이
//      정상일 수도 있다 — 코더와 합의 필요.
// ============================================================

import XCTest
@testable import BabyLog

// MARK: - Helpers

/// "yyyy-MM-dd" 문자열을 현지 그레고리안 자정으로 변환하는 헬퍼
private func makeDate(_ s: String) -> Date {
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.timeZone = .current
    fmt.dateFormat = "yyyy-MM-dd"
    guard let date = fmt.date(from: s) else {
        fatalError("날짜 파싱 실패: \(s)")
    }
    return date
}

// MARK: - VaccineSchedule Tests

final class NetworkingMockVaccineTests: XCTestCase {

    // MARK: - 항목 수 > 0

    /// Mock이 birthDate를 받아 비어있지 않은 VaccineRecord 배열을 반환해야 한다.
    func test_mockVaccineSchedule_returnsNonEmptyList() async throws {
        let mock = MockVaccineScheduleProvider()
        let birthDate = makeDate("2025-01-01")

        let records = try await mock.schedule(birthDate: birthDate)

        XCTAssertFalse(records.isEmpty,
            "MockVaccineScheduleProvider.schedule(birthDate:)는 비어있지 않은 결과를 반환해야 한다")
        XCTAssertGreaterThan(records.count, 0,
            "예방접종 스케줄 항목 수는 1개 이상이어야 한다")
    }

    // MARK: - scheduledDate가 birthDate 이후

    /// 모든 VaccineRecord의 scheduledDate는 non-nil이고 birthDate 이후여야 한다.
    func test_mockVaccineSchedule_allScheduledDatesAfterBirthDate() async throws {
        let mock = MockVaccineScheduleProvider()
        let birthDate = makeDate("2025-06-01")

        let records = try await mock.schedule(birthDate: birthDate)

        XCTAssertFalse(records.isEmpty,
            "검증을 위해 반환 결과가 비어있지 않아야 한다")

        for record in records {
            let scheduled = try XCTUnwrap(
                record.scheduledDate,
                "VaccineRecord.scheduledDate는 nil이 아니어야 한다 (vaccineId: \(record.vaccineId))"
            )
            XCTAssertGreaterThanOrEqual(
                scheduled,
                birthDate,
                "scheduledDate(\(scheduled))가 birthDate(\(birthDate)) 이후여야 한다 (vaccineId: \(record.vaccineId))"
            )
        }
    }

    // MARK: - 서로 다른 birthDate → 서로 다른 스케줄

    /// birthDate가 달라지면 scheduledDate도 그에 맞게 이동해야 한다(결정적 일관성).
    func test_mockVaccineSchedule_differentBirthDates_produceDifferentSchedules() async throws {
        let mock = MockVaccineScheduleProvider()
        let birth1 = makeDate("2025-01-01")
        let birth2 = makeDate("2025-06-01")

        let records1 = try await mock.schedule(birthDate: birth1)
        let records2 = try await mock.schedule(birthDate: birth2)

        guard let first1 = records1.first?.scheduledDate,
              let first2 = records2.first?.scheduledDate else {
            XCTFail("두 결과 모두 scheduledDate를 가진 첫 번째 항목이 있어야 한다")
            return
        }

        XCTAssertNotEqual(
            first1, first2,
            "birthDate가 다르면 첫 번째 scheduledDate도 달라야 한다 (결정적 오프셋 검증)"
        )
    }

    // MARK: - vaccineId 비어있지 않음

    /// 반환된 모든 VaccineRecord의 vaccineId는 빈 문자열이 아니어야 한다.
    func test_mockVaccineSchedule_allVaccineIdsNonEmpty() async throws {
        let mock = MockVaccineScheduleProvider()
        let birthDate = makeDate("2025-03-15")

        let records = try await mock.schedule(birthDate: birthDate)

        for record in records {
            XCTAssertFalse(
                record.vaccineId.isEmpty,
                "vaccineId는 빈 문자열이 아니어야 한다"
            )
        }
    }
}

// MARK: - PlaceSearcher Tests

final class NetworkingMockPlaceSearcherTests: XCTestCase {

    // MARK: - 비어있지 않은 결과

    /// 키워드와 좌표를 주면 비어있지 않은 Place 배열을 반환해야 한다.
    func test_mockPlaceSearcher_returnsNonEmptyList() async throws {
        let mock = MockPlaceSearcher()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780) // 서울 중심

        let places = try await mock.search("키즈카페", near: coord)

        XCTAssertFalse(places.isEmpty,
            "MockPlaceSearcher.search(_:near:)는 비어있지 않은 Place 배열을 반환해야 한다")
    }

    // MARK: - 필수 필드 채워짐

    /// 반환된 모든 Place는 name, address, category가 빈 문자열이 아니어야 한다.
    func test_mockPlaceSearcher_allRequiredFieldsNonEmpty() async throws {
        let mock = MockPlaceSearcher()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let places = try await mock.search("소아과", near: coord)

        XCTAssertFalse(places.isEmpty, "검증을 위해 결과가 비어있지 않아야 한다")

        for place in places {
            XCTAssertFalse(place.name.isEmpty,
                "Place.name은 빈 문자열이 아니어야 한다")
            XCTAssertFalse(place.address.isEmpty,
                "Place.address는 빈 문자열이 아니어야 한다")
            XCTAssertFalse(place.category.isEmpty,
                "Place.category는 빈 문자열이 아니어야 한다")
        }
    }

    // MARK: - distanceM >= 0

    /// 모든 Place.distanceM은 0 이상이어야 한다.
    func test_mockPlaceSearcher_allDistancesNonNegative() async throws {
        let mock = MockPlaceSearcher()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let places = try await mock.search("약국", near: coord)

        for place in places {
            XCTAssertGreaterThanOrEqual(
                place.distanceM, 0,
                "Place.distanceM은 0 이상이어야 한다 (name: \(place.name))"
            )
        }
    }

    // MARK: - rating 범위

    /// 모든 Place.rating은 0.0~5.0 사이여야 한다.
    func test_mockPlaceSearcher_ratingsInValidRange() async throws {
        let mock = MockPlaceSearcher()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let places = try await mock.search("키즈카페", near: coord)

        for place in places {
            XCTAssertGreaterThanOrEqual(place.rating, 0.0,
                "Place.rating은 0.0 이상이어야 한다")
            XCTAssertLessThanOrEqual(place.rating, 5.0,
                "Place.rating은 5.0 이하여야 한다")
        }
    }

    // MARK: - id 유일성

    /// 반환된 모든 Place의 id는 서로 달라야 한다.
    func test_mockPlaceSearcher_allIdsUnique() async throws {
        let mock = MockPlaceSearcher()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let places = try await mock.search("병원", near: coord)

        let ids = places.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(
            ids.count, uniqueIds.count,
            "반환된 모든 Place의 id는 서로 달라야 한다"
        )
    }
}

// MARK: - HospitalInfoProvider Tests

final class NetworkingMockHospitalInfoTests: XCTestCase {

    // MARK: - openNow 필터 없이 비어있지 않음

    /// openNow=false(필터 없음)로 호출하면 비어있지 않은 결과를 반환해야 한다.
    func test_mockHospitalInfo_noFilter_returnsNonEmptyList() async throws {
        let mock = MockHospitalInfoProvider()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await mock.hospitals(near: coord, openNow: false)

        XCTAssertFalse(hospitals.isEmpty,
            "openNow=false 시 비어있지 않은 결과를 반환해야 한다")
    }

    // MARK: - openNow=true 필터 시 모두 isOpenNow==true

    /// openNow=true 필터 적용 시 반환된 모든 HospitalInfo.isOpenNow가 true여야 한다.
    func test_mockHospitalInfo_openNowFilter_allAreOpen() async throws {
        let mock = MockHospitalInfoProvider()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await mock.hospitals(near: coord, openNow: true)

        XCTAssertFalse(hospitals.isEmpty,
            "openNow=true 필터 시 비어있지 않은 결과를 반환해야 한다")

        for hospital in hospitals {
            XCTAssertTrue(
                hospital.isOpenNow,
                "openNow=true 필터 결과의 모든 HospitalInfo.isOpenNow는 true여야 한다 (name 확인 가능 시 확인)"
            )
        }
    }

    // MARK: - openNow=false 결과에 isOpenNow=false 항목 포함

    /// openNow=false로 호출하면 isOpenNow==false인 항목이 적어도 하나 포함되어야 한다.
    /// (Mock이 실제로 닫힌 병원 데이터를 제공하는지 검증)
    func test_mockHospitalInfo_noFilter_containsClosedHospitals() async throws {
        let mock = MockHospitalInfoProvider()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await mock.hospitals(near: coord, openNow: false)

        let hasClosedHospital = hospitals.contains { !$0.isOpenNow }
        XCTAssertTrue(hasClosedHospital,
            "openNow=false 결과에 isOpenNow=false 항목이 최소 1개 포함되어야 한다 (결정적 Mock 데이터 검증)")
    }

    // MARK: - lastCheckedMinutesAgo >= 0

    /// 모든 HospitalInfo.lastCheckedMinutesAgo는 0 이상이어야 한다.
    func test_mockHospitalInfo_lastCheckedMinutesAgoNonNegative() async throws {
        let mock = MockHospitalInfoProvider()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await mock.hospitals(near: coord, openNow: false)

        for hospital in hospitals {
            XCTAssertGreaterThanOrEqual(
                hospital.lastCheckedMinutesAgo, 0,
                "HospitalInfo.lastCheckedMinutesAgo는 0 이상이어야 한다"
            )
        }
    }

    // MARK: - distanceM >= 0, rating 범위

    /// HospitalInfo.distanceM >= 0, rating 0.0~5.0.
    func test_mockHospitalInfo_distanceAndRatingInValidRange() async throws {
        let mock = MockHospitalInfoProvider()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await mock.hospitals(near: coord, openNow: false)

        for hospital in hospitals {
            XCTAssertGreaterThanOrEqual(hospital.distanceM, 0,
                "HospitalInfo.distanceM은 0 이상이어야 한다")
            XCTAssertGreaterThanOrEqual(hospital.rating, 0.0,
                "HospitalInfo.rating은 0.0 이상이어야 한다")
            XCTAssertLessThanOrEqual(hospital.rating, 5.0,
                "HospitalInfo.rating은 5.0 이하여야 한다")
        }
    }
}

// MARK: - SubsidyProvider Tests

final class NetworkingMockSubsidyTests: XCTestCase {

    // MARK: - 신생아(0개월) 지원금 비어있지 않음

    /// childAgeMonths=0(신생아)에서 비어있지 않은 SubsidyInfo 배열을 반환해야 한다.
    func test_mockSubsidy_newborn_returnsNonEmptyList() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 0)

        XCTAssertFalse(subsidies.isEmpty,
            "childAgeMonths=0(신생아)에서 비어있지 않은 SubsidyInfo를 반환해야 한다")
    }

    // MARK: - 6개월 지원금 비어있지 않음

    /// childAgeMonths=6에서 비어있지 않은 SubsidyInfo 배열을 반환해야 한다.
    func test_mockSubsidy_sixMonths_returnsNonEmptyList() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 6)

        XCTAssertFalse(subsidies.isEmpty,
            "childAgeMonths=6에서 비어있지 않은 SubsidyInfo를 반환해야 한다")
    }

    // MARK: - 12개월 지원금 비어있지 않음

    /// childAgeMonths=12에서 비어있지 않은 SubsidyInfo 배열을 반환해야 한다.
    func test_mockSubsidy_twelveMonths_returnsNonEmptyList() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 12)

        XCTAssertFalse(subsidies.isEmpty,
            "childAgeMonths=12에서 비어있지 않은 SubsidyInfo를 반환해야 한다")
    }

    // MARK: - 필수 필드 채워짐

    /// 반환된 모든 SubsidyInfo의 name, eligibility는 빈 문자열이 아니어야 한다.
    func test_mockSubsidy_allRequiredFieldsNonEmpty() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 0)

        XCTAssertFalse(subsidies.isEmpty, "검증을 위해 결과가 비어있지 않아야 한다")

        for subsidy in subsidies {
            XCTAssertFalse(subsidy.name.isEmpty,
                "SubsidyInfo.name은 빈 문자열이 아니어야 한다")
            XCTAssertFalse(subsidy.eligibility.isEmpty,
                "SubsidyInfo.eligibility는 빈 문자열이 아니어야 한다")
        }
    }

    // MARK: - amountKRW > 0

    /// 반환된 모든 SubsidyInfo.amountKRW는 0보다 커야 한다.
    func test_mockSubsidy_allAmountsPositive() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 0)

        for subsidy in subsidies {
            XCTAssertGreaterThan(
                subsidy.amountKRW, 0,
                "SubsidyInfo.amountKRW는 0보다 커야 한다 (name: \(subsidy.name))"
            )
        }
    }

    // MARK: - id 유일성

    /// 반환된 모든 SubsidyInfo의 id는 서로 달라야 한다.
    func test_mockSubsidy_allIdsUnique() async throws {
        let mock = MockSubsidyProvider()

        let subsidies = try await mock.subsidies(childAgeMonths: 0)

        let ids = subsidies.map { $0.id }
        let uniqueIds = Set(ids)

        XCTAssertEqual(
            ids.count, uniqueIds.count,
            "반환된 모든 SubsidyInfo의 id는 서로 달라야 한다"
        )
    }

    // MARK: - 월령별 결과 결정적 일관성

    /// 동일한 childAgeMonths로 두 번 호출하면 동일한 id 집합을 반환해야 한다.
    func test_mockSubsidy_deterministicForSameMonths() async throws {
        let mock = MockSubsidyProvider()

        let first = try await mock.subsidies(childAgeMonths: 3)
        let second = try await mock.subsidies(childAgeMonths: 3)

        let firstIds = Set(first.map { $0.id })
        let secondIds = Set(second.map { $0.id })

        XCTAssertEqual(firstIds, secondIds,
            "동일한 childAgeMonths로 두 번 호출하면 동일한 id 집합을 반환해야 한다 (결정적 Mock 검증)")
    }
}
