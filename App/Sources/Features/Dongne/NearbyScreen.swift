// NearbyScreen.swift
// BabyLog · Features/Dongne
// DongneTab의 "주변" 세그먼트에 임베드하여 사용합니다.
// Swift 5 / iOS 17 / SwiftUI + MapKit + CoreLocation + Foundation

import SwiftUI
import MapKit
import CoreLocation
import Foundation

// MARK: - Mock Data Models
// NOTE: NearbyPlace / mockPlaces는 EmergencyScreen이 직접 참조합니다.
//       시그니처·삭제 금지.

enum PlaceCategory: String, CaseIterable {
    case hospital = "소아과"
    case pharmacy = "약국"
    case kidsCafe = "키즈카페"
    case playground = "놀이터"

    var systemIcon: String {
        switch self {
        case .hospital:   return "cross.case.fill"
        case .pharmacy:   return "pills.fill"
        case .kidsCafe:   return "heart.fill"
        case .playground: return "figure.play"
        }
    }

    var iconColor: Color {
        switch self {
        case .hospital:   return Color(hex: 0xB45840)
        case .pharmacy:   return Color(hex: 0x2E7A5C)
        case .kidsCafe:   return Color(hex: 0xB5478A)
        case .playground: return Color(hex: 0x3B6FA8)
        }
    }

    var iconBg: Color {
        switch self {
        case .hospital:   return Color(hex: 0xFAECE7)
        case .pharmacy:   return Color(hex: 0xE1F5EE)
        case .kidsCafe:   return Color(hex: 0xFBEAF0)
        case .playground: return Color(hex: 0xE6F1FB)
        }
    }

    var filterOptions: [String] {
        switch self {
        case .hospital:   return ["현재 영업중", "야간진료", "공휴일진료"]
        case .pharmacy:   return ["현재 영업중", "24시간", "야간약국"]
        case .kidsCafe:   return ["0-2세", "3-5세", "6세+"]
        case .playground: return ["실내", "실외"]
        }
    }
}

struct NearbyPlace: Identifiable {
    let id: Int
    let name: String
    let category: PlaceCategory
    let isOpen: Bool
    let distanceMeters: Int
    let rating: Double
    let hasNightCare: Bool
    let hasHolidayCare: Bool
    let confirmedMinutesAgo: Int   // 몇 분 전 확인
    let trustLevel: TrustLevel      // 신뢰도
    let phone: String
}

enum TrustLevel {
    case high, medium

    var label: String { self == .high ? "높음" : "보통" }
    var badgeTone: BadgeTone { self == .high ? .mint : .amber }
}

// MARK: - Mock Data

let mockPlaces: [NearbyPlace] = [
    NearbyPlace(id: 1, name: "망원소아청소년과",   category: .hospital,   isOpen: true,  distanceMeters: 210,  rating: 4.8, hasNightCare: true,  hasHolidayCare: false, confirmedMinutesAgo: 12,  trustLevel: .high,   phone: "tel://0223451234"),
    NearbyPlace(id: 2, name: "한강아이들병원",     category: .hospital,   isOpen: true,  distanceMeters: 480,  rating: 4.6, hasNightCare: true,  hasHolidayCare: true,  confirmedMinutesAgo: 35,  trustLevel: .high,   phone: "tel://0256782345"),
    NearbyPlace(id: 3, name: "성산소아과의원",     category: .hospital,   isOpen: false, distanceMeters: 720,  rating: 4.3, hasNightCare: false, hasHolidayCare: false, confirmedMinutesAgo: 120, trustLevel: .medium, phone: "tel://0245673456"),
    NearbyPlace(id: 4, name: "마포어린이의원",     category: .hospital,   isOpen: true,  distanceMeters: 950,  rating: 4.5, hasNightCare: false, hasHolidayCare: true,  confirmedMinutesAgo: 5,   trustLevel: .high,   phone: "tel://0234564567"),
    NearbyPlace(id: 5, name: "망원약국",           category: .pharmacy,   isOpen: true,  distanceMeters: 90,   rating: 4.7, hasNightCare: false, hasHolidayCare: false, confirmedMinutesAgo: 8,   trustLevel: .high,   phone: "tel://0223455678"),
    NearbyPlace(id: 6, name: "성산24시약국",       category: .pharmacy,   isOpen: true,  distanceMeters: 340,  rating: 4.4, hasNightCare: false, hasHolidayCare: false, confirmedMinutesAgo: 20,  trustLevel: .medium, phone: "tel://0256786789"),
    NearbyPlace(id: 7, name: "꿈나래키즈카페",     category: .kidsCafe,   isOpen: true,  distanceMeters: 560,  rating: 4.9, hasNightCare: false, hasHolidayCare: false, confirmedMinutesAgo: 60,  trustLevel: .high,   phone: "tel://0245677890"),
    NearbyPlace(id: 8, name: "한강어린이공원",     category: .playground, isOpen: true,  distanceMeters: 310,  rating: 4.2, hasNightCare: false, hasHolidayCare: false, confirmedMinutesAgo: 90,  trustLevel: .medium, phone: "tel://0234568901"),
]

// MARK: - Load State

private enum HospitalLoadState {
    case idle
    case loading
    case loaded([HospitalInfo])
    case empty
    case failed(Error)
}

// MARK: - Synthetic Coordinate Helper
// ⚠️ HospitalInfo에 실제 좌표 필드가 없으므로, 망원동 중심 좌표에서
//    인덱스 기반으로 소량 오프셋을 합성해 지도 Marker를 배치합니다.
//    카카오 로컬 API의 x/y 필드 연동 후 이 함수를 교체하세요.

private func syntheticCoordinate(for index: Int, center: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
    // 방사형 오프셋 — 약 200m~600m 범위, 8방향 균등 배치
    let angleStep = (Double.pi * 2) / 8.0
    let angle = angleStep * Double(index % 8)
    // 위도·경도 1도 ≈ 111km → 0.005도 ≈ 555m
    let radius = 0.002 + Double(index % 3) * 0.0015   // 0.002 ~ 0.005도
    return CLLocationCoordinate2D(
        latitude:  center.latitude  + radius * sin(angle),
        longitude: center.longitude + radius * cos(angle)
    )
}

// MARK: - NearbyScreen

/// DongneTab의 "주변" 세그먼트에 임베드하는 메인 뷰.
/// 리스트/지도 토글(실제 동작), ProviderFactory 배선, BLSkeleton·BLEmptyState·BLErrorState 포함.
struct NearbyScreen: View {

    // 망원동 기준 좌표
    private static let centerCoord = CLLocationCoordinate2D(latitude: 37.5563, longitude: 126.9101)

    @State private var selectedCategory: PlaceCategory = .hospital
    @State private var activeFilters: Set<String> = ["현재 영업중"]
    @State private var showMap: Bool = false

    // 병원 로드 상태
    @State private var hospitalState: HospitalLoadState = .idle

    // 지도 카메라 — 망원동 중심 고정
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: NearbyScreen.centerCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
    )

    var body: some View {
        Group {
            if showMap {
                // 지도 뷰 — 스크롤 없이 full-height
                VStack(spacing: 0) {
                    mapToggleBar
                    emergencyCTA
                    categoryChips
                    filterChips
                    mapView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    disclaimer
                        .padding(.horizontal, Spacing.s5)
                        .padding(.vertical, Spacing.s5)
                }
                .background(AppColors.canvas.ignoresSafeArea())
            } else {
                // 리스트 뷰
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        mapToggleBar
                        emergencyCTA
                        categoryChips
                        filterChips
                        listSection
                        disclaimer
                            .padding(.horizontal, Spacing.s5)
                            .padding(.vertical, Spacing.s5)
                    }
                }
                .background(AppColors.canvas.ignoresSafeArea())
            }
        }
        .task(id: activeFilters) {
            await loadHospitals()
        }
    }

    // MARK: Load Hospitals

    private func loadHospitals() async {
        guard selectedCategory == .hospital else { return }
        hospitalState = .loading
        let openNow = activeFilters.contains("현재 영업중")
        do {
            let results = try await ProviderFactory.hospital()
                .hospitals(
                    near: Coordinate(lat: Self.centerCoord.latitude, lng: Self.centerCoord.longitude),
                    openNow: openNow
                )
            hospitalState = results.isEmpty ? .empty : .loaded(results)
        } catch {
            hospitalState = .failed(error)
        }
    }

    // MARK: Map Toggle Bar

    private var mapToggleBar: some View {
        HStack {
            Spacer()
            HStack(spacing: 0) {
                mapToggleButton(icon: "list.bullet", label: "리스트", isSelected: !showMap) {
                    withAnimation(.easeInOut(duration: 0.2)) { showMap = false }
                }
                mapToggleButton(icon: "map", label: "지도", isSelected: showMap) {
                    withAnimation(.easeInOut(duration: 0.2)) { showMap = true }
                }
            }
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .blShadow(.chip)
        }
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, Spacing.s3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("보기 전환")
    }

    private func mapToggleButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.ink3)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(isSelected ? AppColors.ink : Color.clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(label)
    }

    // MARK: Emergency CTA

    private var emergencyCTA: some View {
        NavigationLink {
            EmergencyScreen(onClose: { })
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppColors.danger)
                        .frame(width: 44, height: 44)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("응급 모드")
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundStyle(Color.white)
                    Text("지금 갈 수 있는 소아과를 한 번에")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [Color(hex: 0x2A211D), Color(hex: 0x1A1512)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: Color(hex: 0x282118).opacity(0.22), radius: 10, x: 0, y: 8)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.985))
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, 14)
        .accessibilityLabel("응급 모드 — 지금 갈 수 있는 소아과를 한 번에")
        .accessibilityHint("탭하면 응급 모드 화면을 엽니다")
    }

    // MARK: Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(PlaceCategory.allCases, id: \.self) { cat in
                    BLChip(text: cat.rawValue, on: selectedCategory == cat) {
                        selectedCategory = cat
                        activeFilters = [cat.filterOptions.first ?? ""]
                    }
                    .accessibilityAddTraits(selectedCategory == cat ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.s5)
        }
        .padding(.bottom, 12)
    }

    // MARK: Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(width: 44, height: 36)
                .background(AppColors.surface2, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                .accessibilityHidden(true)

                ForEach(selectedCategory.filterOptions, id: \.self) { option in
                    let isOn = activeFilters.contains(option)
                    BLChip(text: option, on: isOn) {
                        if isOn {
                            activeFilters.remove(option)
                        } else {
                            activeFilters.insert(option)
                        }
                    }
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.s5)
        }
        .padding(.bottom, 14)
    }

    // MARK: Map View (iOS 17 Map { })

    @ViewBuilder
    private var mapView: some View {
        // ⚠️ 합성 좌표 주의: HospitalInfo에 좌표 필드 없어 인덱스 기반 오프셋 사용.
        //    카카오 로컬 API x/y 연동 후 syntheticCoordinate() 제거하고 실제 좌표로 교체 필요.
        let hospitals: [HospitalInfo] = {
            if case .loaded(let list) = hospitalState { return list }
            return []
        }()

        Map(position: $cameraPosition) {
            // 사용자 현재 위치 표시
            UserAnnotation()

            // 병원 마커 — 합성 좌표 배치
            // TODO: 카카오 x/y 연동 후 실 좌표 대체
            ForEach(Array(hospitals.enumerated()), id: \.element.id) { index, hospital in
                let coord = syntheticCoordinate(for: index, center: Self.centerCoord)
                Marker(hospital.name, systemImage: "cross.case.fill", coordinate: coord)
                    .tint(hospital.isOpenNow ? AppColors.primary : AppColors.ink3)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Spacing.s5)
        .padding(.bottom, 14)
        .accessibilityLabel("주변 병원 지도")
        .accessibilityHint("병원 위치가 지도에 표시됩니다")
    }

    // MARK: List Section

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            // 소아과 카테고리: ProviderFactory 데이터 사용
            if selectedCategory == .hospital {
                hospitalListContent
            } else {
                // 소아과 외 카테고리: 기존 mockPlaces 기반
                let filtered = filteredMockPlaces
                Group {
                    Text("현재 영업중 \(filtered.filter(\.isOpen).count)곳 · 거리순")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AppColors.ink3)
                        .padding(.horizontal, 2)
                    if filtered.isEmpty {
                        BLEmptyState(
                            icon: "mappin.slash",
                            title: "주변에 결과가 없어요",
                            message: "필터를 조정하거나 다른 카테고리를 선택해 보세요."
                        )
                    } else {
                        ForEach(filtered) { place in
                            PlaceCard(place: place)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.s5)
    }

    // MARK: Hospital List Content (ProviderFactory 배선)

    @ViewBuilder
    private var hospitalListContent: some View {
        switch hospitalState {
        case .idle, .loading:
            // BLSkeleton 로딩 플레이스홀더
            VStack(spacing: 11) {
                Text("불러오는 중...")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .padding(.horizontal, 2)
                ForEach(0..<3, id: \.self) { _ in
                    BLCard(padding: 15) {
                        HStack(alignment: .center, spacing: 12) {
                            BLSkeleton(width: 48, height: 48, cornerRadius: 13)
                            VStack(alignment: .leading, spacing: 6) {
                                BLSkeleton(height: 14, cornerRadius: Radius.xs)
                                    .frame(maxWidth: .infinity)
                                BLSkeleton(width: 140, height: 12, cornerRadius: Radius.xs)
                                BLSkeleton(width: 80, height: 10, cornerRadius: Radius.xs)
                            }
                            .frame(maxWidth: .infinity)
                            BLSkeleton(width: 44, height: 44, cornerRadius: 13)
                        }
                    }
                }
            }

        case .loaded(let hospitals):
            let openCount = hospitals.filter(\.isOpenNow).count
            VStack(alignment: .leading, spacing: 11) {
                Text("현재 영업중 \(openCount)곳 · 거리순")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppColors.ink3)
                    .padding(.horizontal, 2)
                ForEach(hospitals) { hospital in
                    HospitalCard(hospital: hospital)
                }
            }

        case .empty:
            BLEmptyState(
                icon: "cross.case",
                title: "주변에 소아과가 없어요",
                message: "필터를 조정하거나 잠시 후 다시 확인해 보세요.",
                actionTitle: "필터 초기화",
                action: {
                    activeFilters = ["현재 영업중"]
                }
            )

        case .failed(let error):
            BLErrorState(
                message: error.localizedDescription,
                retry: {
                    Task { await loadHospitals() }
                }
            )
        }
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        Text("영업 정보는 공공데이터 기반이며 실시간과 다를 수 있어요. 방문 전 전화 확인을 권장합니다.")
            .font(.system(size: 11.5, weight: .regular))
            .foregroundStyle(AppColors.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: Filtering Logic (mockPlaces 기반 — 소아과 외 카테고리용)

    private var filteredMockPlaces: [NearbyPlace] {
        mockPlaces
            .filter { $0.category == selectedCategory }
            .filter { place in
                if activeFilters.isEmpty { return true }
                var matches = true
                if activeFilters.contains("현재 영업중") { matches = matches && place.isOpen }
                if activeFilters.contains("야간진료") { matches = matches && place.hasNightCare }
                if activeFilters.contains("공휴일진료") { matches = matches && place.hasHolidayCare }
                if activeFilters.contains("24시간") { matches = matches && place.hasNightCare }
                if activeFilters.contains("야간약국") { matches = matches && place.hasNightCare }
                return matches
            }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }
}

// MARK: - HospitalCard (ProviderFactory HospitalInfo용)

private struct HospitalCard: View {
    let hospital: HospitalInfo

    var body: some View {
        BLCard(padding: 15) {
            HStack(alignment: .center, spacing: 12) {
                // 카테고리 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(hex: 0xFAECE7))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xB45840))
                }
                .accessibilityHidden(true)

                // 텍스트 정보
                VStack(alignment: .leading, spacing: 4) {
                    // 이름 + 영업 상태 뱃지
                    HStack(alignment: .center, spacing: 7) {
                        Text(hospital.name)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)

                        if hospital.isOpenNow {
                            BLBadge(tone: .mint, text: "영업중", systemIcon: nil, dot: true)
                        } else {
                            BLBadge(tone: .grey, text: "영업종료", systemIcon: nil, dot: false)
                        }
                    }

                    // 거리·평점·진료과목
                    HStack(spacing: 6) {
                        Text("\(hospital.distanceM)m")
                            .font(AppFont.num(12.5))
                            .foregroundStyle(AppColors.ink2)

                        Text("·").foregroundStyle(AppColors.ink3)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.gold)
                            Text(String(format: "%.1f", hospital.rating))
                                .font(AppFont.num(12.5))
                                .foregroundStyle(AppColors.ink2)
                        }

                        Text("·").foregroundStyle(AppColors.ink3)

                        Text(hospital.department)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                            .lineLimit(1)
                    }

                    // "○분 전 확인" 뱃지
                    BLBadge(
                        tone: hospital.lastCheckedMinutesAgo <= 10 ? .mint : .amber,
                        text: "\(hospital.lastCheckedMinutesAgo)분 전 확인",
                        systemIcon: "clock",
                        dot: false
                    )
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                // 전화 버튼 (44pt)
                phoneButton
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("전화 버튼을 탭하면 전화를 겁니다")
    }

    private var phoneButton: some View {
        Button {
            let raw = hospital.phone
                .replacingOccurrences(of: "-", with: "")
            if let url = URL(string: "tel://\(raw)") {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: "phone.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("전화하기")
        .accessibilityHint("\(hospital.name)에 전화합니다")
    }

    private var accessibilityDescription: String {
        let status = hospital.isOpenNow ? "영업중" : "영업종료"
        return "\(hospital.name), \(status), \(hospital.distanceM)미터, 평점 \(String(format: "%.1f", hospital.rating)), \(hospital.lastCheckedMinutesAgo)분 전 확인"
    }
}

// MARK: - PlaceCard (mockPlaces — 소아과 외 카테고리용, EmergencyScreen 공용)

private struct PlaceCard: View {
    let place: NearbyPlace

    var body: some View {
        BLCard(padding: 15) {
            HStack(alignment: .center, spacing: 12) {
                // 카테고리 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(place.category.iconBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: place.category.systemIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(place.category.iconColor)
                }
                .accessibilityHidden(true)

                // 텍스트 정보
                VStack(alignment: .leading, spacing: 4) {
                    // 이름 + 영업 상태 뱃지
                    HStack(alignment: .center, spacing: 7) {
                        Text(place.name)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)

                        if place.isOpen {
                            BLBadge(tone: .mint, text: "영업중", systemIcon: nil, dot: true)
                        } else {
                            BLBadge(tone: .grey, text: "영업종료", systemIcon: nil, dot: false)
                        }
                    }

                    // 거리·평점·야간진료
                    HStack(spacing: 6) {
                        Text("\(place.distanceMeters)m")
                            .font(AppFont.num(12.5))
                            .foregroundStyle(AppColors.ink2)

                        Text("·").foregroundStyle(AppColors.ink3)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.gold)
                            Text(String(format: "%.1f", place.rating))
                                .font(AppFont.num(12.5))
                                .foregroundStyle(AppColors.ink2)
                        }

                        if place.hasNightCare {
                            Text("·").foregroundStyle(AppColors.ink3)
                            Text("야간진료")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color(hex: 0x5B53B0))
                        }
                    }

                    // 신뢰도 뱃지 ("○분 전 확인")
                    confirmBadge
                }

                Spacer(minLength: 0)

                // 전화 LiquidButton
                phoneButton
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("전화 버튼을 탭하면 전화를 겁니다")
    }

    @ViewBuilder
    private var confirmBadge: some View {
        HStack(spacing: 6) {
            BLBadge(
                tone: place.trustLevel.badgeTone,
                text: "\(place.confirmedMinutesAgo)분 전 확인",
                systemIcon: "clock",
                dot: false
            )
            Text("신뢰도 \(place.trustLevel.label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(.top, 2)
    }

    private var phoneButton: some View {
        Button {
            if let url = URL(string: place.phone) {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: "phone.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("전화하기")
        .accessibilityHint("\(place.name)에 전화합니다")
    }

    private var accessibilityDescription: String {
        let openStatus = place.isOpen ? "영업중" : "영업종료"
        let night = place.hasNightCare ? ", 야간진료 가능" : ""
        return "\(place.name), \(openStatus), \(place.distanceMeters)미터, 평점 \(String(format: "%.1f", place.rating))\(night), \(place.confirmedMinutesAgo)분 전 확인"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NearbyScreen()
    }
}
#endif
