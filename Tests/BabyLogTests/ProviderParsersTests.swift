// ProviderParsersTests.swift
// 공공/지도 API 응답 순수 파서(QA 테스트 대상) — 행복/거리/전화정상화/연령필터/날짜파싱.
// LiveProviders의 IO와 분리된 순수 함수만 검증(네트워크 미사용).

import XCTest
@testable import BabyLog

final class ProviderParsersTests: XCTestCase {

    // MARK: - Haversine
    func test_haversine_samePointIsZero() {
        XCTAssertEqual(HospitalResponseParser.haversineMeters(lat1: 37.5, lng1: 127, lat2: 37.5, lng2: 127),
                       0, accuracy: 0.5)
    }
    func test_haversine_oneDegreeLatitudeApprox111km() {
        let d = HospitalResponseParser.haversineMeters(lat1: 37.0, lng1: 127, lat2: 38.0, lng2: 127)
        XCTAssertEqual(d, 111_195, accuracy: 2_000)
    }

    // MARK: - normalizedPhone (HIRA 지역번호 보정)
    func test_phone_addsSeoulAreaCode() {
        XCTAssertEqual(HospitalResponseParser.normalizedPhone("221-1122", sidoNm: "서울특별시"), "02-221-1122")
    }
    func test_phone_keepsExistingAreaCode() {
        XCTAssertEqual(HospitalResponseParser.normalizedPhone("02-221-1122", sidoNm: "서울특별시"), "02-221-1122")
    }
    func test_phone_keepsNationwide1588() {
        XCTAssertEqual(HospitalResponseParser.normalizedPhone("1588-1234", sidoNm: "서울특별시"), "1588-1234")
    }
    func test_phone_nilOrEmptyIsEmpty() {
        XCTAssertEqual(HospitalResponseParser.normalizedPhone(nil, sidoNm: "서울"), "")
        XCTAssertEqual(HospitalResponseParser.normalizedPhone("   ", sidoNm: "서울"), "")
    }
    func test_phone_chungbukFullName() {
        XCTAssertEqual(HospitalResponseParser.normalizedPhone("221-1122", sidoNm: "충청북도"), "043-221-1122")
    }

    // MARK: - Hospital parser
    private let hiraJSON = #"{"response":{"body":{"items":{"item":[{"ykiho":"H1","yadmNm":"행복소아과","addr":"서울 강남구","telno":"221-1122","dgsbjtCdNm":"소아청소년과","clCdNm":"의원","XPos":127.0,"YPos":37.5,"sidoCdNm":"서울특별시"}]}}}}"#

    func test_hospital_happyPath() throws {
        let resp = try JSONDecoder().decode(HIRAHospitalResponse.self, from: Data(hiraJSON.utf8))
        let result = try HospitalResponseParser.parse(resp, near: Coordinate(lat: 37.5, lng: 127.0))
        XCTAssertEqual(result.count, 1)
        let h = result[0]
        XCTAssertEqual(h.name, "행복소아과")
        XCTAssertEqual(h.phone, "02-221-1122", "지역번호 보정")
        XCTAssertEqual(h.department, "소아청소년과")
        XCTAssertFalse(h.hoursKnown, "HIRA 기본목록은 영업시간 미확인이어야 함(거짓 영업중 방지)")
        XCTAssertEqual(h.distanceM, 0, "같은 좌표 → 0m (haversine 직접계산)")
    }

    func test_hospital_emptyItems_returnsEmpty() throws {
        let r = try HospitalResponseParser.parse(Data(#"{"response":{"body":{"items":{}}}}"#.utf8))
        XCTAssertTrue(r.isEmpty)
    }

    func test_hospital_invalidJSON_throws() {
        XCTAssertThrowsError(try HospitalResponseParser.parse(Data("not json".utf8)))
    }

    // MARK: - Place parser (카카오)
    func test_place_trimsCategoryToLastSegment() throws {
        let json = #"{"documents":[{"id":"P1","place_name":"행복키즈카페","address_name":"서울 강남구","phone":"02-1","category_name":"가정,생활 > 육아 > 키즈카페","distance":"350"}]}"#
        let r = try PlaceResponseParser.parse(Data(json.utf8))
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].name, "행복키즈카페")
        XCTAssertEqual(r[0].category, "키즈카페", "카테고리는 '>' 마지막 세그먼트만")
        XCTAssertEqual(r[0].distanceM, 350)
    }

    // MARK: - Subsidy parser (연령 필터)
    private func bokjiro(min: String, max: String) -> Data {
        Data(#"{"response":{"body":{"items":{"item":[{"wlfareSno":"S1","wlfareName":"부모급여","minAge":"\#(min)","maxAge":"\#(max)","paymentAmount":"1000000","applyUrl":"https://www.bokjiro.go.kr","wlfareOverview":"설명"}]}}}}"#.utf8)
    }
    func test_subsidy_includedWithinAgeRange() throws {
        let r = try SubsidyResponseParser.parse(bokjiro(min: "0", max: "11"), childAgeMonths: 6)
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].amountKRW, 1_000_000)
    }
    func test_subsidy_excludedOutsideAgeRange() throws {
        let r = try SubsidyResponseParser.parse(bokjiro(min: "0", max: "11"), childAgeMonths: 20)
        XCTAssertTrue(r.isEmpty)
    }
    func test_subsidy_boundaryMaxAgeInclusive() throws {
        let r = try SubsidyResponseParser.parse(bokjiro(min: "0", max: "11"), childAgeMonths: 11)
        XCTAssertEqual(r.count, 1)
    }

    // MARK: - Vaccine parser (KDCA)
    func test_vaccine_parsesDateAndSentinelChildId() throws {
        let json = #"{"response":{"body":{"items":{"item":[{"vaccineCode":"BCG","vaccineName":"결핵(BCG)","scheduledDate":"20240115","orderNo":"1"}]}}}}"#
        let r = try VaccineResponseParser.parse(Data(json.utf8), birthDate: Date())
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].vaccineId, "BCG")
        XCTAssertEqual(r[0].childId, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        XCTAssertNotNil(r[0].scheduledDate)
    }
    func test_vaccine_invalidJSON_throws() {
        XCTAssertThrowsError(try VaccineResponseParser.parse(Data("x".utf8), birthDate: Date()))
    }
}
