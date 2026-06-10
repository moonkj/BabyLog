import XCTest
@testable import BabyLog

/// 네트워킹 인프라 테스트.
/// 파서는 공공 API 래퍼 형태(response.body.items.item[]) + 컨텍스트 인자를 받으므로,
/// happy-path 포맷별 픽스처는 실 API 연동 시 보강한다(현재는 에러 매핑·디코딩 실패 처리 검증).
final class NetworkingInfraTests: XCTestCase {

    private func utf8(_ s: String) -> Data { Data(s.utf8) }

    // MARK: - APIError Equatable

    func test_apiError_equatable() {
        XCTAssertEqual(APIError.http(404), APIError.http(404))
        XCTAssertNotEqual(APIError.http(404), APIError.http(500))
        XCTAssertEqual(APIError.decoding, APIError.decoding)
        XCTAssertNotEqual(APIError.decoding, APIError.transport)
        XCTAssertEqual(APIError.noAPIKey, APIError.noAPIKey)
        XCTAssertNotEqual(APIError.invalidURL, APIError.transport)
    }

    // MARK: - APIClient.mapHTTP

    func test_mapHTTP_success_returnsNil() {
        XCTAssertNil(APIClient.mapHTTP(200))
        XCTAssertNil(APIClient.mapHTTP(201))
        XCTAssertNil(APIClient.mapHTTP(204))
    }

    func test_mapHTTP_clientAndServerErrors_mapToHTTP() {
        XCTAssertEqual(APIClient.mapHTTP(400), .http(400))
        XCTAssertEqual(APIClient.mapHTTP(401), .http(401))
        XCTAssertEqual(APIClient.mapHTTP(404), .http(404))
        XCTAssertEqual(APIClient.mapHTTP(429), .http(429))
        XCTAssertEqual(APIClient.mapHTTP(500), .http(500))
        XCTAssertEqual(APIClient.mapHTTP(503), .http(503))
    }

    // MARK: - 파서: 잘못된 JSON → throws (포맷 무관)

    func test_hospitalParser_invalidJSON_throws() {
        XCTAssertThrowsError(try HospitalResponseParser.parse(utf8("INVALID")))
    }

    func test_placeParser_invalidJSON_throws() {
        XCTAssertThrowsError(try PlaceResponseParser.parse(utf8("INVALID")))
    }

    func test_subsidyParser_invalidJSON_throws() {
        XCTAssertThrowsError(try SubsidyResponseParser.parse(utf8("INVALID"), childAgeMonths: 6))
    }

    func test_vaccineParser_invalidJSON_throws() {
        XCTAssertThrowsError(try VaccineResponseParser.parse(utf8("INVALID"), birthDate: Date()))
    }

    // MARK: - 파서: 빈 래퍼 → 빈 결과 (item 없음)

    func test_subsidyParser_emptyWrapper_returnsEmpty() throws {
        let json = #"{"response":{"body":{"items":{}}}}"#
        let result = try SubsidyResponseParser.parse(utf8(json), childAgeMonths: 6)
        XCTAssertTrue(result.isEmpty)
    }

    func test_vaccineParser_emptyWrapper_returnsEmpty() throws {
        let json = #"{"response":{"body":{"items":{}}}}"#
        let result = try VaccineResponseParser.parse(utf8(json), birthDate: Date())
        XCTAssertTrue(result.isEmpty)
    }
}
