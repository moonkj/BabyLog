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

    // 필터 0 — 소아과 & 현재 영업중 & 거리순
    private var availablePlaces: [NearbyPlace] {
        mockPlaces
            .filter { $0.category == .hospital && $0.isOpen }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }

    // 마지막 확인 시각 (목업)
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
                    .foregroundStyle(AppColors.ink)

                Text("현재 영업중 · 거리순 · 마지막 확인 \(lastCheckedAt)")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
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
            if availablePlaces.isEmpty {
                emptyState
            } else {
                ForEach(Array(availablePlaces.enumerated()), id: \.element.id) { index, place in
                    EmergencyPlaceCard(place: place, isNearest: index == 0)
                }
            }
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppColors.danger)
            Text("현재 영업 중인 소아과를 찾을 수 없어요.\n아래 119 상담 버튼을 이용하세요.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s8)
        .accessibilityLabel("현재 영업 중인 소아과 없음. 119 상담 버튼을 이용하세요.")
    }

    // MARK: 119 Emergency Call Button
    private var emergencyCallButton: some View {
        Button {
            if let url = URL(string: "tel://119") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.danger)
                Text("119 구급 상담")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(AppColors.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.danger.opacity(0.35), lineWidth: 1.5)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.97))
        .padding(.horizontal, Spacing.s4)
        .padding(.bottom, Spacing.s3)
        .accessibilityLabel("119 구급 상담 전화")
        .accessibilityHint("119에 전화하여 구급 상담을 요청합니다")
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
    let place: NearbyPlace
    let isNearest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 상단: 이름·거리·야간진료 정보
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(place.name)
                        .font(.system(size: 21, weight: .heavy))
                        .foregroundStyle(AppColors.ink)

                    HStack(spacing: 10) {
                        Label {
                            Text("\(place.distanceMeters)m")
                                .font(AppFont.num(15))
                                .foregroundStyle(AppColors.ink2)
                        } icon: {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.ink3)
                        }

                        if place.hasNightCare {
                            Text("야간진료")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x3B6FA8))
                        }
                    }

                    // 확인 시각 뱃지
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text("\(place.confirmedMinutesAgo)분 전 확인 · 전화로 다시 확인하세요")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                    .foregroundStyle(AppColors.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColors.surface2, in: Capsule())
                    .accessibilityLabel("\(place.confirmedMinutesAgo)분 전 확인. 전화로 다시 확인하세요.")
                }

                Spacer()

                if isNearest {
                    Text("가장 가까움")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
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
                        if let url = URL(string: place.phone) {
                            UIApplication.shared.open(url)
                        }
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
                .accessibilityLabel("\(place.name) 전화하기")
                .accessibilityHint("탭하면 \(place.name)에 전화를 겁니다")

                // 지도 버튼 — Apple 지도 앱에서 장소명 검색
                Button {
                    let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
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
                .accessibilityHint("\(place.name) 위치를 지도 앱에서 열어봅니다")
            }
        }
        .padding(18)
        .background(
            isNearest
                ? AppColors.danger.opacity(0.12)
                : AppColors.surface,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    isNearest
                        ? AppColors.danger.opacity(0.35)
                        : AppColors.line,
                    lineWidth: isNearest ? 1.5 : 1
                )
        }
        .blShadow(.card)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(place.name), \(place.distanceMeters)미터\(isNearest ? ", 가장 가까운 병원" : "")")
    }
}

// MARK: - PulseDot

/// 응급 상태를 나타내는 펄싱 점 (색+모양 이중 인코딩)
private struct PulseDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.danger.opacity(0.25))
                .frame(width: 18, height: 18)
                .scaleEffect(pulsing ? 1 : 0.6)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulsing)

            Circle()
                .fill(AppColors.danger)
                .frame(width: 9, height: 9)
        }
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
