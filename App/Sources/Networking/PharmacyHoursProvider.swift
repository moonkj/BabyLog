// PharmacyHoursProvider.swift
// BabyLog — Networking
//
// 약국 '영업시간 포함' 조회 — 국립중앙의료원 응급의료포털 '전국 약국 정보 조회 서비스'(B552657).
// HIRA 약국 기본목록엔 진료시간이 없어 영업중/종료를 알 수 없었다. 이 서비스는 요일별
// 운영시간(dutyTime1s/1c=월 … 7=일, 8=공휴일)과 좌표를 주므로 목록 단계에서 바로 영업 여부 판정.
// data.go.kr 같은 일반 인증키(HIRA_API_KEY) 공유. 미구독/실패 시 HIRA 기본목록으로 폴백(시간 미상).
//
// ⚠️ 영업시간은 실시간과 다를 수 있어 방문 전 전화 확인이 가장 정확하다(화면 면책).

import Foundation
import CoreLocation

final class LivePharmacyProvider: HospitalInfoProviding {
    /// 시간 서비스 실패 시 폴백(HIRA 기본목록 — 시간 미상).
    private let fallback: HospitalInfoProviding

    init(fallback: HospitalInfoProviding) { self.fallback = fallback }

    func hospitals(near coordinate: Coordinate?, openNow: Bool) async throws -> [HospitalInfo] {
        guard let key = APIConfig.key(APIConfig.hiraKeyName), let coord = coordinate else {
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
        // 1) 좌표 → 시도/시군구(이 서비스는 행정구역명으로 조회)
        guard let region = try? await Self.reverseRegion(coord),
              var comps = URLComponents(string: "https://apis.data.go.kr/B552657/ErmctInsttInfoInqireService/getParmacyListInfoInqire") else {
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
        comps.queryItems = [
            URLQueryItem(name: "serviceKey", value: key),
            URLQueryItem(name: "Q0", value: region.sido),
            URLQueryItem(name: "Q1", value: region.sigungu),
            URLQueryItem(name: "pageNo", value: "1"),
            URLQueryItem(name: "numOfRows", value: "1000"),
            URLQueryItem(name: "_type", value: "json"),
        ]
        // serviceKey의 '+' 보호(병원 검색과 동일)
        comps.percentEncodedQuery = comps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = comps.url else {
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
        var req = URLRequest(url: url); req.timeoutInterval = 12
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ERPharmacyResponse.self, from: data),
              let items = decoded.response?.body?.items?.item, !items.isEmpty else {
            // 미구독(403)·장애·빈 응답 → 시간 미상 폴백(정직: '전화로 확인')
            return try await fallback.hospitals(near: coordinate, openNow: openNow)
        }
        let now = Date()
        let mapped = items.compactMap { it -> HospitalInfo? in
            guard let lat = it.wgs84Lat, let lon = it.wgs84Lon,
                  let name = it.dutyName, !name.isEmpty else { return nil }
            let dist = Int(HospitalResponseParser.haversineMeters(lat1: coord.lat, lng1: coord.lng, lat2: lat, lng2: lon))
            return HospitalInfo(
                id: it.hpid ?? "\(name)#\(lat),\(lon)",
                name: name,
                address: it.dutyAddr ?? "",
                phone: it.dutyTel1 ?? "",
                department: "약국",
                isOpenNow: it.isOpen(at: now),   // 요일별 운영시간으로 판정
                hoursKnown: true,                 // 목록에 시간 포함 → 영업중/종료 표시
                lastCheckedMinutesAgo: 0,
                distanceM: dist,
                rating: 0,
                latitude: lat,
                longitude: lon,
                clCdNm: "약국"
            )
        }
        .sorted { $0.distanceM < $1.distanceM }
        guard !mapped.isEmpty else { return try await fallback.hospitals(near: coordinate, openNow: openNow) }
        return Array(mapped.prefix(40))   // 가까운 곳 위주
    }

    /// 좌표 → (시도, 시군구) 역지오코딩. administrativeArea=시도, locality/subAdministrativeArea=시군구.
    private static func reverseRegion(_ coord: Coordinate) async throws -> (sido: String, sigungu: String)? {
        let loc = CLLocation(latitude: coord.lat, longitude: coord.lng)
        let placemarks: [CLPlacemark] = try await withCheckedThrowingContinuation { cont in
            CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ko_KR")) { pms, err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: pms ?? []) }
            }
        }
        guard let p = placemarks.first else { return nil }
        let sido = p.administrativeArea ?? ""
        let sigungu = p.locality ?? p.subAdministrativeArea ?? ""
        guard !sido.isEmpty, !sigungu.isEmpty else { return nil }
        return (sido, sigungu)
    }
}

// MARK: - DTO (응급의료포털 약국)

struct ERPharmacyResponse: Decodable {
    let response: Resp?
    struct Resp: Decodable {
        let body: Body?
        struct Body: Decodable {
            let items: Items?
            struct Items: Decodable {
                let item: [ERPharmacyItem]?
                // item이 배열/단일객체 둘 다 올 수 있어 관대 디코딩.
                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    if let arr = try? c.decode([ERPharmacyItem].self, forKey: .item) { item = arr }
                    else if let one = try? c.decode(ERPharmacyItem.self, forKey: .item) { item = [one] }
                    else { item = nil }
                }
                enum CodingKeys: String, CodingKey { case item }
            }
        }
    }
}

struct ERPharmacyItem: Decodable {
    let dutyName, dutyAddr, dutyTel1, hpid: String?
    let wgs84Lat, wgs84Lon: Double?
    /// 요일(1=월 … 7=일) → 시작/종료 HHMM(정수). 누락 요일은 휴무.
    private let starts: [Int: Int]
    private let closes: [Int: Int]

    enum CodingKeys: String, CodingKey {
        case dutyName, dutyAddr, dutyTel1, hpid, wgs84Lat, wgs84Lon
        case dutyTime1s, dutyTime1c, dutyTime2s, dutyTime2c, dutyTime3s, dutyTime3c
        case dutyTime4s, dutyTime4c, dutyTime5s, dutyTime5c, dutyTime6s, dutyTime6c
        case dutyTime7s, dutyTime7c
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        dutyName = try? c.decodeIfPresent(String.self, forKey: .dutyName)
        dutyAddr = try? c.decodeIfPresent(String.self, forKey: .dutyAddr)
        dutyTel1 = try? c.decodeIfPresent(String.self, forKey: .dutyTel1)
        hpid     = try? c.decodeIfPresent(String.self, forKey: .hpid)
        wgs84Lat = ERPharmacyItem.flexDouble(c, .wgs84Lat)
        wgs84Lon = ERPharmacyItem.flexDouble(c, .wgs84Lon)
        // dutyTime은 정수("1800")/문자열("0830") 혼재 → 관대 파싱.
        func hhmm(_ k: CodingKeys) -> Int? {
            if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return i }
            if let s = try? c.decodeIfPresent(String.self, forKey: k) {
                return Int(s.trimmingCharacters(in: .whitespaces))
            }
            return nil
        }
        let dayKeys: [(Int, CodingKeys, CodingKeys)] = [
            (1, .dutyTime1s, .dutyTime1c), (2, .dutyTime2s, .dutyTime2c), (3, .dutyTime3s, .dutyTime3c),
            (4, .dutyTime4s, .dutyTime4c), (5, .dutyTime5s, .dutyTime5c), (6, .dutyTime6s, .dutyTime6c),
            (7, .dutyTime7s, .dutyTime7c),
        ]
        var st: [Int: Int] = [:], cl: [Int: Int] = [:]
        for (idx, sk, ck) in dayKeys {
            if let s = hhmm(sk) { st[idx] = s }
            if let e = hhmm(ck) { cl[idx] = e }
        }
        starts = st; closes = cl
    }

    private static func flexDouble(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    /// 해당 시각(KST)에 영업 중인지. 요일별 운영시간 기준(자정 넘김 허용). 누락 요일은 휴무.
    func isOpen(at date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? cal.timeZone
        // Calendar weekday: 1=일 … 7=토 → dutyTime index: 1=월 … 6=토, 7=일
        let wd = cal.component(.weekday, from: date)
        let idx = (wd == 1) ? 7 : (wd - 1)
        guard let s = starts[idx], let e = closes[idx], s != e else { return false }
        let now = cal.component(.hour, from: date) * 100 + cal.component(.minute, from: date)
        return s < e ? (now >= s && now < e) : (now >= s || now < e)
    }
}
