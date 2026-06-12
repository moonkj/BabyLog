// APIConfig.swift
// BabyLog — Networking
//
// API 키 조회 유틸리티.
// 키는 Info.plist 또는 프로세스 환경변수에서 읽습니다.
//
// ⚠️ 실제 API 키는 절대 소스 코드에 하드코딩하지 않습니다.
//    키는 Xcode Build Settings → Info.plist 커스텀 엔트리로 주입하거나,
//    CI/CD 환경에서 환경변수로 전달합니다.
//
// [B4 정책] 키가 설정되지 않은 경우:
//   - Live 프로바이더 대신 Mock 프로바이더로 자동 폴백합니다.
//   - 앱은 정상 동작하며, 사용자에게는 샘플 데이터가 표시됩니다.
//   - 개발/QA 환경에서 키 없이도 빌드·실행이 가능해야 합니다.
//
// Info.plist 설정 예시 (절대 실제 키 값을 커밋하지 말 것):
//   <key>KAKAO_REST_API_KEY</key>
//   <string>$(KAKAO_REST_API_KEY)</string>   ← Xcode Build Setting에서 주입

import Foundation

// MARK: - APIConfig

enum APIConfig {

    // MARK: - 알려진 키 이름 상수

    /// 카카오맵 로컬 API REST 키 (Info.plist 키 이름)
    static let kakaoRESTKeyName = "KAKAO_REST_API_KEY"

    /// 건강보험심사평가원 API 키 (Info.plist 키 이름)
    static let hiraKeyName = "HIRA_API_KEY"

    /// 복지로 API 키 (Info.plist 키 이름)
    static let bokjiroKeyName = "BOKJIRO_API_KEY"

    /// 질병관리청 예방접종도우미 API 키 (Info.plist 키 이름)
    static let kdcaKeyName = "KDCA_VACCINE_API_KEY"

    // MARK: - 키 조회

    /// Info.plist 또는 프로세스 환경변수에서 API 키를 읽습니다.
    ///
    /// 우선순위:
    /// 1. 프로세스 환경변수 (`ProcessInfo.processInfo.environment`)
    /// 2. 메인 번들 Info.plist
    ///
    /// 두 곳 모두 값이 없거나 빈 문자열이면 `nil` 반환.
    ///
    /// - Parameter name: 키 이름 (예: `"KAKAO_REST_API_KEY"`)
    /// - Returns: 키 값 문자열, 없으면 `nil`
    static func key(_ name: String) -> String? {
        // 0. 단위 테스트에서는 실제 키를 무시 → 항상 Mock 경로(결정적 테스트).
        //    Secrets.plist가 번들에 있어도 테스트가 실네트워크를 타지 않게 한다.
        if NSClassFromString("XCTestCase") != nil { return nil }

        // 1. 환경변수 우선 (CI/CD 및 테스트 환경 지원)
        let env = ProcessInfo.processInfo.environment[name]
        if let env, !env.isEmpty { return env }

        // 2. Secrets.plist (깃 제외 — 특수문자 키 안전 보관, 사용자가 직접 채움)
        if let s = secrets[name], !s.isEmpty { return s }

        // 3. Info.plist fallback (Xcode Build Settings 주입 경로)
        let plist = Bundle.main.object(forInfoDictionaryKey: name) as? String
        if let plist, !plist.isEmpty { return plist }

        return nil
    }

    /// 번들에 포함된 `Secrets.plist`(깃 제외)를 1회 로드해 캐싱.
    /// 파일이 없으면 빈 딕셔너리 → 키 없음 → Mock 폴백(B4 정책).
    private static let secrets: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (k, v) in dict { if let s = v as? String { out[k] = s } }
        return out
    }()
}
