// AppFeatures.swift
// BabyLog · 피처 플래그 (CLAUDE.md 아키텍처 규칙: 동네별 점진 개방·심사 없는 핫픽스)
// 지금은 빌드타임 상수. 추후 원격 구성(Supabase)으로 승격 가능.

/// 소수점 콤마("8,5") 로케일 입력도 허용해 Double 파싱. 키/몸무게 입력 유실 방지.
func blDecimal(_ s: String) -> Double? {
    Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
}

enum AppFeatures {
    /// 마켓(중고거래) 노출 여부.
    /// ON — schema_market.sql(테이블·RLS·Storage 버킷) 배포 후 개방. 익명(기기ID) 거래 가능,
    /// 로그인 시 소유권이 계정으로 승계. 무료 정책: 1인 1매물·30일 자동만료.
    static let market = true

    /// Pro 가족 피드(클라우드 가족 보관함) 노출 여부.
    /// 백엔드(bl_* 스키마·R2·Edge)는 라이브. 앱 UI는 개발 중 → 기본 OFF(출시 빌드 미노출).
    /// 켜는 조건(추후): StoreKit 구독 게이트(isPro) 연결 + Apple 구독 상품 등록. 개발 검증 시에만 true.
    static let proFamilyFeed = true   // ⚠️ 개발 테스트 중 — 출시 전 false 또는 isPro 구독 게이트로
}
