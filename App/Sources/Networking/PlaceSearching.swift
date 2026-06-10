// PlaceSearching.swift
// BabyLog — Networking
//
// 출처: 카카오맵 로컬 API (주변 장소 검색)
//
// NOTE: 실제 API 키는 B4(키 관리 담당)가 관리합니다.
//       현재 구현은 Mock 데이터만 반환합니다.

import Foundation

// MARK: - Supporting Types

/// 위도·경도 좌표
struct Coordinate: Sendable {
    let lat: Double
    let lng: Double

    init(lat: Double, lng: Double) {
        self.lat = lat
        self.lng = lng
    }
}

/// 카카오맵 로컬 API 결과 장소 모델
struct Place: Identifiable, Sendable {
    let id: String
    let name: String
    let address: String
    let phone: String
    let category: String
    /// 현재 위치로부터의 직선 거리 (미터)
    let distanceM: Int
    /// 5점 만점 평점
    let rating: Double

    init(
        id: String,
        name: String,
        address: String,
        phone: String,
        category: String,
        distanceM: Int,
        rating: Double
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.category = category
        self.distanceM = distanceM
        self.rating = rating
    }
}

// MARK: - Protocol

/// 카카오맵 로컬 API를 통해 주변 장소를 검색합니다.
protocol PlaceSearching {
    /// 키워드와 좌표 기준으로 장소를 검색합니다.
    /// - Parameters:
    ///   - query: 검색 키워드 (예: "키즈카페", "소아과")
    ///   - near: 검색 기준 좌표. `nil`이면 서울 중심부 기준
    /// - Returns: 검색 결과 `Place` 배열 (거리순)
    func search(_ query: String, near: Coordinate?) async throws -> [Place]
}

// MARK: - Mock Implementation

/// 카카오맵 로컬 API Mock — 결정적 샘플 데이터 반환
final class MockPlaceSearcher: PlaceSearching {

    init() {}

    func search(_ query: String, near: Coordinate?) async throws -> [Place] {
        // 결정적 샘플 데이터 — 쿼리 키워드에 무관하게 동일 목록 반환 (QA용)
        return [
            Place(
                id: "place-001",
                name: "하늘키즈카페",
                address: "서울특별시 마포구 월드컵북로 56",
                phone: "02-1234-5678",
                category: "키즈카페",
                distanceM: 320,
                rating: 4.5
            ),
            Place(
                id: "place-002",
                name: "행복소아과의원",
                address: "서울특별시 마포구 성산로 128",
                phone: "02-2345-6789",
                category: "소아과",
                distanceM: 540,
                rating: 4.8
            ),
            Place(
                id: "place-003",
                name: "아이사랑 어린이집",
                address: "서울특별시 마포구 백범로 31",
                phone: "02-3456-7890",
                category: "어린이집",
                distanceM: 780,
                rating: 4.2
            ),
            Place(
                id: "place-004",
                name: "별빛도서관 어린이실",
                address: "서울특별시 마포구 독막로 324",
                phone: "02-4567-8901",
                category: "도서관",
                distanceM: 1_100,
                rating: 4.6
            ),
            Place(
                id: "place-005",
                name: "마포구청 열린놀이터",
                address: "서울특별시 마포구 마포대로 63",
                phone: "",
                category: "공원·놀이터",
                distanceM: 1_450,
                rating: 4.0
            ),
        ]
    }
}
