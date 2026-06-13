// LegalNoticeScreen.swift
// BabyLog — 법적 고지 묶음 화면
//
// 설정 > "법적 고지 및 약관"에서 진입. 개인정보처리방침 · 오픈소스 라이선스 · 사업자 정보를
// 한 곳에 모은다. 사업자 정보는 메인 설정에 대놓고 노출하지 않고 이 화면 안쪽에 둔다
// (전자상거래법 고지 의무는 충족하되, 첫 화면을 어지럽히지 않도록).

import SwiftUI

// MARK: - 사업자 정보 (전자상거래법 고지 · 카카오 비즈 심사 대응)
//
// ⚠️ 아래 값은 반드시 (1) 국세청 사업자등록증, (2) 카카오 비즈니스 정보에
//    등록한 내용과 "정확히 동일"해야 합니다. 다르면 카카오 심사에서 또 반려됩니다.
//    값을 채운 뒤 빌드→설치하고, [설정 > 법적 고지 > 사업자 정보] 화면을 캡처해 재제출하세요.
enum BusinessInfo {
    static let company   = "바이브랩"             // 상호 (사업자등록증과 동일)
    static let owner     = "문경주"               // 대표자명
    static let regNumber = "874-04-03594"        // 사업자등록번호
    static let mailOrder = "제2026-충북청주-0608호" // 통신판매업 신고번호
    static let address   = ""                     // 사업장 소재지 (등록증값 입력 — 비우면 숨김)
    static let tel       = ""                     // 고객센터 전화 (입력 — 비우면 숨김)
    static let email     = "imurmkj@naver.com"   // 고객센터 이메일
    static let host      = "Apple iCloud · Supabase" // 호스팅/인프라 제공

    /// 빈 값은 자동 제외 — 화면에 가짜/플레이스홀더가 찍히지 않도록.
    static var rows: [(String, String)] {
        [("상호", company),
         ("대표자", owner),
         ("사업자등록번호", regNumber),
         ("통신판매업 신고", mailOrder),
         ("사업장 소재지", address),
         ("고객센터", tel),
         ("이메일", email),
         ("호스팅 제공", host)]
            .filter { !$0.1.isEmpty }
    }
}

// MARK: - 법적 고지 허브

/// 개인정보처리방침 · 오픈소스 · 사업자 정보로 가는 묶음 화면.
struct LegalNoticeScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                BLScreenHeader(title: "법적 고지 및 약관", eyebrow: "정보")

                BLCard(padding: 0) {
                    VStack(spacing: 0) {
                        NavigationLink { PrivacyPolicyScreen() } label: {
                            LegalLinkRow(icon: "lock.shield.fill",
                                         iconBg: Color(hex: 0xE6F1FB), iconFg: Color(hex: 0x3B6FA8),
                                         title: "개인정보처리방침",
                                         subtitle: "어떤 정보를 어떻게 다루는지")
                        }
                        .buttonStyle(.plain)

                        legalDivider

                        NavigationLink { OpenSourceNoticeScreen() } label: {
                            LegalLinkRow(icon: "doc.text.fill",
                                         iconBg: Color(hex: 0xEFF1F4), iconFg: AppColors.ink3,
                                         title: "오픈소스 라이선스",
                                         subtitle: "사용한 소프트웨어 고지")
                        }
                        .buttonStyle(.plain)

                        legalDivider

                        NavigationLink { BusinessInfoScreen() } label: {
                            LegalLinkRow(icon: "building.2.fill",
                                         iconBg: Color(hex: 0xEFEDFB), iconFg: Color(hex: 0x5B53B0),
                                         title: "사업자 정보",
                                         subtitle: "전자상거래법 고지")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalDivider: some View {
        Divider().overlay(AppColors.line).padding(.leading, 62)
    }
}

// MARK: - 공용 링크 행

private struct LegalLinkRow: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(iconFg)
            }
            .frame(width: 38, height: 38)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s3)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - 개인정보처리방침

struct PrivacyPolicyScreen: View {
    private let effectiveDate = "2026년 6월 13일"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                BLScreenHeader(title: "개인정보처리방침", eyebrow: "Privacy")

                BLCard {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        LegalLead("BabyLog(베이비로그)는 아이의 기록을 가장 소중한 자산으로 여깁니다. 우리는 꼭 필요한 정보만 다루고, 아이의 데이터를 절대 외부에 판매하지 않습니다. 본 방침은 어떤 정보가 어떻게 다뤄지는지 투명하게 설명합니다.")

                        LegalSection("1. 가장 중요한 약속", [
                            "아이 사진·영상·성장 기록·일기·지출 등 핵심 데이터는 회사 서버로 전송되지 않고, 사용자의 기기와 사용자 본인의 iCloud에만 저장됩니다.",
                            "아동과 관련된 어떤 데이터도 외부에 판매하거나 광고 목적으로 제공하지 않습니다.",
                            "무료 사용자의 데이터도 삭제하지 않습니다. ‘데이터 인질극’은 없습니다.",
                        ])

                        LegalSection("2. 수집하는 정보", [
                            "기기에만 저장(서버 전송 없음): 아이·임신 기록, 사진·영상, 성장·접종 기록, 일기, 가계부 지출 내역.",
                            "동네 기능(중고 마켓·동네 크루) 사용 시: 사용자가 직접 정한 닉네임, 작성한 글·댓글·채팅, 기기 식별자가 백엔드(Supabase)에 저장됩니다.",
                            "로그인(선택) 시: Apple이 제공하는 로그인 식별자만 보관합니다. 실명·이메일을 닉네임으로 자동 저장하지 않습니다.",
                            "위치: 주변 병원·약국·시설 검색 시 기기의 현재 위치를 사용합니다. 위치는 검색 그 순간에만 쓰이며 별도로 저장하지 않습니다.",
                        ])

                        LegalSection("3. 제3자 서비스", [
                            "주변 정보·지원금 조회를 위해 검색어 또는 좌표가 다음 공공·지도 서비스로 전달될 수 있습니다: 건강보험심사평가원, 질병관리청, 복지로, 국립중앙의료원 응급의료포털, 카카오맵.",
                            "동네 기능 백엔드는 Supabase, 사진 백업·동기화는 사용자 본인의 Apple iCloud를 이용합니다.",
                            "위 서비스에는 아이를 식별할 수 있는 개인정보를 전송하지 않습니다.",
                        ])

                        LegalSection("4. 보유와 파기", [
                            "기기 데이터는 사용자가 삭제하거나 앱을 삭제하기 전까지 보관됩니다. 앱을 삭제하면 기기 내 데이터가 사라지므로, 설정의 ‘데이터 백업’을 권장합니다.",
                            "동네 기능에 올린 글은 사용자가 삭제할 수 있습니다. 계정을 삭제하면 본인 식별이 해제되며, 남은 글은 익명으로 처리됩니다.",
                        ])

                        LegalSection("5. 이용자의 권리", [
                            "데이터 내보내기: 설정 > 내 데이터 내보내기에서 표준 JSON 포맷으로 언제든 내려받을 수 있습니다.",
                            "전체 백업: 사진을 포함한 전체 데이터를 파일 하나로 백업·복원할 수 있습니다.",
                            "계정 삭제: 설정에서 직접 계정을 삭제할 수 있습니다.",
                        ])

                        LegalSection("6. 아동에 관하여", [
                            "본 서비스는 아동이 직접 가입·이용하는 서비스가 아니라, 양육자(보호자)가 아이의 기록을 남기기 위해 사용하는 서비스입니다.",
                        ])

                        LegalSection("7. 문의", [
                            "개인정보 보호책임자: \(BusinessInfo.owner)",
                            "이메일: \(BusinessInfo.email)",
                        ])

                        LegalDisclaimer("본 방침은 관련 법령 및 서비스 변경에 따라 개정될 수 있으며, 중요한 변경은 앱 내에서 공지합니다.")

                        Text("시행일: \(effectiveDate)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 오픈소스 라이선스

struct OpenSourceNoticeScreen: View {
    /// 실제 앱이 사용하는 Apple 시스템 프레임워크. (서드파티 오픈소스 라이브러리는 포함하지 않음.)
    private let frameworks = [
        "SwiftUI", "UIKit", "Foundation", "Combine",
        "Swift Charts", "WidgetKit", "MapKit", "CoreLocation",
        "CloudKit", "AuthenticationServices", "CryptoKit", "Security",
        "PhotosUI", "AVKit", "UserNotifications", "UniformTypeIdentifiers",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                BLScreenHeader(title: "오픈소스 라이선스", eyebrow: "Open Source")

                BLCard {
                    VStack(alignment: .leading, spacing: Spacing.s4) {
                        LegalLead("BabyLog는 Apple이 제공하는 시스템 프레임워크 위에서 제작되었습니다. 현재 별도의 서드파티 오픈소스 라이브러리를 포함하고 있지 않습니다. 향후 외부 오픈소스를 도입하면 해당 라이선스 전문을 이 화면에 명시합니다.")

                        Text("사용한 Apple 프레임워크")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.ink)

                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            ForEach(frameworks, id: \.self) { name in
                                HStack(alignment: .top, spacing: Spacing.s2) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 5))
                                        .foregroundStyle(AppColors.ink3)
                                        .padding(.top, 7)
                                        .accessibilityHidden(true)
                                    Text(name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(AppColors.ink2)
                                }
                            }
                        }

                        LegalDisclaimer("위 프레임워크는 Apple Inc.의 소프트웨어 개발 키트(SDK)에 포함된 것으로, Apple의 소프트웨어 라이선스 계약을 따릅니다. ‘Apple’, ‘iCloud’ 등은 Apple Inc.의 상표입니다.")
                    }
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 사업자 정보

struct BusinessInfoScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                BLScreenHeader(title: "사업자 정보", eyebrow: "통신판매")

                BLCard(padding: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        let rows = BusinessInfo.rows
                        ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                            if idx > 0 {
                                Divider().overlay(AppColors.line).padding(.horizontal, Spacing.s4)
                            }
                            businessRow(label: row.0, value: row.1)
                        }

                        Text("전자상거래 등에서의 소비자보호에 관한 법률에 따른 사업자 정보입니다. 거래·환불 분쟁은 고객센터로 문의해 주세요.")
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Spacing.s4)
                            .padding(.vertical, Spacing.s3)
                    }
                    .padding(.vertical, Spacing.s2)
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func businessRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .frame(width: 104, alignment: .leading)
            Text(value)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(.horizontal, Spacing.s4)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - 공용 텍스트 컴포넌트

/// 도입 문단(살짝 강조).
private struct LegalLead: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(AppColors.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(3)
    }
}

/// 제목 + 불릿 항목.
private struct LegalSection: View {
    let title: String
    let items: [String]
    init(_ title: String, _ items: [String]) { self.title = title; self.items = items }
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.ink)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: Spacing.s2) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(AppColors.ink3)
                        .padding(.top, 7)
                        .accessibilityHidden(true)
                    Text(item)
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
            }
        }
    }
}

/// 회색 면책/부가 안내 문단.
private struct LegalDisclaimer: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(AppColors.ink3)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)
    }
}
