// APIClient.swift
// BabyLog — Networking
//
// 순수 Foundation 기반 HTTP GET 클라이언트.
// 외부 의존 없음. URLSession async/await 사용.
//
// NOTE: 실제 API 키는 절대 이 파일에 하드코딩하지 않습니다.
//       키는 Info.plist 또는 환경변수로 주입받습니다 (APIConfig 참조).

import Foundation

// MARK: - APIError

/// 네트워크 요청 중 발생할 수 있는 오류 유형
enum APIError: Error, Equatable {
    /// URL 구성 실패 (잘못된 문자열 등)
    case invalidURL
    /// 네트워크 전송 오류 (연결 없음, 타임아웃 등)
    case transport
    /// 서버가 2xx 이외의 HTTP 상태 코드를 반환한 경우
    case http(Int)
    /// 응답 본문을 기대 타입으로 디코딩하지 못한 경우
    case decoding
    /// 필수 API 키가 설정되지 않은 경우
    case noAPIKey
}

// MARK: - APIClient

/// Foundation URLSession 기반의 가볍고 테스트 가능한 HTTP GET 클라이언트.
///
/// 사용 예시:
/// ```swift
/// let client = APIClient()
/// let result = try await client.get(url, as: MyDTO.self)
/// ```
struct APIClient {

    /// 주입 가능한 URLSession (테스트에서 mock session 교체 가능)
    var session: URLSession

    /// 기본 초기화 — 타임아웃 15초 설정
    init(session: URLSession = .init(configuration: {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 15
        return cfg
    }())) {
        self.session = session
    }

    /// 지정된 URL에 GET 요청을 보내고 응답을 `T`로 디코딩하여 반환합니다.
    ///
    /// - Parameters:
    ///   - url: 요청 대상 URL
    ///   - type: 디코딩 대상 타입 (`Decodable` 준수)
    /// - Returns: 디코딩된 `T` 인스턴스
    /// - Throws:
    ///   - `APIError.transport`: URLSession 레벨 오류
    ///   - `APIError.http(statusCode)`: 2xx 이외의 HTTP 상태
    ///   - `APIError.decoding`: JSON 디코딩 실패
    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw APIError.transport
        }

        if let httpResponse = response as? HTTPURLResponse,
           let mapped = APIClient.mapHTTP(httpResponse.statusCode) {
            throw mapped
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    // MARK: - Pure Helper (QA 테스트 대상)

    /// HTTP 상태 코드를 `APIError`로 매핑합니다.
    ///
    /// 2xx 범위는 성공으로 간주하여 `nil` 반환.
    /// 그 외 모든 코드는 `APIError.http(statusCode)` 반환.
    ///
    /// - Parameter status: HTTP 상태 코드
    /// - Returns: 오류면 `APIError.http(status)`, 성공(2xx)이면 `nil`
    static func mapHTTP(_ status: Int) -> APIError? {
        switch status {
        case 200 ..< 300:
            return nil
        default:
            return .http(status)
        }
    }
}
