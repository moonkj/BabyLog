// ProviderFactory.swift
// BabyLog — Networking
//
// API 키 유무에 따라 Live / Mock 프로바이더를 선택하는 팩토리.
//
// [B4 정책] 키가 설정된 경우 → Live 프로바이더 반환
//           키가 없는 경우  → Mock 프로바이더 반환 (graceful fallback)
//
// 사용 예시:
//   let hospitalProvider = ProviderFactory.hospital()
//   let hospitals = try await hospitalProvider.hospitals(near: coord, openNow: true)

import Foundation

// MARK: - ProviderFactory

enum ProviderFactory {

    // MARK: - Hospital (건강보험심사평가원)

    /// `HospitalInfoProviding` 구현을 반환합니다.
    /// - `HIRA_API_KEY`가 설정된 경우: `LiveHospitalInfoProvider`
    /// - 키 없는 경우: `MockHospitalInfoProvider`
    static func hospital(client: APIClient = APIClient()) -> HospitalInfoProviding {
        if APIConfig.key(APIConfig.hiraKeyName) != nil {
            return LiveHospitalInfoProvider(client: client)
        }
        return MockHospitalInfoProvider()
    }

    // MARK: - Place (카카오맵)

    /// `PlaceSearching` 구현을 반환합니다.
    /// - `KAKAO_REST_API_KEY`가 설정된 경우: `LivePlaceSearcher`
    /// - 키 없는 경우: `MockPlaceSearcher`
    static func place(client: APIClient = APIClient()) -> PlaceSearching {
        if APIConfig.key(APIConfig.kakaoRESTKeyName) != nil {
            return LivePlaceSearcher(client: client)
        }
        return MockPlaceSearcher()
    }

    // MARK: - Subsidy (복지로)

    /// `SubsidyProviding` 구현을 반환합니다.
    /// - `BOKJIRO_API_KEY`가 설정된 경우: `LiveSubsidyProvider`
    /// - 키 없는 경우: `MockSubsidyProvider`
    static func subsidy(client: APIClient = APIClient()) -> SubsidyProviding {
        if APIConfig.key(APIConfig.bokjiroKeyName) != nil {
            return LiveSubsidyProvider(client: client)
        }
        return MockSubsidyProvider()
    }

    // MARK: - Vaccine (질병관리청)

    /// `VaccineScheduleProviding` 구현을 반환합니다.
    /// - `KDCA_VACCINE_API_KEY`가 설정된 경우: `LiveVaccineScheduleProvider`
    /// - 키 없는 경우: `MockVaccineScheduleProvider`
    ///
    /// ⚠️ 반환된 일정은 의료 상담을 대체하지 않습니다.
    static func vaccine(client: APIClient = APIClient()) -> VaccineScheduleProviding {
        if APIConfig.key(APIConfig.kdcaKeyName) != nil {
            return LiveVaccineScheduleProvider(client: client)
        }
        return MockVaccineScheduleProvider()
    }

    /// 해당 키가 없어 Mock(샘플 데이터)으로 동작하는지 여부.
    /// 화면에서 "샘플 데이터" 안내를 조건부로 노출하는 데 사용.
    static func isMock(_ keyName: String) -> Bool {
        APIConfig.key(keyName) == nil
    }
}
