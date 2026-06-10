// ProviderFactoryTests.swift
// BabyLogTests
//
// QA — ProviderFactory Mock 폴백 검증 (키 미설정 환경)
//
// ============================================================
// [계약 이탈 가능 지점]
//
// 1. APIConfig.key(_:) — 환경변수(ProcessInfo) 또는 Info.plist에서 읽음.
//    테스트 프로세스 환경에 실제 키가 주입되어 있으면 이 테스트들이
//    Live 프로바이더를 통해 실제 네트워크를 시도하므로 실패한다.
//    CI/CD에서는 해당 환경변수를 설정하지 않은 상태로 실행해야 한다.
//    (HIRA_API_KEY / KAKAO_REST_API_KEY / BOKJIRO_API_KEY / KDCA_VACCINE_API_KEY)
//
// 2. ProviderFactory.hospital() / place() / subsidy() / vaccine() 는
//    반환 타입이 각각 HospitalInfoProviding / PlaceSearching /
//    SubsidyProviding / VaccineScheduleProviding 프로토콜이다.
//    키 미설정 시 각각 MockHospitalInfoProvider / MockPlaceSearcher /
//    MockSubsidyProvider / MockVaccineScheduleProvider 를 반환함을
//    ProviderFactory.swift 소스에서 확인했다.
//
// 3. HospitalInfoProviding.hospitals(near:openNow:)
//    - near: Coordinate? 파라미터명 확인 완료 (PlaceSearching.swift)
//    - openNow: Bool 파라미터명 확인 완료 (HospitalInfoProviding.swift)
//    - openNow=true 시 Mock이 isOpenNow==true 항목만 필터링함을 소스 확인.
//
// 4. SubsidyProviding.subsidies(childAgeMonths:)
//    - childAgeMonths: 6 시 부모급여(0~11개월) + 아동수당 + 가정양육수당 + 보육료 포함.
//    - amountKRW > 0, eligibility 비어있지 않음을 Mock 소스에서 확인.
//
// 5. VaccineScheduleProviding.schedule(birthDate:)
//    - VaccineRecord.scheduledDate 는 Optional<Date> 이나,
//      Mock은 반드시 non-nil로 채워 반환함을 VaccineScheduleProviding.swift에서 확인.
//
// 6. PlaceSearching.search(_:near:)
//    - 첫 파라미터는 레이블 없는 String(query), 두 번째는 near: Coordinate?
//    - Mock은 쿼리 무관하게 고정된 5건 반환.
// ============================================================

import XCTest
@testable import BabyLog

// MARK: - APIConfig 키 미설정 검증

final class ProviderFactoryAPIConfigTests: XCTestCase {

    /// 존재하지 않는 키 이름으로 조회하면 nil을 반환해야 한다.
    func testAPIConfig_unknownKey_returnsNil() {
        let value = APIConfig.key("UNKNOWN_KEY_DEFINITELY_NOT_SET_12345")
        XCTAssertNil(value, "설정되지 않은 키는 nil을 반환해야 한다")
    }

    /// 빈 문자열 키 이름도 nil을 반환해야 한다.
    func testAPIConfig_emptyKeyName_returnsNil() {
        let value = APIConfig.key("")
        XCTAssertNil(value, "빈 문자열 키 이름은 nil을 반환해야 한다")
    }
}

// MARK: - ProviderFactory.hospital() Mock 폴백 검증

final class ProviderFactoryHospitalTests: XCTestCase {

    /// 키 미설정 환경에서 hospital() 반환 객체로 hospitals(near:openNow:) 호출 시
    /// 비어있지 않은 결과를 반환해야 한다(Mock 폴백 확인).
    func testHospital_mockFallback_returnsNonEmptyList() async throws {
        let provider = ProviderFactory.hospital()
        let coord = Coordinate(lat: 37.5665, lng: 126.9780)

        let hospitals = try await provider.hospitals(near: coord, openNow: false)

        XCTAssertFalse(
            hospitals.isEmpty,
            "키 미설정 시 Mock 폴백이 비어있지 않은 HospitalInfo 배열을 반환해야 한다"
        )
    }

    /// openNow=true 필터 적용 시 반환된 모든 HospitalInfo.isOpenNow가 true여야 한다.
    func testHospital_openNowTrue_allResultsAreOpen() async throws {
        let provider = ProviderFactory.hospital()

        let hospitals = try await provider.hospitals(near: nil, openNow: true)

        XCTAssertFalse(
            hospitals.isEmpty,
            "openNow=true 시 비어있지 않은 결과를 반환해야 한다"
        )

        for hospital in hospitals {
            XCTAssertTrue(
                hospital.isOpenNow,
                "openNow=true 필터 결과의 모든 항목은 isOpenNow==true여야 한다 (id: \(hospital.id))"
            )
        }
    }
}

// MARK: - ProviderFactory.subsidy() Mock 폴백 검증

final class ProviderFactorySubsidyTests: XCTestCase {

    /// 키 미설정 환경에서 subsidy().subsidies(childAgeMonths: 6) 호출 시
    /// 비어있지 않은 결과를 반환해야 하며 필드가 유효해야 한다.
    func testSubsidy_mockFallback_sixMonths_returnsNonEmptyWithValidFields() async throws {
        let provider = ProviderFactory.subsidy()

        let subsidies = try await provider.subsidies(childAgeMonths: 6)

        XCTAssertFalse(
            subsidies.isEmpty,
            "키 미설정 시 Mock 폴백이 childAgeMonths=6에서 비어있지 않은 SubsidyInfo를 반환해야 한다"
        )

        for subsidy in subsidies {
            XCTAssertFalse(
                subsidy.name.isEmpty,
                "SubsidyInfo.name은 빈 문자열이 아니어야 한다"
            )
            XCTAssertFalse(
                subsidy.eligibility.isEmpty,
                "SubsidyInfo.eligibility는 빈 문자열이 아니어야 한다"
            )
            XCTAssertGreaterThan(
                subsidy.amountKRW, 0,
                "SubsidyInfo.amountKRW는 0보다 커야 한다 (name: \(subsidy.name))"
            )
        }
    }
}

// MARK: - ProviderFactory.vaccine() Mock 폴백 검증

final class ProviderFactoryVaccineTests: XCTestCase {

    /// 키 미설정 환경에서 vaccine().schedule(birthDate:) 호출 시
    /// 비어있지 않은 결과를 반환해야 하며 scheduledDate가 non-nil이어야 한다.
    func testVaccine_mockFallback_returnsNonEmptyWithScheduledDates() async throws {
        let provider = ProviderFactory.vaccine()

        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 1
        let birthDate = Calendar.current.date(from: components)!

        let records = try await provider.schedule(birthDate: birthDate)

        XCTAssertFalse(
            records.isEmpty,
            "키 미설정 시 Mock 폴백이 비어있지 않은 VaccineRecord 배열을 반환해야 한다"
        )

        for record in records {
            let scheduled = try XCTUnwrap(
                record.scheduledDate,
                "VaccineRecord.scheduledDate는 nil이 아니어야 한다 (vaccineId: \(record.vaccineId))"
            )
            XCTAssertGreaterThanOrEqual(
                scheduled,
                birthDate,
                "scheduledDate(\(scheduled))는 birthDate(\(birthDate)) 이후여야 한다 (vaccineId: \(record.vaccineId))"
            )
        }
    }
}

// MARK: - ProviderFactory.place() Mock 폴백 검증

final class ProviderFactoryPlaceTests: XCTestCase {

    /// 키 미설정 환경에서 place().search("소아과", near: nil) 호출 시
    /// 비어있지 않은 결과를 반환해야 한다.
    func testPlace_mockFallback_searchPediatric_returnsNonEmptyList() async throws {
        let provider = ProviderFactory.place()

        let places = try await provider.search("소아과", near: nil)

        XCTAssertFalse(
            places.isEmpty,
            "키 미설정 시 Mock 폴백이 비어있지 않은 Place 배열을 반환해야 한다"
        )
    }
}
