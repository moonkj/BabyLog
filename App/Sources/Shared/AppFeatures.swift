// AppFeatures.swift
// BabyLog · 피처 플래그 (CLAUDE.md 아키텍처 규칙: 동네별 점진 개방·심사 없는 핫픽스)
// 지금은 빌드타임 상수. 추후 원격 구성(Supabase)으로 승격 가능.

enum AppFeatures {
    /// 마켓(중고거래) 노출 여부.
    /// ON — schema_market.sql(테이블·RLS·Storage 버킷) 배포 후 개방. 익명(기기ID) 거래 가능,
    /// 로그인 시 소유권이 계정으로 승계. 무료 정책: 1인 1매물·30일 자동만료.
    static let market = true
}
