// SubsidyProviding.swift
// BabyLog — Networking
//
// 출처: 복지로 API (정부지원금 — 아동수당·부모급여·첫만남이용권 등)
//
// NOTE: 실제 API 키는 B4(키 관리 담당)가 관리합니다.
//       현재 구현은 Mock 데이터만 반환합니다.
//       지원금 금액·조건은 정책 변경에 따라 달라질 수 있습니다.
//       신청 전 복지로(www.bokjiro.go.kr) 또는 주민센터에서 반드시 확인하세요.

import Foundation

// MARK: - Model

/// 복지로 정부지원금 정보 모델
struct SubsidyInfo: Identifiable, Sendable {
    let id: String
    let name: String
    /// 월 지원 금액 (원). 일시금인 경우 총액.
    let amountKRW: Int
    /// 신청 자격 설명
    let eligibility: String
    /// 신청 페이지 URL (복지로 또는 해당 기관)
    let applyURL: URL?
    /// 일시금 여부 — true면 "총 N만원", false면 "월 N만원"으로 표기(첫만남이용권 등 오표기 방지).
    let isLumpSum: Bool

    init(
        id: String,
        name: String,
        amountKRW: Int,
        eligibility: String,
        applyURL: URL?,
        isLumpSum: Bool = false   // 기본 false — 기존 생성부(LiveProviders 등)는 수정 없이 컴파일
    ) {
        self.id = id
        self.name = name
        self.amountKRW = amountKRW
        self.eligibility = eligibility
        self.applyURL = applyURL
        self.isLumpSum = isLumpSum
    }
}

// MARK: - Protocol

/// 복지로 API를 통해 아동 연령에 맞는 정부지원금 목록을 제공합니다.
protocol SubsidyProviding {
    /// 아동 개월 수 기준 신청 가능한 정부지원금 목록을 반환합니다.
    /// - Parameter childAgeMonths: 아동의 현재 개월 수 (0 이상)
    /// - Returns: 해당 연령에 적용 가능한 `SubsidyInfo` 배열
    func subsidies(childAgeMonths: Int) async throws -> [SubsidyInfo]
}

// MARK: - Mock Implementation

/// 복지로 정부지원금 Mock — 개월 수 기준 결정적 샘플 데이터 반환
final class MockSubsidyProvider: SubsidyProviding {

    init() {}

    func subsidies(childAgeMonths: Int) async throws -> [SubsidyInfo] {
        var result: [SubsidyInfo] = []

        // 첫만남이용권 — 출생 후 1년 이내 신청 (일시금 200만원, 2024 기준)
        if childAgeMonths < 12 {
            result.append(SubsidyInfo(
                id: "subsidy-001",
                name: "첫만남이용권",
                amountKRW: 2_000_000,
                eligibility: "출생 아동 1인당 200만원 바우처 지급. 출생 후 1년 이내 신청.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=94"),
                isLumpSum: true   // 일시금 — "총 200만원"으로 표기(월 지급 아님)
            ))
        }

        // 부모급여 — 0~23개월 (2024 기준: 0~11개월 100만원, 12~23개월 50만원)
        if childAgeMonths < 12 {
            result.append(SubsidyInfo(
                id: "subsidy-002",
                name: "부모급여 (0~11개월)",
                amountKRW: 1_000_000,
                eligibility: "만 0세(0~11개월) 아동을 가정에서 양육하는 경우 월 100만원 지급.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=96")
            ))
        } else if childAgeMonths < 24 {
            result.append(SubsidyInfo(
                id: "subsidy-003",
                name: "부모급여 (12~23개월)",
                amountKRW: 500_000,
                eligibility: "만 1세(12~23개월) 아동을 가정에서 양육하는 경우 월 50만원 지급.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=96")
            ))
        }

        // 아동수당 — 0~95개월 (만 8세 미만), 월 10만원
        if childAgeMonths < 96 {
            result.append(SubsidyInfo(
                id: "subsidy-004",
                name: "아동수당",
                amountKRW: 100_000,
                eligibility: "만 8세 미만(0~95개월) 아동에게 월 10만원 지급. 소득 기준 없음.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=20")
            ))
        }

        // 가정양육수당 — 어린이집·유치원 미이용 시 (86개월 미만)
        if childAgeMonths < 86 {
            result.append(SubsidyInfo(
                id: "subsidy-005",
                name: "가정양육수당",
                amountKRW: childAgeMonths < 12 ? 200_000 : (childAgeMonths < 24 ? 150_000 : 100_000),
                eligibility: "어린이집·유치원·종일제 아이돌봄서비스를 이용하지 않는 가정양육 아동 지원. 연령별 금액 상이.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=56")
            ))
        }

        // 어린이집 보육료 바우처 — 84개월 미만 (취학 전)
        if childAgeMonths < 84 {
            result.append(SubsidyInfo(
                id: "subsidy-006",
                name: "어린이집 보육료 지원",
                amountKRW: childAgeMonths < 12 ? 514_000 : (childAgeMonths < 24 ? 452_000 : 280_000),
                eligibility: "어린이집 이용 아동에게 연령별 보육료 바우처 지급. 국공립·민간·가정 어린이집 모두 적용.",
                applyURL: URL(string: "https://www.bokjiro.go.kr/ssis-tbu/twatbz/mkclAr/mkclArMtdInfo.do?tbbzSn=61")
            ))
        }

        return result
    }
}
