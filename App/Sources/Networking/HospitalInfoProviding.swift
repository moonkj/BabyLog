// HospitalInfoProviding.swift
// BabyLog — Networking
//
// 출처: 건강보험심사평가원 API (소아과·병원 정보)
// ⚠️ 이 정보는 의료 상담을 대체하지 않습니다.
//    응급상황에는 119에 연락하거나 인근 응급실을 방문하세요.
//
// NOTE: 실제 API 키는 B4(키 관리 담당)가 관리합니다.
//       현재 구현은 Mock 데이터만 반환합니다.

import Foundation

// MARK: - Model

/// 건강보험심사평가원 병원 정보 모델
/// ⚠️ 운영 시간·진료 가능 여부는 실시간 변동될 수 있습니다.
///    방문 전 반드시 전화로 확인하세요.
struct HospitalInfo: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let phone: String
    /// 대표 진료 과목 (예: "소아청소년과", "소아응급의학과")
    let department: String
    /// 조회 시점 기준 운영 중 여부 (실시간 아님)
    let isOpenNow: Bool
    /// 마지막 운영 정보 갱신 후 경과 시간 (분)
    let lastCheckedMinutesAgo: Int
    /// 현재 위치로부터의 직선 거리 (미터)
    let distanceM: Int
    /// 5점 만점 평점
    let rating: Double
    /// 기관 위치 좌표 (지도 핀·거리계산용). 없으면 nil.
    let latitude: Double?
    let longitude: Double?
    /// 종별 (HIRA clCdNm: "상급종합"·"종합병원"·"병원"·"의원"·"치과의원" 등). 응급 모드 정렬용.
    let clCdNm: String?

    init(
        id: String,
        name: String,
        address: String,
        phone: String,
        department: String,
        isOpenNow: Bool,
        lastCheckedMinutesAgo: Int,
        distanceM: Int,
        rating: Double,
        latitude: Double? = nil,
        longitude: Double? = nil,
        clCdNm: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.department = department
        self.isOpenNow = isOpenNow
        self.lastCheckedMinutesAgo = lastCheckedMinutesAgo
        self.distanceM = distanceM
        self.rating = rating
        self.latitude = latitude
        self.longitude = longitude
        self.clCdNm = clCdNm
    }

    /// 대학병원급(상급종합·종합병원) 여부 — 응급실 운영 가능성 높음.
    var isMajorHospital: Bool {
        guard let c = clCdNm else { return false }
        return c.contains("상급종합") || c.contains("종합병원") || c.contains("대학")
    }
}

// MARK: - Protocol

/// 건강보험심사평가원 API를 통해 주변 소아과·병원 정보를 제공합니다.
/// ⚠️ 이 정보는 의료 상담을 대체하지 않습니다.
protocol HospitalInfoProviding {
    /// 주변 병원 목록을 반환합니다.
    /// - Parameters:
    ///   - near: 검색 기준 좌표. `nil`이면 서울 중심부 기준
    ///   - openNow: `true`이면 현재 운영 중인 병원만 필터링
    /// - Returns: `HospitalInfo` 배열 (거리순)
    func hospitals(near: Coordinate?, openNow: Bool) async throws -> [HospitalInfo]
}

// MARK: - Mock Implementation

/// 건강보험심사평가원 병원 정보 Mock — 결정적 샘플 데이터 반환
/// ⚠️ 의료 상담을 대체하지 않습니다.
final class MockHospitalInfoProvider: HospitalInfoProviding {

    init() {}

    func hospitals(near: Coordinate?, openNow: Bool) async throws -> [HospitalInfo] {
        let all: [HospitalInfo] = [
            HospitalInfo(
                id: "hosp-001",
                name: "연세아동병원",
                address: "서울특별시 마포구 토정로 35",
                phone: "02-1111-2222",
                department: "소아청소년과",
                isOpenNow: true,
                lastCheckedMinutesAgo: 5,
                distanceM: 410,
                rating: 4.7
            ),
            HospitalInfo(
                id: "hosp-002",
                name: "서울성모소아과의원",
                address: "서울특별시 마포구 월드컵로 190",
                phone: "02-2222-3333",
                department: "소아청소년과",
                isOpenNow: true,
                lastCheckedMinutesAgo: 10,
                distanceM: 830,
                rating: 4.5
            ),
            HospitalInfo(
                id: "hosp-003",
                name: "강북삼성응급의료센터 소아응급",
                address: "서울특별시 종로구 새문안로 29",
                phone: "02-2001-2000",
                department: "소아응급의학과",
                isOpenNow: true,   // 24시간 운영
                lastCheckedMinutesAgo: 1,
                distanceM: 3_200,
                rating: 4.3
            ),
            HospitalInfo(
                id: "hosp-004",
                name: "마포밝은소아과",
                address: "서울특별시 마포구 신촌로 62",
                phone: "02-3333-4444",
                department: "소아청소년과",
                isOpenNow: false,  // 오전 진료 종료
                lastCheckedMinutesAgo: 15,
                distanceM: 1_050,
                rating: 4.6
            ),
            HospitalInfo(
                id: "hosp-005",
                name: "홍대키즈한의원",
                address: "서울특별시 마포구 어울마당로 45",
                phone: "02-4444-5555",
                department: "한방소아과",
                isOpenNow: false,
                lastCheckedMinutesAgo: 20,
                distanceM: 1_380,
                rating: 4.1
            ),
        ]

        if openNow {
            return all.filter { $0.isOpenNow }
        }
        return all
    }
}
