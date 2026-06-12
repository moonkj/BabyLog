// LiveProviders.swift
// BabyLog — Networking
//
// 각 프로토콜의 Live 구현 + 순수 응답 파서.
// 키 미설정 시 Mock 프로바이더로 자동 폴백합니다 (B4 정책).
//
// ⚠️ 의료·병원 정보는 의료 상담을 대체하지 않습니다.
//    응급상황에는 119에 연락하거나 인근 응급실을 방문하세요.
//    모든 지원금 정보는 복지로(www.bokjiro.go.kr) 또는 주민센터에서 확인하세요.
//
// NOTE: 실제 API 키는 절대 이 파일에 하드코딩하지 않습니다.

import Foundation

// ============================================================
// MARK: - LiveHospitalInfoProvider
// ============================================================

/// 건강보험심사평가원 API Live 구현
/// 키 없으면 MockHospitalInfoProvider로 위임
///
/// ⚠️ 이 정보는 의료 상담을 대체하지 않습니다.
final class LiveHospitalInfoProvider: HospitalInfoProviding {

    private let client: APIClient
    private let fallback: HospitalInfoProviding
    private let endpoint: String      // 병원/약국 등 basis 엔드포인트
    private let dgsbjtCd: String?     // 진료과목코드(병원=11 소아과, 약국=nil)

    init(client: APIClient = APIClient(),
         fallback: HospitalInfoProviding = MockHospitalInfoProvider(),
         endpoint: String = LiveHospitalInfoProvider.hospitalEndpoint,
         dgsbjtCd: String? = "11") {
        self.client = client
        self.fallback = fallback
        self.endpoint = endpoint
        self.dgsbjtCd = dgsbjtCd
    }

    static let hospitalEndpoint = "https://apis.data.go.kr/B551182/hospInfoServicev2/getHospBasisList"
    static let pharmacyEndpoint = "https://apis.data.go.kr/B551182/pharmacyInfoService/getParmacyBasisList"

    func hospitals(near coordinate: Coordinate?, openNow: Bool) async throws -> [HospitalInfo] {
        guard let key = APIConfig.key(APIConfig.hiraKeyName) else {
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
        do {
            // 반경 검색 — HIRA radius는 API가 거리순 정렬 + distance 제공.
            // 단일 호출이라 빠르고, '집앞'이 항상 최상단에 온다.
            // (행정구역/probe 방식은 numOfRows=1 probe가 '가장 가까운 1곳'을 보장하지 못해
            //  엉뚱한 구를 골라 집앞이 누락되는 문제가 있어 반경 방식으로 통일.)
            var results: [HospitalInfo]
            do {
                results = try await radiusHospitals(key: key, coord: coordinate)
            } catch {
                // data.go.kr 일시 혼잡(504 등) — 0.7초 후 1회 재시도 후에야 Mock 폴백.
                try? await Task.sleep(nanoseconds: 700_000_000)
                results = try await radiusHospitals(key: key, coord: coordinate)
            }
            if openNow { results = results.filter { $0.isOpenNow } }
            results.sort { $0.distanceM < $1.distanceM }   // 좌표 기반 거리순(가까운 곳 먼저)
            return results
        } catch {
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
    }

    /// dgsbjtCd가 설정돼 있으면 쿼리에 추가(병원=소아과 필터, 약국=없음).
    private func appendDgsbjt(_ items: inout [URLQueryItem]) {
        if let d = dgsbjtCd { items.append(.init(name: "dgsbjtCd", value: d)) }
    }

    /// 좌표 기반 반경 검색 — 거리순 정렬되어 가까운 곳(집앞)부터 numOfRows만큼.
    private func radiusHospitals(key: String, coord: Coordinate?) async throws -> [HospitalInfo] {
        let lat = coord?.lat ?? 37.5665, lng = coord?.lng ?? 126.9780
        var c = URLComponents(string: endpoint)!
        var items: [URLQueryItem] = [
            .init(name: "serviceKey", value: key), .init(name: "pageNo", value: "1"),
            // numOfRows를 크게 — 반경 내 결과를 '전부' 받아 클라이언트에서 거리순 정렬한다.
            // (100이면 반경 내 기관이 100개를 넘을 때 가까운 곳이 잘려 '집앞'이 누락됨)
            .init(name: "numOfRows", value: "1000"),
            .init(name: "xPos", value: String(lng)), .init(name: "yPos", value: String(lat)),
            .init(name: "radius", value: "20000"),   // 시/군 전체를 아우르도록 넉넉히
            .init(name: "_type", value: "json"),
        ]
        appendDgsbjt(&items)
        c.queryItems = items
        guard let url = c.url else { return [] }
        let resp = try await client.get(url, as: HIRAHospitalResponse.self)
        return try HospitalResponseParser.parse(resp, near: coord)
    }
}

// ============================================================
// MARK: - HospitalResponseParser (QA 테스트 대상)
// ============================================================

/// 건강보험심사평가원 응답 DTO → HospitalInfo 순수 파서
///
/// QA 샘플 JSON 형태:
/// ```json
/// {
///   "response": {
///     "body": {
///       "items": {
///         "item": [
///           {
///             "ykiho": "B1179839",
///             "yadmNm": "연세아동병원",
///             "addr": "서울특별시 마포구 토정로 35",
///             "telno": "02-1111-2222",
///             "dgsbjtCdNm": "소아청소년과",
///             "clCdNm": "의원",
///             "distance": "410"
///           }
///         ]
///       }
///     }
///   }
/// }
/// ```
enum HospitalResponseParser {

    /// 건강보험심사평가원 응답을 `[HospitalInfo]`로 변환합니다.
    /// - Parameter response: `HIRAHospitalResponse` 디코딩 결과
    /// - Returns: `HospitalInfo` 배열
    static func parse(_ response: HIRAHospitalResponse, near userCoord: Coordinate? = nil) throws -> [HospitalInfo] {
        guard let items = response.response?.body?.items?.item else {
            return []
        }
        return items.map { item in
            let lat = item.ypos
            let lng = item.xpos
            // 거리: 사용자 좌표 + 기관 좌표가 있으면 직접 계산(API distance 비신뢰), 없으면 API distance 폴백
            let dist: Int
            if let uc = userCoord, let lat, let lng {
                dist = Int(haversineMeters(lat1: uc.lat, lng1: uc.lng, lat2: lat, lng2: lng))
            } else {
                dist = Int(item.distanceMeters ?? 0)
            }
            return HospitalInfo(
                id: item.ykiho ?? UUID().uuidString,
                name: item.yadmNm ?? "알 수 없음",
                address: item.addr ?? "",
                phone: normalizedPhone(item.telno, sidoNm: item.sidoCdNm),
                department: item.dgsbjtCdNm ?? item.clCdNm ?? "",
                // HIRA basis API는 실시간 영업 여부를 주지 않음 → 노출되도록 true(미상).
                // 화면에 "영업 정보는 공공데이터 기반, 방문 전 확인" 면책 있음.
                isOpenNow: true,
                lastCheckedMinutesAgo: 0,
                distanceM: dist,
                rating: 0.0,                // HIRA API는 평점 미제공
                latitude: lat,
                longitude: lng
            )
        }
    }

    /// HIRA telno 정상화 — HIRA는 시내번호의 지역번호를 자주 생략한다(예: "221-1122").
    /// 그대로 두면 휴대폰에서 잘못 걸리거나 "2-211-122"처럼 이상하게 표기되므로,
    /// 0/1로 시작하지 않는 시내번호엔 시도(sidoCdNm) 기준 지역번호를 앞에 붙인다.
    static func normalizedPhone(_ raw: String?, sidoNm: String?) -> String {
        guard let raw else { return "" }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        // 이미 지역번호(0…) 또는 전국대표번호(1588 등)면 그대로
        if t.hasPrefix("0") || t.hasPrefix("1") { return t }
        guard let code = areaCode(forSido: sidoNm) else { return t }
        return "\(code)-\(t)"
    }

    /// 시도명 → 지역번호. (HIRA sidoCdNm 표기 기준)
    private static func areaCode(forSido nm: String?) -> String? {
        guard let nm else { return nil }
        let map: [String: String] = [
            "서울": "02", "부산": "051", "대구": "053", "인천": "032",
            "광주": "062", "대전": "042", "울산": "052", "세종": "044",
            "경기": "031", "강원": "033", "충북": "043", "충남": "041",
            "전북": "063", "전남": "061", "경북": "054", "경남": "055",
            "제주": "064",
        ]
        if let exact = map[nm] { return exact }
        // "충청북도"·"서울특별시"처럼 풀네임으로 와도 매칭
        for (k, v) in map where nm.hasPrefix(k) { return v }
        return nil
    }

    /// 두 좌표 간 직선거리(미터) — Haversine.
    static func haversineMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let R = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat/2) * sin(dLat/2)
            + cos(lat1 * .pi/180) * cos(lat2 * .pi/180) * sin(dLng/2) * sin(dLng/2)
        return R * 2 * atan2(sqrt(a), sqrt(1-a))
    }

    /// 원시 JSON Data를 직접 파싱합니다 (QA 단위 테스트용).
    /// - Parameter data: JSON 원시 데이터
    /// - Returns: `HospitalInfo` 배열
    /// - Throws: `APIError.decoding`
    static func parse(_ data: Data) throws -> [HospitalInfo] {
        do {
            let response = try JSONDecoder().decode(HIRAHospitalResponse.self, from: data)
            return try parse(response)
        } catch {
            throw APIError.decoding
        }
    }
}

// MARK: HIRA DTO

struct HIRAHospitalResponse: Decodable {
    let response: HIRABody?
}

struct HIRABody: Decodable {
    let body: HIRABodyInner?
}

struct HIRABodyInner: Decodable {
    let items: HIRAItems?
}

struct HIRAItems: Decodable {
    /// 단일 결과는 객체, 복수는 배열로 오는 공공 API 특성 대응
    let item: [HIRAHospitalItem]?

    /// 한 건이 깨져도 전체가 날아가지 않도록 요소 단위로 관대하게 디코딩하는 래퍼.
    /// (HIRA가 한 레코드의 필드 타입을 예외적으로 다르게 보내도 그 한 건만 버린다.)
    private struct Failable: Decodable {
        let value: HIRAHospitalItem?
        init(from decoder: Decoder) throws { value = try? HIRAHospitalItem(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // 배열: 요소 단위 관대 디코딩 → 깨진 한 건만 제외하고 나머지는 모두 보존
        // (기존 all-or-nothing 디코딩은 충북 약국 745건 중 한 건만 타입이 어긋나도
        //  한 페이지 전체가 사라져 '가까운 약국이 누락'되는 버그가 있었다.)
        if let array = try? container.decode([Failable].self, forKey: .item) {
            item = array.compactMap(\.value)
        } else if let single = try? container.decode(HIRAHospitalItem.self, forKey: .item) {
            item = [single]
        } else {
            item = nil
        }
    }

    enum CodingKeys: String, CodingKey { case item }
}

struct HIRAHospitalItem: Decodable {
    let ykiho: String?      // 요양기관 기호 (고유 ID)
    let yadmNm: String?     // 요양기관명
    let addr: String?       // 주소
    let telno: String?      // 전화번호
    let dgsbjtCdNm: String? // 진료과목명
    let clCdNm: String?     // 종별 코드명 (의원/병원 등)
    // ⚠️ HIRA는 distance/XPos/YPos/코드를 레코드마다 문자열 또는 숫자로 섞어 보냄 → 둘 다 허용
    let distanceMeters: Double?  // 거리(미터)
    let xpos: Double?            // 경도
    let ypos: Double?            // 위도
    let sidoCd: String?          // 시도코드(행정구역 단위 조회용)
    let sgguCd: String?          // 시군구코드(좁은 단위 조회용 — 빠름)
    let sidoCdNm: String?        // 시도명(지역번호 보정용)

    enum CodingKeys: String, CodingKey {
        case ykiho, yadmNm, addr, telno, dgsbjtCdNm, clCdNm, distance, XPos, YPos, sidoCd, sgguCd, sidoCdNm
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 문자열 필드도 flexString으로 — HIRA가 telno 등을 숫자로 보내도 그 한 건을 버리지 않는다.
        ykiho = HIRAHospitalItem.flexString(c, .ykiho)
        yadmNm = HIRAHospitalItem.flexString(c, .yadmNm)
        addr = HIRAHospitalItem.flexString(c, .addr)
        telno = HIRAHospitalItem.flexString(c, .telno)
        dgsbjtCdNm = HIRAHospitalItem.flexString(c, .dgsbjtCdNm)
        clCdNm = HIRAHospitalItem.flexString(c, .clCdNm)
        distanceMeters = HIRAHospitalItem.flexDouble(c, .distance)
        xpos = HIRAHospitalItem.flexDouble(c, .XPos)
        ypos = HIRAHospitalItem.flexDouble(c, .YPos)
        sidoCd = HIRAHospitalItem.flexString(c, .sidoCd)
        sgguCd = HIRAHospitalItem.flexString(c, .sgguCd)
        sidoCdNm = HIRAHospitalItem.flexString(c, .sidoCdNm)
    }

    /// 문자열·숫자 어느 쪽이든 Double로 안전 변환.
    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    /// 문자열·정수·실수 어느 쪽이든 String으로 안전 변환(코드값·전화번호 등).
    private static func flexString(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return s }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) {
            // 정수형 실수는 소수점 없이(예: 전화번호가 숫자로 온 경우)
            return d == d.rounded() ? String(Int(d)) : String(d)
        }
        return nil
    }
}

// ============================================================
// MARK: - LivePlaceSearcher
// ============================================================

/// 카카오맵 로컬 API Live 구현
/// 키 없으면 MockPlaceSearcher로 위임
final class LivePlaceSearcher: PlaceSearching {

    private let client: APIClient
    private let fallback: PlaceSearching

    init(client: APIClient = APIClient(),
         fallback: PlaceSearching = MockPlaceSearcher()) {
        self.client = client
        self.fallback = fallback
    }

    func search(_ query: String, near coordinate: Coordinate?) async throws -> [Place] {
        guard let key = APIConfig.key(APIConfig.kakaoRESTKeyName) else {
            return try await fallback.search(query, near: coordinate)
        }

        guard var components = URLComponents(string: "https://dapi.kakao.com/v2/local/search/keyword.json") else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "x", value: String(coordinate?.lng ?? 126.9780)),
            URLQueryItem(name: "y", value: String(coordinate?.lat ?? 37.5665)),
            URLQueryItem(name: "radius", value: "5000"),
            URLQueryItem(name: "size", value: "15"),
            URLQueryItem(name: "sort", value: "distance"),
        ]

        guard let url = components.url else {
            return try await fallback.search(query, near: coordinate)
        }

        // 네트워크·파싱 실패 시 샘플로 graceful 폴백
        do {
            var request = URLRequest(url: url)
            request.setValue("KakaoAK \(key)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await client.session.data(for: request)
            if let http = response as? HTTPURLResponse,
               let err = APIClient.mapHTTP(http.statusCode) { throw err }
            let decoded = try JSONDecoder().decode(KakaoPlaceResponse.self, from: data)
            return try PlaceResponseParser.parse(decoded)
        } catch {
            return try await fallback.search(query, near: coordinate)
        }
    }
}

// ============================================================
// MARK: - PlaceResponseParser (QA 테스트 대상)
// ============================================================

/// 카카오맵 로컬 API 응답 DTO → Place 순수 파서
///
/// QA 샘플 JSON 형태:
/// ```json
/// {
///   "documents": [
///     {
///       "id": "12345678",
///       "place_name": "하늘키즈카페",
///       "address_name": "서울특별시 마포구 월드컵북로 56",
///       "phone": "02-1234-5678",
///       "category_name": "가정,생활 > 육아 > 키즈카페",
///       "distance": "320"
///     }
///   ]
/// }
/// ```
enum PlaceResponseParser {

    static func parse(_ response: KakaoPlaceResponse) throws -> [Place] {
        return response.documents.map { doc in
            Place(
                id: doc.id,
                name: doc.placeName,
                address: doc.addressName,
                phone: doc.phone,
                category: doc.categoryName.components(separatedBy: ">").last?.trimmingCharacters(in: .whitespaces) ?? doc.categoryName,
                distanceM: Int(doc.distance) ?? 0,
                rating: 0.0  // 카카오 로컬 API는 평점 미제공
            )
        }
    }

    static func parse(_ data: Data) throws -> [Place] {
        do {
            let response = try JSONDecoder().decode(KakaoPlaceResponse.self, from: data)
            return try parse(response)
        } catch {
            throw APIError.decoding
        }
    }
}

// MARK: Kakao DTO

struct KakaoPlaceResponse: Decodable {
    let documents: [KakaoPlaceDocument]
}

struct KakaoPlaceDocument: Decodable {
    let id: String
    let placeName: String
    let addressName: String
    let phone: String
    let categoryName: String
    let distance: String

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case addressName = "address_name"
        case phone
        case categoryName = "category_name"
        case distance
    }
}

// ============================================================
// MARK: - LiveSubsidyProvider
// ============================================================

/// 복지로 API Live 구현
/// 키 없으면 MockSubsidyProvider로 위임
final class LiveSubsidyProvider: SubsidyProviding {

    private let client: APIClient
    private let fallback: SubsidyProviding

    init(client: APIClient = APIClient(),
         fallback: SubsidyProviding = MockSubsidyProvider()) {
        self.client = client
        self.fallback = fallback
    }

    func subsidies(childAgeMonths: Int) async throws -> [SubsidyInfo] {
        guard let key = APIConfig.key(APIConfig.bokjiroKeyName) else {
            return try await fallback.subsidies(childAgeMonths: childAgeMonths)
        }

        guard var components = URLComponents(string: "https://www.bokjiro.go.kr/ssis-tbu/api/gvmtWlfareInfo") else {
            throw APIError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: key),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "numOfRows", value: "20"),
            URLQueryItem(name: "lifeArray", value: "C0013"),  // 영유아 생애주기 코드
            URLQueryItem(name: "_type", value: "json"),
        ]

        guard let url = components.url else {
            return try await fallback.subsidies(childAgeMonths: childAgeMonths)
        }

        // 네트워크·파싱 실패 시 샘플로 graceful 폴백
        do {
            let response = try await client.get(url, as: BokjiroSubsidyResponse.self)
            return try SubsidyResponseParser.parse(response, childAgeMonths: childAgeMonths)
        } catch {
            return try await fallback.subsidies(childAgeMonths: childAgeMonths)
        }
    }
}

// ============================================================
// MARK: - SubsidyResponseParser (QA 테스트 대상)
// ============================================================

/// 복지로 API 응답 DTO → SubsidyInfo 순수 파서
///
/// QA 샘플 JSON 형태:
/// ```json
/// {
///   "response": {
///     "body": {
///       "items": {
///         "item": [
///           {
///             "wlfareSno": "WS001",
///             "wlfareName": "아동수당",
///             "wlfareOverview": "만 8세 미만 아동에게 월 10만원 지급",
///             "applyMtdCn": "복지로 온라인 신청",
///             "minAge": "0",
///             "maxAge": "95",
///             "paymentAmount": "100000"
///           }
///         ]
///       }
///     }
///   }
/// }
/// ```
enum SubsidyResponseParser {

    static func parse(_ response: BokjiroSubsidyResponse,
                      childAgeMonths: Int) throws -> [SubsidyInfo] {
        guard let items = response.response?.body?.items?.item else {
            return []
        }

        return items.compactMap { item -> SubsidyInfo? in
            // 연령 범위 필터링 (minAge/maxAge는 개월 수)
            let minAge = Int(item.minAge ?? "0") ?? 0
            let maxAge = Int(item.maxAge ?? "999") ?? 999
            guard childAgeMonths >= minAge, childAgeMonths <= maxAge else { return nil }

            let applyURL = item.applyUrl.flatMap { URL(string: $0) }
            let amount = Int(item.paymentAmount ?? "0") ?? 0

            return SubsidyInfo(
                id: item.wlfareSno ?? UUID().uuidString,
                name: item.wlfareName ?? "지원금",
                amountKRW: amount,
                eligibility: item.wlfareOverview ?? item.applyMtdCn ?? "",
                applyURL: applyURL
            )
        }
    }

    static func parse(_ data: Data, childAgeMonths: Int) throws -> [SubsidyInfo] {
        do {
            let response = try JSONDecoder().decode(BokjiroSubsidyResponse.self, from: data)
            return try parse(response, childAgeMonths: childAgeMonths)
        } catch {
            throw APIError.decoding
        }
    }
}

// MARK: Bokjiro DTO

struct BokjiroSubsidyResponse: Decodable {
    let response: BokjiroBody?
}

struct BokjiroBody: Decodable {
    let body: BokjiroBodyInner?
}

struct BokjiroBodyInner: Decodable {
    let items: BokjiroItems?
}

struct BokjiroItems: Decodable {
    let item: [BokjiroSubsidyItem]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let array = try? container.decode([BokjiroSubsidyItem].self, forKey: .item) {
            item = array
        } else if let single = try? container.decode(BokjiroSubsidyItem.self, forKey: .item) {
            item = [single]
        } else {
            item = nil
        }
    }

    enum CodingKeys: String, CodingKey { case item }
}

struct BokjiroSubsidyItem: Decodable {
    let wlfareSno: String?      // 복지 서비스 일련번호
    let wlfareName: String?     // 서비스명
    let wlfareOverview: String? // 서비스 개요
    let applyMtdCn: String?     // 신청 방법
    let minAge: String?         // 최소 연령 (개월)
    let maxAge: String?         // 최대 연령 (개월)
    let paymentAmount: String?  // 지급액 (원)
    let applyUrl: String?       // 신청 URL
}

// ============================================================
// MARK: - LiveVaccineScheduleProvider
// ============================================================

/// 질병관리청 예방접종도우미 API Live 구현
/// 키 없으면 MockVaccineScheduleProvider로 위임
///
/// ⚠️ 이 정보는 의료 상담을 대체하지 않습니다.
///    실제 접종 일정은 반드시 담당 의료진과 확인하세요.
final class LiveVaccineScheduleProvider: VaccineScheduleProviding {

    private let client: APIClient
    private let fallback: VaccineScheduleProviding

    init(client: APIClient = APIClient(),
         fallback: VaccineScheduleProviding = MockVaccineScheduleProvider()) {
        self.client = client
        self.fallback = fallback
    }

    func schedule(birthDate: Date) async throws -> [VaccineRecord] {
        guard let key = APIConfig.key(APIConfig.kdcaKeyName) else {
            return try await fallback.schedule(birthDate: birthDate)
        }

        guard var components = URLComponents(string: "https://apis.data.go.kr/B551182/vaccinationScheduleInfoService/getVaccinationScheduleInfo") else {
            throw APIError.invalidURL
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let birthStr = formatter.string(from: birthDate)

        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: key),
            URLQueryItem(name: "birthDay", value: birthStr),
            URLQueryItem(name: "_type", value: "json"),
        ]

        guard let url = components.url else {
            return try await fallback.schedule(birthDate: birthDate)
        }

        // 네트워크·파싱 실패 시 샘플로 graceful 폴백
        do {
            let response = try await client.get(url, as: KDCAVaccineResponse.self)
            return try VaccineResponseParser.parse(response, birthDate: birthDate)
        } catch {
            return try await fallback.schedule(birthDate: birthDate)
        }
    }
}

// ============================================================
// MARK: - VaccineResponseParser (QA 테스트 대상)
// ============================================================

/// 질병관리청 API 응답 DTO → VaccineRecord 순수 파서
///
/// QA 샘플 JSON 형태:
/// ```json
/// {
///   "response": {
///     "body": {
///       "items": {
///         "item": [
///           {
///             "vaccineCode": "BCG",
///             "vaccineName": "결핵(BCG)",
///             "scheduledDate": "20240115",
///             "orderNo": "1"
///           }
///         ]
///       }
///     }
///   }
/// }
/// ```
enum VaccineResponseParser {

    static func parse(_ response: KDCAVaccineResponse,
                      birthDate: Date) throws -> [VaccineRecord] {
        guard let items = response.response?.body?.items?.item else {
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

        return items.map { item in
            let scheduled: Date? = item.scheduledDate.flatMap { formatter.date(from: $0) }
            return VaccineRecord(
                id: UUID(),
                childId: zeroUUID,  // 호출부(ViewModel/Service)에서 실제 childId로 교체 필요
                vaccineId: item.vaccineCode ?? item.vaccineName ?? "UNKNOWN",
                scheduledDate: scheduled,
                completedDate: nil,
                hospital: nil
            )
        }
    }

    static func parse(_ data: Data, birthDate: Date) throws -> [VaccineRecord] {
        do {
            let response = try JSONDecoder().decode(KDCAVaccineResponse.self, from: data)
            return try parse(response, birthDate: birthDate)
        } catch {
            throw APIError.decoding
        }
    }
}

// MARK: KDCA DTO

struct KDCAVaccineResponse: Decodable {
    let response: KDCABody?
}

struct KDCABody: Decodable {
    let body: KDCABodyInner?
}

struct KDCABodyInner: Decodable {
    let items: KDCAItems?
}

struct KDCAItems: Decodable {
    let item: [KDCAVaccineItem]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let array = try? container.decode([KDCAVaccineItem].self, forKey: .item) {
            item = array
        } else if let single = try? container.decode(KDCAVaccineItem.self, forKey: .item) {
            item = [single]
        } else {
            item = nil
        }
    }

    enum CodingKeys: String, CodingKey { case item }
}

struct KDCAVaccineItem: Decodable {
    let vaccineCode: String?    // 백신 코드 (예: "BCG", "HepB")
    let vaccineName: String?    // 백신명 (예: "결핵(BCG)")
    let scheduledDate: String?  // 권장 접종일 (yyyyMMdd 형식)
    let orderNo: String?        // 접종 차수 (예: "1", "2")
}
