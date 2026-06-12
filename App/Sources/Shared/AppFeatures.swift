// AppFeatures.swift
// BabyLog · 피처 플래그 (CLAUDE.md 아키텍처 규칙: 동네별 점진 개방·심사 없는 핫픽스)
// 지금은 빌드타임 상수. 추후 원격 구성(Supabase)으로 승격 가능.

enum AppFeatures {
    /// 마켓(중고거래) 노출 여부.
    /// 출시 빌드에선 false(숨김) — 코드는 완성돼 있으나 로그인·소유자 RLS·Storage 배포가
    /// 준비된 뒤 true로 켜서 점진 개방한다. 무료 정책: 1인 1매물·30일 자동만료.
    static let market = false
}
