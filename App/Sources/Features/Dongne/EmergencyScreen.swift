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

    // 마지막 확인 시각 (조회 시점)
    private let lastCheckedAt: String = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }()

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

    /// 내 위치 기준 실제 소아과 — 주변 탭 캐시 재사용, 없으면 HIRA 조회. 현재 영업중·거리순.
    private func load() async {
        // 주변 탭에서 이미 불러온 소아과가 있으면 즉시 사용(빠름)
        if let cached = NearbyResultCache.shared.entries[.hospital], !cached.results.isEmpty {
            hospitals = cached.results.filter { $0.isOpenNow }.sorted { $0.distanceM < $1.distanceM }
            loading = false
            return
        }
        loading = true
        let coord = location.coordinate.map { Coordinate(lat: $0.latitude, lng: $0.longitude) }
        do {
            let results = try await ProviderFactory.hospital().hospitals(near: coord, openNow: true)
            let peds = results.filter { h in ["소아", "아동", "어린이", "키즈"].contains { h.name.contains($0) } }
            hospitals = (peds.isEmpty ? results : peds).sorted { $0.distanceM < $1.distanceM }
        } catch {
            hospitals = []
        }
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

                Text("현재 영업중 · 거리순 · 마지막 확인 \(lastCheckedAt)")
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
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                        .fill(AppColors.surface2)
                        .frame(height: 150)
                        .redacted(reason: .placeholder)
                }
                .accessibilityHidden(true)
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
                Text("지금 문 연 소아과가 없어요")
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
        .accessibilityLabel("지금 문 연 소아과가 없어요. 위급하면 119 구급 상담을 이용하세요.")
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
    let isNearest: Bool

    private var distanceText: String {
        hospital.distanceM >= 1000 ? String(format: "%.1fkm", Double(hospital.distanceM) / 1000) : "\(hospital.distanceM)m"
    }
    private var telURL: URL? {
        let digits = hospital.phone.filter { $0.isNumber }
        return digits.isEmpty ? nil : URL(string: "tel://\(digits)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단: 이름·거리·종별
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hospital.name)
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: Spacing.s3) {
                        Label {
                            Text(distanceText)
                                .font(AppFont.num(15))
                                .foregroundStyle(AppColors.ink2)
                        } icon: {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.ink3)
                        }
                        if !hospital.department.isEmpty {
                            Text(hospital.department)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(AppColors.ink3)
                        }
                    }

                    // HIRA는 실시간 영업정보가 없음 → 전화 확인 안내
                    HStack(spacing: 5) {
                        Image(systemName: "phone.arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("방문 전 전화로 영업 여부를 확인하세요")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(AppColors.ink2)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 26)
                    .background(AppColors.surface2, in: Capsule())
                }

                Spacer()

                if isNearest {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text("가장 가까움")
                            .font(.system(size: 11, weight: .heavy))
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.danger, in: Capsule())
                    .accessibilityLabel("가장 가까운 병원")
                }
            }
            .padding(.bottom, Spacing.s4)

            // 하단: 전화 + 지도 버튼
            HStack(spacing: 10) {
                // 초대형 전화 LiquidButton (높이 64+)
                LiquidButton(
                    fill: AppColors.emergencyAction,
                    cornerRadius: Radius.md,
                    action: {
                        if let url = telURL { UIApplication.shared.open(url) }
                    }
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 22, weight: .bold))
                        Text("전화하기")
                            .font(.system(size: 19, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                }
                .opacity(telURL == nil ? 0.4 : 1)
                .accessibilityLabel("\(hospital.name) 전화하기")
                .accessibilityHint("탭하면 \(hospital.name)에 전화를 겁니다")

                // 지도 버튼 — Apple 지도 앱에서 장소명 검색
                Button {
                    let q = hospital.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                            .fill(AppColors.surface2)
                            .frame(width: 64, height: 64)
                        Image(systemName: "map.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.ink2)
                    }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.93))
                .accessibilityLabel("지도로 길찾기")
                .accessibilityHint("\(hospital.name) 위치를 지도 앱에서 열어봅니다")
            }
        }
        .padding(18)
        .background(
            isNearest
                ? AppColors.dangerTint
                : AppColors.surface,
            in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(
                    isNearest
                        ? AppColors.danger.opacity(0.45)
                        : AppColors.line,
                    lineWidth: isNearest ? 2 : 1
                )
        }
        .blShadow(.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(hospital.name), \(distanceText)\(isNearest ? ", 가장 가까운 병원" : "")")
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
