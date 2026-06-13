// HospitalDetailService.swift
// BabyLog — Networking
//
// HIRA 의료기관별상세정보(MadmDtlInfoService2.8/getDtlInfo2.8)로 "현재 영업 중" 여부를 판정한다.
// 기본 목록(getHospBasisList)엔 영업시간이 없으므로, 영업 여부가 필요할 때 기관별로 상세를
// 조회한다. 응급/주변 화면 특성상 빠르게 포기(짧은 타임아웃)하고, 실패 시 nil(불명).
//
// ⚠️ 의료기관별상세정보 서비스는 data.go.kr에서 별도 활용신청 필요. 의료 상담을 대체하지 않음.

import Foundation

enum HospitalDetailService {

    /// 현재 영업 중 여부. 응급실(주/야간) 또는 해당 요일 진료시간 기준.
    /// - Returns: 영업중 true / 영업종료 false / 조회 실패·시간 데이터 전무(미확인) nil
    static func isOpenNow(ykiho: String, at date: Date = Date()) async -> Bool? {
        guard let key = APIConfig.key(APIConfig.hiraKeyName), !ykiho.isEmpty else { return nil }
        // LiveProviders와 동일한 패턴 — URLComponents + queryItems로 일관 인코딩.
        // (키를 문자열에 직접 보간하면 +/%/= 포함 키가 한쪽 경로에서만 깨진다.)
        // ⚠️ 영업시간(진료시간)은 '의료기관별상세정보' 서비스(MadmDtlInfoService2.8)에 있다.
        // 기본 목록(hospInfoServicev2)엔 없음. 이 서비스는 data.go.kr에서 키에 별도
        // 구독(활용신청)해야 동작(미구독 시 403 → nil → '영업시간 미확인').
        // 버전 주의: 2.7은 폐기되어 403, 현재 유효 버전은 2.8(getDtlInfo2.8).
        guard var components = URLComponents(string: "https://apis.data.go.kr/B551182/MadmDtlInfoService2.8/getDtlInfo2.8") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "serviceKey", value: key),
            URLQueryItem(name: "ykiho", value: ykiho),
            URLQueryItem(name: "_type", value: "json"),
        ]
        // URLComponents는 쿼리의 '+'를 그대로 두는데, 서버가 공백으로 해석할 수 있다
        // (HIRA serviceKey·ykiho에 '+'가 흔함) → 명시적으로 %2B 인코딩.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        guard let url = components.url else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 6   // 응급 — 오래 기다리지 않는다
        guard let (data, response) = try? await URLSession.shared.data(for: req) else { return nil }
        // HTTP 상태 확인 — 5xx 등 오류 본문을 영업정보로 오인하지 않는다(불명 = nil).
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) { return nil }
        guard let resp = try? JSONDecoder().decode(HIRADetailResponse.self, from: data),
              let item = resp.response?.body?.items?.item?.first else { return nil }
        return item.isOpen(at: date)
    }
}

// MARK: - DTO

struct HIRADetailResponse: Decodable {
    let response: Body?
    struct Body: Decodable {
        let body: Inner?
        struct Inner: Decodable {
            let items: Items?
            struct Items: Decodable {
                let item: [HIRADetailItem]?
                init(from decoder: Decoder) throws {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    if let arr = try? c.decode([HIRADetailItem].self, forKey: .item) { item = arr }
                    else if let one = try? c.decode(HIRADetailItem.self, forKey: .item) { item = [one] }
                    else { item = nil }
                }
                enum CodingKeys: String, CodingKey { case item }
            }
        }
    }
}

struct HIRADetailItem: Decodable {
    // 요일별 진료시간 (HHMM 문자열/숫자)
    let trmtMonStart, trmtMonEnd, trmtTueStart, trmtTueEnd, trmtWedStart, trmtWedEnd: String?
    let trmtThuStart, trmtThuEnd, trmtFriStart, trmtFriEnd, trmtSatStart, trmtSatEnd: String?
    let trmtSunStart, trmtSunEnd: String?
    // 응급실 운영
    let emyDayYn, emyNgtYn, emyDayStart, emyDayEnd, emyNgtStart, emyNgtEnd: String?
    // 점심시간 (예: "1시00분~2시00분", "점심시간 없음") — 주중/토 구분
    let lunchWeek, lunchSat: String?

    enum CodingKeys: String, CodingKey {
        case trmtMonStart, trmtMonEnd, trmtTueStart, trmtTueEnd, trmtWedStart, trmtWedEnd
        case trmtThuStart, trmtThuEnd, trmtFriStart, trmtFriEnd, trmtSatStart, trmtSatEnd
        case trmtSunStart, trmtSunEnd
        case emyDayYn, emyNgtYn, emyDayStart, emyDayEnd, emyNgtStart, emyNgtEnd
        case lunchWeek, lunchSat
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) -> String? {
            if let v = try? c.decodeIfPresent(String.self, forKey: k) { return v }
            if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return String(i) }
            return nil
        }
        trmtMonStart = s(.trmtMonStart); trmtMonEnd = s(.trmtMonEnd)
        trmtTueStart = s(.trmtTueStart); trmtTueEnd = s(.trmtTueEnd)
        trmtWedStart = s(.trmtWedStart); trmtWedEnd = s(.trmtWedEnd)
        trmtThuStart = s(.trmtThuStart); trmtThuEnd = s(.trmtThuEnd)
        trmtFriStart = s(.trmtFriStart); trmtFriEnd = s(.trmtFriEnd)
        trmtSatStart = s(.trmtSatStart); trmtSatEnd = s(.trmtSatEnd)
        trmtSunStart = s(.trmtSunStart); trmtSunEnd = s(.trmtSunEnd)
        emyDayYn = s(.emyDayYn); emyNgtYn = s(.emyNgtYn)
        emyDayStart = s(.emyDayStart); emyDayEnd = s(.emyDayEnd)
        emyNgtStart = s(.emyNgtStart); emyNgtEnd = s(.emyNgtEnd)
        lunchWeek = s(.lunchWeek); lunchSat = s(.lunchSat)
    }

    /// HHMM 문자열 → 정수(분 단위 비교용 HHMM). 빈값/형식오류는 nil.
    /// v >= 0 — "0000"(자정 종료/시작)도 유효한 시각이므로 버리지 않는다(빈 문자열·비숫자는 여전히 nil).
    private func hhmm(_ s: String?) -> Int? {
        guard let s, let v = Int(s.filter { $0.isNumber }), v >= 0 else { return nil }
        return v
    }

    /// 시작~끝 범위 안에 now가 드는지(자정 넘김 허용).
    private func inRange(_ now: Int, _ start: Int?, _ end: Int?) -> Bool {
        guard let s = start, let e = end else { return false }
        if s == e { return false }
        return s < e ? (now >= s && now < e) : (now >= s || now < e)
    }

    /// "1시00분~2시00분" 또는 "12:30~13:30" 형태의 점심시간 → (시작HHMM, 끝HHMM). 없음/파싱실패 nil.
    /// 점심은 항상 한낮이므로 1~7시는 오후로 보정(+12). "점심시간 없음" 등은 nil.
    private func lunchRange(_ s: String?) -> (Int, Int)? {
        guard let s, s.contains("~") else { return nil }
        let parts = s.components(separatedBy: "~")
        guard parts.count == 2 else { return nil }
        func parse(_ t: String) -> Int? {
            // 구분자 확장 — "시"(한글 포맷) 외에 ":"(콜론 포맷 "12:30")도 지원. 오후 보정은 동일.
            guard let si = t.range(of: "시") ?? t.range(of: ":") else { return nil }
            guard var h = Int(t[t.startIndex..<si.lowerBound].filter { $0.isNumber }) else { return nil }
            let m = Int(t[si.upperBound...].filter { $0.isNumber }) ?? 0
            if h < 8 { h += 12 }   // 점심 1~7시 = 오후(13~19), 12시는 정오 그대로
            return h * 100 + m
        }
        guard let a = parse(parts[0]), let b = parse(parts[1]), a < b else { return nil }
        return (a, b)
    }

    /// 영업 판정. 시간 데이터가 전무한 기관은 '영업종료'(false)가 아니라 '미확인'(nil) —
    /// 데이터 없음을 확정 종료로 단정하면 실제 영업 중인 곳을 닫힌 곳으로 오표시한다.
    func isOpen(at date: Date) -> Bool? {
        // 시간 관련 필드가 하나도 없으면 판정 불가 → nil(미확인)
        let hourFields = [trmtMonStart, trmtMonEnd, trmtTueStart, trmtTueEnd,
                          trmtWedStart, trmtWedEnd, trmtThuStart, trmtThuEnd,
                          trmtFriStart, trmtFriEnd, trmtSatStart, trmtSatEnd,
                          trmtSunStart, trmtSunEnd,
                          emyDayStart, emyDayEnd, emyNgtStart, emyNgtEnd]
        let hasAnyData = emyDayYn == "Y" || emyNgtYn == "Y" || hourFields.contains { hhmm($0) != nil }
        guard hasAnyData else { return nil }
        // 한국 의료기관의 영업시간이므로 KST 고정 — 해외 체류 중 현지 시각으로 오판하지 않게.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul") ?? cal.timeZone
        let now = cal.component(.hour, from: date) * 100 + cal.component(.minute, from: date)
        // 응급실(야간/주간) — 24시간 응급이면 항상 열림
        if emyDayYn == "Y" && emyNgtYn == "Y" { return true }
        if emyNgtYn == "Y", inRange(now, hhmm(emyNgtStart), hhmm(emyNgtEnd)) { return true }
        if emyDayYn == "Y", inRange(now, hhmm(emyDayStart), hhmm(emyDayEnd)) { return true }
        // 요일별 정규 진료시간
        let weekday = cal.component(.weekday, from: date)   // 1=일 … 7=토
        let (st, en): (String?, String?)
        switch weekday {
        case 1: (st, en) = (trmtSunStart, trmtSunEnd)
        case 2: (st, en) = (trmtMonStart, trmtMonEnd)
        case 3: (st, en) = (trmtTueStart, trmtTueEnd)
        case 4: (st, en) = (trmtWedStart, trmtWedEnd)
        case 5: (st, en) = (trmtThuStart, trmtThuEnd)
        case 6: (st, en) = (trmtFriStart, trmtFriEnd)
        default: (st, en) = (trmtSatStart, trmtSatEnd)
        }
        guard inRange(now, hhmm(st), hhmm(en)) else { return false }
        // 점심시간이면 닫힘(토=lunchSat, 그 외 평일=lunchWeek; 일요일은 점심 무관)
        let lunch = weekday == 7 ? lunchRange(lunchSat) : (weekday == 1 ? nil : lunchRange(lunchWeek))
        if let (ls, le) = lunch, now >= ls, now < le { return false }
        return true
    }
}
