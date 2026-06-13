// EmergencyScreen.swift
// BabyLog · Features/Dongne
// 응급 모드 — 라이트 풀스크린, 고대비·큰 터치타깃. (앱 전역 라이트 정책에 맞춰 라이트 테마)
// Swift 5 / iOS 17 / SwiftUI + Foundation only

import SwiftUI
import Foundation

// MARK: - EmergencyScreen

/// 응급 모드 풀스크린 뷰.
/// - `onClose`: 닫기 버튼·완료 시 호출되는 클로저 (DongneTab이 주입)
struct EmergencyScreen: View {
    var onClose: () -> Void

    @ObservedObject private var location = NearbyLocationProvider.shared
    @State private var hospitals: [HospitalInfo] = []
    @State private var loading = true
    /// 조회 실패 — 실제 "0곳"과 구분(아동안전: 거짓 "병원 없음" 방지). 재시도 UI 노출.
    @State private var loadFailed = false
    /// 요청 세대 카운터 — 좌표 nil로 시작한 폴백 조회가 GPS 도착 후의 내 위치 조회를
    /// 늦게 덮어쓰는 경합 방지(완료 시 세대가 일치하는 마지막 요청만 반영).
    @State private var loadGeneration = 0

    // 마지막 확인 시각 — @State로 두고 load() 완료 시 갱신(뷰 생성 시각 고정이던 버그 수정).
    @State private var lastCheckedAt: String = Self.timeString(Date())

    /// "HH:mm" 표기(ko_KR) — 헤더의 "○○:○○ 기준" 갱신용.
    private static func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.canvas
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    placeList
                    emergencyCallButton
                    disclaimerView
                }
                .padding(.bottom, Spacing.s8)
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear { location.start() }
        .task { await load() }
        .onChange(of: location.coordinate?.latitude) { _, lat in
            if lat != nil { Task { await load() } }
        }
    }

    /// 내 위치 기준 응급용 — 대학병원급(상급종합·종합병원) + 소아과만.
    /// 정렬: ① 가장 가까운 대학병원급 최상단 → ② 종합병원급·소아과 거리순.
    private func load() async {
        loadGeneration += 1
        let gen = loadGeneration   // 이 요청의 세대 — 완료 시 일치할 때만 상태에 반영
        loading = true
        loadFailed = false
        let coord = location.coordinate.map { Coordinate(lat: $0.latitude, lng: $0.longitude) }
        // 두 조회 병렬: 전체 병원(종별 식별용) + 소아과(진료과목 11)
        // 부분 실패 허용 — 하나만 실패해도 성공한 쪽(예: 대학병원급)은 표시한다.
        // 둘 다 실패했을 때만 loadFailed(거짓 "병원 없음" = 아동안전 위험).
        async let allRaw = ProviderFactory.hospitalAll().hospitals(near: coord, openNow: false)
        async let pedRaw = ProviderFactory.hospital().hospitals(near: coord, openNow: false)
        let allResult: [HospitalInfo]? = try? await allRaw
        let pedResult: [HospitalInfo]? = try? await pedRaw

        // 더 최신 요청이 시작됐으면 이 응답은 폐기(폴백 좌표 결과가 내 위치 결과를 덮어쓰지 않게)
        guard gen == loadGeneration else { return }

        if allResult == nil && pedResult == nil {
            // 둘 다 실패 — 빈 결과로 위장하지 않는다.
            hospitals = []
            loadFailed = true
            lastCheckedAt = Self.timeString(Date())
            loading = false
            return
        }
        let all = allResult ?? []
        let peds = pedResult ?? []

        // 대학병원급(상급종합·종합병원) — 응급실 운영이 사실상 보장되므로 영업조회 없이
        // 가까운 순 최대 3곳을 '항상' 노출한다. (소아과 조회에 묻혀 후보에서 잘리던 버그 수정:
        // 24h 응급이 필요한 상황에서 큰 병원을 빠뜨리는 건 아동안전 위험.)
        let majorsNearest = all.filter { $0.isMajorHospital }
            .sorted { $0.distanceM < $1.distanceM }
        let topMajors = Array(majorsNearest.prefix(3))
        let majorIDs = Set(topMajors.map { $0.id })

        // 소아과(이름 기반 — 가정의학·내과 혼입 제거)는 가까운 후보만 상세 영업시간을
        // 조회해 '영업중'인 곳만 남긴다(빠르게). 대학병원급과 중복되면 제외.
        let kw = ["소아", "아동", "어린이", "키즈"]
        let pediatric = peds.filter { h in kw.contains { h.name.contains($0) } }
            .filter { !majorIDs.contains($0.id) }
            .sorted { $0.distanceM < $1.distanceM }
        let pedCandidates = Array(pediatric.prefix(12))
        var openPeds: [HospitalInfo] = []
        await withTaskGroup(of: (HospitalInfo, Bool?).self) { group in
            for h in pedCandidates {
                group.addTask { (h, await HospitalDetailService.isOpenNow(ykiho: h.id)) }
            }
            for await (h, open) in group where open == true {
                openPeds.append(h)
            }
        }
        // 영업조회 동안에도 새 요청이 시작될 수 있다 — 마지막 요청만 반영
        guard gen == loadGeneration else { return }
        openPeds.sort { $0.distanceM < $1.distanceM }
        // 최상단 = 가까운 대학병원급(최대 3) → 그 뒤 영업중 소아과 거리순
        hospitals = topMajors + openPeds
        lastCheckedAt = Self.timeString(Date())   // 조회 완료 시각으로 갱신
        loading = false
    }

    private static func distanceText(_ m: Int) -> String {
        m >= 1000 ? String(format: "%.1fkm", Double(m) / 1000) : "\(m)m"
    }

    // MARK: Header
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                // "응급 모드" 레이블 + 펄스 점
                HStack(spacing: 8) {
                    PulseDot()
                    Text("응급 모드")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(AppColors.danger)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("응급 모드 활성")

                Text("지금 갈 수 있는 곳")
                    .font(.system(size: 27, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityAddTraits(.isHeader)

                Text("영업중 · 대학병원급 우선 · 가까운 순 · \(lastCheckedAt) 기준")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 닫기 버튼
            Button(action: onClose) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(AppColors.surface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppColors.ink2)
                }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.93))
            .accessibilityLabel("응급 모드 닫기")
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.top, Spacing.s5)
        .padding(.bottom, Spacing.s4)
    }

    // MARK: Place List
    private var placeList: some View {
        VStack(spacing: 14) {
            if loading {
                // 주변 탐색과 동일한 레이더 검색 애니메이션(응급 — 가까운 병원 훑는 중)
                VStack(spacing: Spacing.s4) {
                    RadarSweepView(size: 132)
                    Text("가까운 병원을 찾는 중…")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink2)
                }
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                .padding(.top, Spacing.s5)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("가까운 병원을 찾는 중")
            } else if loadFailed {
                failedState
            } else if hospitals.isEmpty {
                emptyState
            } else {
                ForEach(Array(hospitals.enumerated()), id: \.element.id) { index, h in
                    EmergencyPlaceCard(hospital: h, isNearest: index == 0)
                }
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s4)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.s4) {
            ZStack {
                Circle()
                    .fill(AppColors.dangerTint)
                    .frame(width: 88, height: 88)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppColors.danger)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: Spacing.s2) {
                Text("주변에서 병원을 찾지 못했어요")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                Text("위급하다면 망설이지 말고 아래 119 구급 상담을 이용하세요.")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.s6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("주변에서 병원을 찾지 못했어요. 위급하면 119 구급 상담을 이용하세요.")
    }

    // MARK: Failed State (조회 실패 — "0곳"과 구분, 재시도)
    // 아동안전: 서버 실패를 "병원 없음"으로 보여주면 보호자가 위험 판단을 그르친다.
    private var failedState: some View {
        VStack(spacing: Spacing.s4) {
            ZStack {
                Circle()
                    .fill(AppColors.dangerTint)
                    .frame(width: 88, height: 88)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppColors.danger)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityHidden(true)

            VStack(spacing: Spacing.s2) {
                Text("병원 정보를 불러오지 못했어요")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)
                Text("일시적인 오류일 수 있어요. 다시 시도하거나, 위급하면 아래 119 구급 상담을 이용하세요.")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.s6)

            // 다시 시도 — 44pt 이상 터치 타깃
            Button {
                Task { await load() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                    Text("다시 시도")
                        .font(.system(size: 15.5, weight: .bold))
                }
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, Spacing.s5)
                .frame(minHeight: 48)
                .background(AppColors.surface, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
            }
            .buttonStyle(LiquidPressStyle(scale: 0.96))
            .accessibilityLabel("병원 정보 다시 불러오기")
            .accessibilityHint("주변 병원 정보를 다시 조회합니다")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s7)
        .accessibilityElement(children: .contain)
    }

    // MARK: 119 Emergency Call Button
    // 응급 화면에서 가장 강한 affordance — 솔리드 레드 풀폭, 흔들림 없는 대비.
    private var emergencyCallButton: some View {
        Button {
            if let url = URL(string: "tel://119") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: Spacing.s3) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("119 구급 상담")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.white)
                    Text("위급하면 바로 전화하세요")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(.horizontal, Spacing.s5)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(AppColors.danger,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .shadow(color: AppColors.danger.opacity(0.28), radius: 12, x: 0, y: 6)
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s1)
        .padding(.bottom, Spacing.s3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("119 구급 상담 전화")
        .accessibilityHint("119에 전화하여 구급 상담을 요청합니다")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Disclaimer
    private var disclaimerView: some View {
        Text("위급 상황 시 망설이지 말고 119에 연락하세요. 영업 정보는 실시간과 다를 수 있어 전화 확인이 가장 정확합니다.")
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(AppColors.ink3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
    }
}

// MARK: - EmergencyPlaceCard

private struct EmergencyPlaceCard: View {
    let hospital: HospitalInfo
    /// 최상단(가장 가까운 대학병원급) 강조 카드 여부.
    let isNearest: Bool

    private var distanceText: String {
        hospital.distanceM >= 1000 ? String(format: "%.1fkm", Double(hospital.distanceM) / 1000) : "\(hospital.distanceM)m"
    }
    private var telURL: URL? {
        let digits = hospital.phone.filter { $0.isNumber }
        return digits.isEmpty ? nil : URL(string: "tel://\(digits)")
    }
    private var typeLabel: String { hospital.clCdNm ?? hospital.department }
    private var highlight: Bool { isNearest && hospital.isMajorHospital }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s3) {
            // 정보
            VStack(alignment: .leading, spacing: 5) {
                // 대학병원급 강조 뱃지 (최상단 + 종합/상급)
                if highlight {
                    HStack(spacing: 4) {
                        Image(systemName: "cross.case.fill").font(.system(size: 10, weight: .bold))
                        Text("가장 가까운 대학병원급 · 응급실")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(AppColors.danger, in: Capsule())
                } else if hospital.isMajorHospital {
                    Text("대학병원급")
                        .font(.system(size: 10.5, weight: .heavy))
                        .foregroundStyle(AppColors.danger)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(AppColors.dangerTint, in: Capsule())
                }

                Text(hospital.name)
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    // 영업중 확인 마커 — 노출되는 곳은 모두 영업중(상세 영업시간/응급실 기준)
                    HStack(spacing: 3) {
                        Circle().fill(BadgeTone.mint.ink).frame(width: 6, height: 6)
                        Text(hospital.isMajorHospital ? "응급실 운영" : "영업중")
                            .font(.system(size: 11.5, weight: .heavy))
                            .foregroundStyle(BadgeTone.mint.ink)
                    }
                    Text("·").foregroundStyle(AppColors.line2)
                    Text(distanceText).font(AppFont.num(13.5)).foregroundStyle(AppColors.ink2)
                    if !typeLabel.isEmpty {
                        Text("·").foregroundStyle(AppColors.line2)
                        Text(typeLabel).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(AppColors.ink3)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // 액션 — 작은 전화 + 지도(각 48pt)
            Button {
                if let url = telURL { UIApplication.shared.open(url) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(AppColors.emergencyAction)
                        .frame(width: 48, height: 48)
                    Image(systemName: "phone.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                }
                .blShadow(.chip)
            }
            .buttonStyle(LiquidPressStyle(scale: 0.93))
            .opacity(telURL == nil ? 0.4 : 1)
            .accessibilityLabel("\(hospital.name) 전화하기")

            Button {
                let q = hospital.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(q)") { UIApplication.shared.open(url) }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(MotionIconPalette.greenSoft)
                        .frame(width: 48, height: 48)
                    Image(systemName: "map.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(MotionIconPalette.green)
                }
                .blShadow(.chip)
            }
            .buttonStyle(LiquidPressStyle(scale: 0.93))
            .accessibilityLabel("지도로 길찾기")
        }
        .padding(14)
        .background(
            highlight ? AppColors.dangerTint : AppColors.surface,
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(highlight ? AppColors.danger.opacity(0.45) : AppColors.line, lineWidth: highlight ? 2 : 1)
        }
        .blShadow(.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(hospital.name), \(typeLabel), \(distanceText)\(highlight ? ", 가장 가까운 대학병원급" : "")")
    }
}

// MARK: - PulseDot

/// 응급 상태를 나타내는 펄싱 점 (색+모양 이중 인코딩)
private struct PulseDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        ZStack {
            // 바깥 헤일로 — 부드럽게 커졌다 옅어짐
            Circle()
                .fill(AppColors.danger.opacity(reduceMotion ? 0.18 : 0.22))
                .frame(width: 22, height: 22)
                .scaleEffect((!reduceMotion && pulsing) ? 1 : 0.55)
                .opacity((!reduceMotion && pulsing) ? 0 : 0.9)
                .animation(
                    reduceMotion ? nil :
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: false),
                    value: pulsing
                )

            // 코어 점 — 항상 또렷 (색+모양 이중 인코딩)
            Circle()
                .fill(AppColors.danger)
                .frame(width: 9, height: 9)
        }
        .frame(width: 22, height: 22)
        .onAppear { pulsing = true }
        .onDisappear { pulsing = false }
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("응급 모드") {
    EmergencyScreen(onClose: { })
}
#endif
