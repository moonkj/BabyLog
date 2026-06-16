// AppFeatures.swift
// BabyLog · 피처 플래그 (CLAUDE.md 아키텍처 규칙: 동네별 점진 개방·심사 없는 핫픽스)
// 지금은 빌드타임 상수. 추후 원격 구성(Supabase)으로 승격 가능.

/// 소수점 콤마("8,5") 로케일 입력도 허용해 Double 파싱. 키/몸무게 입력 유실 방지.
/// `isFinite` 가드 — "inf"/"nan"/"1e400" 붙여넣기(클립보드·하드웨어 키보드)가 차트로 흘러가
/// Swift Charts 도메인을 NaN/무한으로 만들어 크래시시키는 경로를 차단한다.
func blDecimal(_ s: String) -> Double? {
    guard let v = Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")),
          v.isFinite else { return nil }
    return v
}

enum AppFeatures {
    /// 마켓(중고거래) 노출 여부.
    /// ON — schema_market.sql(테이블·RLS·Storage 버킷) 배포 후 개방. 익명(기기ID) 거래 가능,
    /// 로그인 시 소유권이 계정으로 승계. 무료 정책: 1인 1매물·30일 자동만료.
    static let market = true

    // 가족 피드(가족과 사진 공유)는 v1 정식 기능으로 상시 노출(무료 부부 2명 / Pro 8명).
    // 등급·열람 권한은 서버(bl_claim_invite·bl_approve_member·bl_is_family_member)에서 강제.
}
