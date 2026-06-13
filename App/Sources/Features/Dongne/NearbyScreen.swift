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
        // 모든 카테고리 필터칩 미노출 — 데이터 소스가 영업시간/연령/실내외를 정확히 주지 않아
        // 정직하게 지킬 수 없는 필터는 두지 않는다(거리순 전체 노출).
        []
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

/// 병원 카드 영업 상태 — 실제 상세조회 결과 기반.
enum HospitalOpenState { case open, closed, checking, unknown }

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

// MARK: - 현재 위치 제공 (CLLocationManager)

/// 주변 검색용 사용자 현재 위치. 권한 허용 시 GPS 좌표 1회 요청.
/// 거부/미확인이면 coordinate == nil → 화면에서 폴백 좌표 사용.
final class NearbyLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// 화면 재생성(세그먼트 전환)에도 위치/권한이 유지되도록 공유 인스턴스 사용.
    static let shared = NearbyLocationProvider()

    @Published var coordinate: CLLocationCoordinate2D?
    /// 역지오코딩된 현재 행정동(동/읍/면/리) — 제목 옆 표시용.
    @Published var localityName: String?
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedCoord: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 권한 상태(거부 시 UI에서 안내용)
    @Published var denied: Bool = false

    /// 현재 좌표를 행정동 이름으로 역지오코딩(과호출 방지: 150m 이상 이동 시에만).
    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        if let last = lastGeocodedCoord {
            let moved = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            if moved < 150, localityName != nil { return }
        }
        lastGeocodedCoord = coord
        let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let ko = Locale(identifier: "ko_KR")
        geocoder.reverseGeocodeLocation(loc, preferredLocale: ko) { [weak self] placemarks, _ in
            guard let self, let p = placemarks?.first else { return }
            // 동/읍/면/리는 보통 subLocality, 없으면 locality(시·군·구) 폴백
            let name = p.subLocality ?? p.locality ?? p.administrativeArea
            DispatchQueue.main.async { self.localityName = name }
        }
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        case .denied, .restricted:
            denied = true
        @unknown default:
            break
        }
    }

    private func beginUpdates() {
        denied = false
        // 캐시된 마지막 위치가 있으면 즉시 사용(빠른 표시)
        if let cached = manager.location?.coordinate {
            coordinate = cached
            reverseGeocode(cached)
        }
        // 연속 갱신으로 첫 양호 fix 확보(one-shot requestLocation은 실내·타임아웃에 자주 실패)
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            beginUpdates()
        case .denied, .restricted:
            denied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let c = locations.last?.coordinate else { return }
        coordinate = c
        denied = false
        reverseGeocode(c)
        manager.stopUpdatingLocation()   // 첫 양호 fix 후 정지(배터리)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 위치 실패 → 폴백 좌표 유지(무시), 갱신은 계속 시도됨
    }
}

/// 카테고리별 결과 캐시 — 화면 재생성(세그먼트 전환: 주변→마켓→주변)에도 유지되도록 싱글톤.
/// @State로 두면 NearbyScreen이 재생성될 때 캐시가 사라져 매번 재검색된다.
final class NearbyResultCache {
    static let shared = NearbyResultCache()
    struct Entry {
        let coord: CLLocationCoordinate2D
        let results: [HospitalInfo]
        let at: Date
    }
    var entries: [PlaceCategory: Entry] = [:]
}

/// DongneTab의 "주변" 세그먼트에 임베드하는 메인 뷰.
/// 리스트/지도 토글(실제 동작), ProviderFactory 배선, BLSkeleton·BLEmptyState·BLErrorState 포함.
struct NearbyScreen: View {

    // 위치 권한 거부/미확인 시 폴백 좌표(서울 도심)
    private static let centerCoord = CLLocationCoordinate2D(latitude: 37.5563, longitude: 126.9101)

    /// 실제 사용자 위치 — 공유 인스턴스(세그먼트 전환에도 유지)
    @ObservedObject private var locationProvider = NearbyLocationProvider.shared
    /// 검색에 쓸 좌표(현재 위치 우선, 없으면 폴백)
    private var searchCoord: CLLocationCoordinate2D {
        locationProvider.coordinate ?? Self.centerCoord
    }

    @State private var selectedCategory: PlaceCategory = .hospital
    // activeFilters 상태 제거 — 필터칩 UI가 없는데 초기값("현재 영업중")이 첫 소아과 조회에만
    // openNow:true로 적용돼 카테고리 전환 후와 결과가 달라지는 비결정성이 있었다.
    @State private var showMap: Bool = false

    // 병원 로드 상태
    @State private var hospitalState: HospitalLoadState = .idle
    // 병원별 실제 영업 여부(상세 영업시간 조회 결과). ykiho→영업중. 조회 완료한 ykiho는 openChecked에.
    @State private var openStatus: [String: Bool] = [:]
    @State private var openChecked: Set<String> = []
    @State private var openLoading = false   // 영업조회 진행 중 — 끝나면 미조회분은 '미확인'으로(확인중 고착 방지)

    // 키즈카페·놀이터(카카오 로컬) 로드 상태 — 카카오 키 연동 후 실데이터
    @State private var places: [Place] = []
    @State private var placesLoading = false
    /// 키즈카페·놀이터 조회 실패 — 빈 결과와 구분해 재시도 UI를 보여준다.
    @State private var placesFailed = false

    /// 위치 획득 타임아웃(권한은 있으나 GPS가 느림) — 권한 거부(denied)와 구분.
    @State private var locationSlow = false

    // 선택된 카드 id — 그 카드의 아이콘만 연속 애니메이션(한 번에 1개라 렉 없음).
    @State private var selectedNearbyID: String? = nil


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
                        locationHint
                        categoryChips
                        filterChips
                        listSection
                        Rectangle()
                            .fill(AppColors.line)
                            .frame(height: 1)
                            .padding(.horizontal, Spacing.s5)
                            .padding(.top, Spacing.s5)
                        disclaimer
                            .padding(.horizontal, Spacing.s5)
                            .padding(.top, Spacing.s4)
                            .padding(.bottom, Spacing.s6)
                    }
                }
                .background(AppColors.canvas.ignoresSafeArea())
            }
        }
        // 첫 진입 1회 트리거 — activeFilters 제거로 onChange와의 이중 트리거(중복 조회)도 함께 해소.
        .task {
            await reloadCurrent()
        }
        .onAppear { locationProvider.start() }
        // 카테고리 전환 시 재로드(소아과·약국=HIRA / 키즈카페·놀이터=애플 지도)
        .onChange(of: selectedCategory) { _, _ in
            // 장소 카테고리(키즈카페·놀이터)는 지도 미지원 → 리스트로 강제(stale 병원 마커 방지).
            if isPlaceCategory && showMap { showMap = false }
            // 카테고리 전환 — 이전 카테고리의 영업조회 진행 상태가 남아 '확인 중' 고착되지 않게 리셋.
            // (조회 도중 이탈하면 openLoading=false가 실행되지 않고, 복귀 시 캐시 히트로 재조회도 안 되던 버그)
            openStatus = [:]; openChecked = []; openLoading = false
            Task { await reloadCurrent() }
        }
        // 위치 획득 타임아웃(8초) — 권한은 있는데 GPS가 느린 경우. denied로 위장하지 않고
        // locationSlow로 구분해 폴백 지역으로 검색 + "위치를 찾는 중" 안내(설정 CTA 미노출).
        .task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            if locationProvider.coordinate == nil && !locationProvider.denied {
                locationSlow = true
                await reloadCurrent()
            }
        }
        // 현재 위치가 잡히면 그 좌표로 다시 검색 + 지도 이동
        .onChange(of: locationProvider.coordinate?.latitude) { _, lat in
            guard lat != nil else { return }
            locationSlow = false
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: searchCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
            }
            // force:false — GPS가 미세하게 재방출돼도 같은 위치(±400m)면 캐시 적중→재호출 없음.
            Task { await reloadCurrent() }
        }
    }

    // MARK: Load (dispatch)

    /// HIRA 실데이터로 로드하는 카테고리(소아과·약국)
    private var isLiveCategory: Bool {
        selectedCategory == .hospital || selectedCategory == .pharmacy
    }
    /// 애플 지도(MKLocalSearch)로 검색하는 카테고리(키즈카페·놀이터)
    private var isPlaceCategory: Bool {
        selectedCategory == .kidsCafe || selectedCategory == .playground
    }

    private func reloadCurrent(force: Bool = false) async {
        if isLiveCategory { await loadHospitals(force: force) }
        else { await loadPlaces() }
    }

    /// 키즈카페·놀이터 — 하이브리드:
    /// 카카오 키가 있으면 카카오 로컬(한국 POI 더 풍부), 없으면 애플 지도(키/비즈앱 불필요).
    private func loadPlaces() async {
        guard isPlaceCategory else { return }
        // locationSlow(GPS 타임아웃) 후엔 폴백 좌표로 실제 검색해야 하므로 대기 가드에서 제외.
        // (제외하지 않으면 타임아웃 후 reloadCurrent()가 또 막혀 레이더가 영원히 돈다)
        if locationProvider.coordinate == nil && !locationProvider.denied && !locationSlow {
            placesLoading = true; places = []
            return
        }
        let category = selectedCategory
        let c = searchCoord
        placesLoading = true
        placesFailed = false
        // 애플 한국 POI가 단일 키워드론 빈약할 수 있어 동의어를 순차 시도(첫 결과 사용).
        let queries: [String] = category == .kidsCafe
            ? ["키즈카페", "키즈 카페", "어린이카페", "kids cafe", "실내놀이터"]
            : ["놀이터", "어린이공원", "어린이놀이터", "공원", "playground"]
        let coord = Coordinate(lat: c.latitude, lng: c.longitude)
        var result: [Place] = []
        // 실패(throw)와 "빈 결과"를 구분 — 실패면 placesFailed로 재시도 UI를 보여준다.
        var didFail = false
        do {
            if !ProviderFactory.isMock(APIConfig.kakaoRESTKeyName) {
                // 카카오 키 연동됨 → 카카오 로컬(더 촘촘한 한국 장소 데이터)
                result = try await ProviderFactory.place().search(queries[0], near: coord)
            } else {
                // 키 없음 → 애플 지도 MKLocalSearch(동의어 순차 시도)
                for q in queries {
                    let r = try await appleLocalSearch(query: q, center: c)
                    if !r.isEmpty { result = r; break }
                }
            }
        } catch {
            didFail = true
        }
        guard category == selectedCategory else { return }
        if didFail {
            places = []
            placesFailed = true
        } else {
            places = result.sorted { $0.distanceM < $1.distanceM }
        }
        placesLoading = false
    }

    /// 애플 지도 POI 검색 → Place 매핑(직선거리 계산).
    private func appleLocalSearch(query: String, center: CLLocationCoordinate2D) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 15_000, longitudinalMeters: 15_000)
        // resultTypes 제한 제거 — POI 누락 방지(기본값으로 주소+POI 모두 허용)
        let response = try await MKLocalSearch(request: request).start()
        let me = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return response.mapItems.compactMap { item in
            let pm = item.placemark
            let dist = Int(me.distance(from: CLLocation(latitude: pm.coordinate.latitude, longitude: pm.coordinate.longitude)))
            return Place(
                id: "\(pm.coordinate.latitude),\(pm.coordinate.longitude)-\(item.name ?? "")",
                name: item.name ?? "이름 없음",
                address: pm.title ?? "",
                phone: item.phoneNumber ?? "",
                category: query,
                distanceM: dist,
                rating: 0
            )
        }
    }

    private func loadHospitals(force: Bool = false) async {
        guard isLiveCategory else { return }
        // 현재 위치 확보 전(권한 거부도 아님)이면 폴백(서울)으로 잘못 검색하지 않고 대기.
        // GPS가 도착하면 onChange가 이 함수를 다시 호출 → 그때 실제 내 위치로 검색.
        // 단, locationSlow(GPS 타임아웃) 후엔 폴백 좌표로 실제 검색해야 하므로 대기하지 않는다.
        if locationProvider.coordinate == nil && !locationProvider.denied && !locationSlow {
            hospitalState = .loading
            return
        }
        let category = selectedCategory
        let c = searchCoord
        // 캐시 히트 — 같은 위치(±400m)·10분 이내면 네트워크 호출 없이 즉시 표시(탭 전환 빠름)
        if !force, let cached = NearbyResultCache.shared.entries[category],
           Self.metersBetween(cached.coord, c) < 400,
           Date().timeIntervalSince(cached.at) < 600 {
            hospitalState = cached.results.isEmpty ? .empty : .loaded(cached.results)
            // 탭 전환 등으로 @State가 일부만 채워졌어도 영업상태를 다시 조회
            // (조회 도중 카테고리 이탈로 '부분 충전'된 경우도 포함 — isEmpty 조건이면 재조회를 건너뛰어
            //  나머지가 "확인 중"으로 고착되던 버그)
            if category == .hospital, !cached.results.isEmpty, openChecked.count < cached.results.count {
                await fetchOpenStatus(cached.results, category: category)
            }
            return
        }
        hospitalState = .loading
        openStatus = [:]; openChecked = []; openLoading = false   // 새 검색 — 영업상태 초기화(스테일 방지)
        // 기본 목록 API엔 영업시간 정보가 없어 openNow는 항상 false — 실제 영업여부는 상세조회로 확인.
        let openNow = false
        do {
            let provider = category == .pharmacy ? ProviderFactory.pharmacy() : ProviderFactory.hospital()
            let results = try await provider.hospitals(
                near: Coordinate(lat: c.latitude, lng: c.longitude),
                openNow: openNow
            )
            let finalResults: [HospitalInfo]
            if category == .hospital {
                // dgsbjtCd=11은 소아청소년과 '등록' 기관이라 가정의학·내과·정형외과까지 섞임 →
                // 이름에 소아 관련 키워드 있는 진짜 소아과/아동병원만(없으면 전체 폴백).
                let pediatricKeywords = ["소아", "아동", "어린이", "키즈"]
                let pediatric = results.filter { h in pediatricKeywords.contains { h.name.contains($0) } }
                // 표시는 가까운 30곳까지 — 그 전부의 실제 영업여부를 조회해 '미조회 미확인'을 없앤다.
                // (결과는 provider에서 이미 거리순. 30 초과는 너무 멀어 실효성 낮음.)
                finalResults = Array((pediatric.isEmpty ? results : pediatric).prefix(30))
            } else {
                finalResults = results   // 약국은 필터 없이 전체
            }
            // 응답이 늦게 와도 그 사이 카테고리가 바뀌었으면 무시
            guard category == selectedCategory else { return }
            NearbyResultCache.shared.entries[category] = .init(coord: c, results: finalResults, at: Date())
            hospitalState = finalResults.isEmpty ? .empty : .loaded(finalResults)
            // 병원은 가까운 곳들의 실제 영업 여부를 상세조회로 확인(미확인 방치 X).
            if category == .hospital, !finalResults.isEmpty {
                await fetchOpenStatus(finalResults, category: category)
            }
        } catch {
            guard category == selectedCategory else { return }
            hospitalState = .failed(error)
        }
    }

    /// 가까운 순 상위 N곳의 실제 영업 여부를 상세 영업시간으로 동시 조회(표시되는 30곳 전부).
    /// 결과가 도착하는 대로 카드 뱃지가 미확인→영업중/영업종료로 갱신된다. 불명은 미확인 유지.
    private func fetchOpenStatus(_ hospitals: [HospitalInfo], category: PlaceCategory) async {
        // 표시되는 곳(가까운 30곳)을 전부 조회 — 미조회로 인한 '미확인'을 남기지 않는다.
        let targets = Array(hospitals.prefix(30))
        openLoading = true
        await withTaskGroup(of: (String, Bool?).self) { group in
            for h in targets {
                group.addTask { (h.id, await HospitalDetailService.isOpenNow(ykiho: h.id)) }
            }
            for await (id, open) in group {
                guard selectedCategory == category else { return }   // 카테고리 바뀌면 중단
                openChecked.insert(id)
                if let open { openStatus[id] = open }
            }
        }
        if selectedCategory == category { openLoading = false }   // 완료 — 미조회분은 '미확인'으로 확정
    }

    /// 카드에 넘길 영업 상태 — 실제 조회 결과 우선. 조회 중엔 확인중, 끝났는데 결과 없으면 미확인.
    private func openState(for h: HospitalInfo) -> HospitalOpenState {
        // 약국: 목록 응답에 요일별 운영시간이 포함돼 hoursKnown=true → 바로 영업중/종료.
        if h.hoursKnown { return h.isOpenNow ? .open : .closed }
        if let s = openStatus[h.id] { return s ? .open : .closed }   // 병원: 상세조회 결과
        if openChecked.contains(h.id) { return .unknown }       // 조회했으나 영업시간 불명
        if openLoading && selectedCategory == .hospital { return .checking }  // 아직 조회 중
        return .unknown                                          // 시간 데이터 없음(폴백·전화 확인)
    }

    /// 두 좌표 간 직선거리(미터) — 캐시 무효화 판단용.
    private static func metersBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    // MARK: 위치 권한 안내

    @ViewBuilder
    private var locationHint: some View {
        if locationProvider.denied {
            // 실제 권한 거부 — 설정 열기 CTA 노출.
            HStack(alignment: .top, spacing: Spacing.s3) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 18)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("기본 지역을 보여드리고 있어요")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text("위치를 켜면 내 주변 결과로 바뀌어요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.s2)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("설정 열기")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, Spacing.s3)
                        .frame(height: 32)
                        .background(AppColors.surface, in: Capsule())
                        .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .frame(minHeight: 44)
                .accessibilityLabel("위치 설정 열기")
                .accessibilityHint("설정 앱에서 위치 권한을 켤 수 있어요")
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.22), lineWidth: 1)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s1)
            .padding(.bottom, Spacing.s3)
            .accessibilityElement(children: .contain)
        } else if locationSlow {
            // 권한은 있으나 GPS가 느린 상태 — 거부가 아니므로 설정 CTA 대신 "다시 시도"만.
            HStack(alignment: .top, spacing: Spacing.s3) {
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 18)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("위치를 찾는 중이에요")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text("잠시 후 다시 시도해 주세요. 그동안 기본 지역을 보여드려요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.s2)
                Button {
                    locationProvider.start()
                    Task { await reloadCurrent(force: true) }
                } label: {
                    Text("다시 시도")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                        .padding(.horizontal, Spacing.s3)
                        .frame(height: 32)
                        .background(AppColors.surface, in: Capsule())
                        .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(LiquidPressStyle(scale: 0.96))
                .frame(minHeight: 44)
                .accessibilityLabel("위치 다시 찾기")
                .accessibilityHint("현재 위치를 다시 찾아 주변 결과를 새로고침합니다")
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.gold.opacity(0.22), lineWidth: 1)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s1)
            .padding(.bottom, Spacing.s3)
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: Map Toggle Bar

    // 장소 카테고리(키즈카페·놀이터)는 실좌표 지도 마커가 없어 리스트만 노출 → 토글 숨김.
    @ViewBuilder
    private var mapToggleBar: some View {
        if isLiveCategory {
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
                .padding(3)
                .background(AppColors.surface2, in: Capsule())
                .overlay { Capsule().stroke(AppColors.line, lineWidth: 1) }
                .blShadow(.chip)
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.bottom, Spacing.s3)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("보기 전환")
        }
    }

    private func mapToggleButton(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.ink3)
            .padding(.horizontal, Spacing.s3)
            .frame(height: 32)
            .background(isSelected ? AppColors.ink : Color.clear, in: Capsule())
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel(label)
    }


    // MARK: Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s2) {
                ForEach(PlaceCategory.allCases.filter { $0 != .playground }, id: \.self) { cat in
                    BLChip(text: cat.rawValue, on: selectedCategory == cat) {
                        // activeFilters 제거 — 필터 상태 갱신 불필요(재조회는 onChange가 담당).
                        selectedCategory = cat
                    }
                    .accessibilityAddTraits(selectedCategory == cat ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, Spacing.s5)
        }
        .padding(.bottom, Spacing.s3)
    }

    // MARK: Filter Chips

    @ViewBuilder
    private var filterChips: some View {
        // 필터칩 미노출(filterOptions가 전 카테고리 빈 배열) + activeFilters 상태 제거 — 빈 뷰 고정.
        // 데이터 소스가 영업시간/연령 정보를 정직하게 주지 않아 지킬 수 없는 필터는 두지 않는다.
        EmptyView()
    }

    // MARK: Map View (iOS 17 Map { })

    @ViewBuilder
    private var mapView: some View {
        let hospitals: [HospitalInfo] = {
            if case .loaded(let list) = hospitalState { return list }
            return []
        }()

        Map(position: $cameraPosition) {
            // 사용자 현재 위치 표시
            UserAnnotation()

            // 마커 — HIRA 실좌표(좌표 없으면 합성으로 폴백)
            ForEach(Array(hospitals.enumerated()), id: \.element.id) { index, hospital in
                let coord: CLLocationCoordinate2D = {
                    if let la = hospital.latitude, let lo = hospital.longitude {
                        return CLLocationCoordinate2D(latitude: la, longitude: lo)
                    }
                    return syntheticCoordinate(for: index, center: searchCoord)
                }()
                Marker(hospital.name, systemImage: "cross.case.fill", coordinate: coord)
                    // 마커 색도 카드와 동일하게 실제 상세조회 결과(openState) 기반 — 기본 목록의
                    // isOpenNow(시간정보 없음)로 칠하면 리스트 뱃지와 지도 색이 어긋난다.
                    .tint(openState(for: hospital) == .open ? AppColors.primary : AppColors.ink3)
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
        // 지도는 소아과·약국에서만 노출 → 현재 카테고리 기준 라벨(키즈카페·놀이터 마커 혼동 방지).
        .accessibilityLabel("주변 \(selectedCategory.rawValue) 지도")
        .accessibilityHint("\(selectedCategory.rawValue) 위치가 지도에 표시됩니다")
    }

    // MARK: List Section

    private var listSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            // 소아과·약국: HIRA 실데이터. 키즈카페·놀이터: 애플 지도(MKLocalSearch) 실데이터.
            if isLiveCategory {
                hospitalListContent
            } else {
                placeListContent
            }
        }
        .padding(.horizontal, Spacing.s5)
    }

    // MARK: Result Count Row (영업중 N곳 · 거리순)

    private func resultCountRow(open: Int, total: Int, hoursKnown: Bool, checking: Bool = false) -> some View {
        // 영업시간을 아는 데이터가 있으면 "영업중 N곳", 없으면(기본 목록) "N곳"만 정직 표기.
        // 영업조회가 아직 진행 중이면 미완 카운트("0곳")로 오해하지 않게 "영업 확인 중…"으로 표기.
        let countLabel = checking ? "영업 확인 중…" : (hoursKnown ? "현재 영업중 " : "주변 ")
        let countValue = checking ? "" : (hoursKnown ? "\(open)곳" : "\(total)곳")
        return HStack(spacing: Spacing.s2) {
            HStack(spacing: Spacing.s2) {
                HStack(spacing: 5) {
                    if hoursKnown && !checking {
                        Circle()
                            .fill(BadgeTone.mint.ink)
                            .frame(width: 6, height: 6)
                    }
                    Text(countLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                    + Text(countValue)
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                }
                Text("·")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppColors.line2)
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(AppColors.ink3)
                    Text("거리순")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .accessibilityElement(children: .combine)
            // 조회 진행 중엔 VoiceOver도 동일하게 "영업 확인 중"으로 안내.
            .accessibilityLabel(checking
                                ? "영업 확인 중, 거리순 정렬"
                                : (hoursKnown ? "현재 영업중 \(open)곳, 거리순 정렬" : "주변 \(total)곳, 거리순 정렬"))

            Spacer(minLength: 0)

            // 수동 새로고침 — 캐시 무시하고 현재 위치로 재조회
            if isLiveCategory {
                Button {
                    Task { await loadHospitals(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.ink2)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surface2, in: Circle())
                        .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
                }
                .accessibilityLabel("새로고침")
            }
        }
        .padding(.horizontal, Spacing.s1)
        .padding(.top, Spacing.s1)
        .padding(.bottom, Spacing.s1)
    }

    // MARK: Hospital List Content (ProviderFactory 배선)

    @ViewBuilder
    private var hospitalListContent: some View {
        switch hospitalState {
        case .idle, .loading:
            // 화면 중앙에서 도는 레이더(주변 훑기)
            VStack(spacing: Spacing.s4) {
                RadarSweepView(size: 132)
                Text("주변을 살펴보는 중…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
            }
            .frame(maxWidth: .infinity, minHeight: 460, alignment: .center)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("주변을 살펴보는 중")

        case .loaded(let hospitals):
            // 영업시간 데이터가 있으면 '영업중 N곳', 없으면 총 개수만 정직 표기.
            // 병원=상세조회 결과 / 약국=목록에 시간 포함(hoursKnown) → 둘 다 영업 카운트.
            let checksOpen = selectedCategory == .hospital || hospitals.contains { $0.hoursKnown }
            let openCount = hospitals.filter { openState(for: $0) == .open }.count
            VStack(alignment: .leading, spacing: Spacing.s3) {
                if ProviderFactory.isMock(APIConfig.hiraKeyName) {
                    BLSampleNote(message: "지금은 샘플 병원 정보예요. 공공데이터 키를 연결하면 실제 우리 동네 병원으로 채워져요.")
                }
                // 영업조회 진행 중엔 카운트 대신 "영업 확인 중…" 표기(소아과만 영업조회 수행).
                resultCountRow(open: openCount, total: hospitals.count, hoursKnown: checksOpen,
                               checking: checksOpen && openLoading)
                ForEach(hospitals) { hospital in
                    HospitalCard(
                        hospital: hospital,
                        category: selectedCategory,
                        openState: openState(for: hospital),
                        isSelected: selectedNearbyID == hospital.id,
                        onTap: { selectedNearbyID = (selectedNearbyID == hospital.id) ? nil : hospital.id }
                    )
                }
            }

        case .empty:
            BLEmptyState(
                icon: selectedCategory == .pharmacy ? "pills" : "cross.case",
                title: selectedCategory == .pharmacy ? "주변에 약국이 없어요" : "주변에 소아과가 없어요",
                message: "잠시 후 다시 확인하거나, 위치를 바꿔 검색해 보세요.",
                actionTitle: "다시 불러오기",
                action: {
                    // force:true — 빈 결과도 캐시에 남아 있어, 캐시를 무시해야 실제 재조회가 된다.
                    Task { await loadHospitals(force: true) }
                }
            )

        case .failed:
            BLErrorState(
                message: "주변 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                retry: {
                    Task { await loadHospitals(force: true) }
                }
            )
        }
    }

    // MARK: Place List Content (키즈카페·놀이터 — 애플 지도 MKLocalSearch)

    @ViewBuilder
    private var placeListContent: some View {
        if placesLoading && places.isEmpty {
            VStack(spacing: Spacing.s4) {
                RadarSweepView(size: 132)
                Text("주변을 살펴보는 중…")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
            }
            .frame(maxWidth: .infinity, minHeight: 460, alignment: .center)
            .accessibilityLabel("주변을 살펴보는 중")
        } else if placesFailed {
            // 조회 실패 — 빈 결과와 구분해 재시도 UI(병원 .failed와 동일 처리).
            BLErrorState(
                message: "주변 정보를 불러오지 못했어요. 잠시 후 다시 시도해 주세요.",
                retry: { Task { await loadPlaces() } }
            )
        } else if places.isEmpty {
            BLEmptyState(
                icon: "mappin.slash",
                title: "주변에 \(selectedCategory.rawValue)가 없어요",
                message: "조금 더 넓은 동네로 이동하거나 잠시 후 다시 시도해 보세요.",
                actionTitle: "다시 불러오기",
                action: { Task { await loadPlaces() } }
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack(spacing: Spacing.s2) {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(selectedCategory.iconColor)
                        Text("주변 ")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                        + Text("\(places.count)곳")
                            .font(.system(size: 12.5, weight: .heavy))
                            .foregroundStyle(AppColors.ink)
                        + Text(" · 거리순")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(AppColors.ink3)
                    }
                    Spacer(minLength: 0)
                    Button { Task { await loadPlaces() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.ink2)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surface2, in: Circle())
                            .overlay { Circle().stroke(AppColors.line, lineWidth: 1) }
                    }
                    .accessibilityLabel("새로고침")
                }
                .padding(.horizontal, Spacing.s1)

                ForEach(places) { place in
                    PlaceResultCard(
                        place: place,
                        category: selectedCategory,
                        isSelected: selectedNearbyID == place.id,
                        onTap: { selectedNearbyID = (selectedNearbyID == place.id) ? nil : place.id }
                    )
                }

                Text("장소 정보: Apple 지도. 영업 여부·연령대는 방문 전 확인하세요.")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppColors.ink3)
                    .padding(.horizontal, Spacing.s1)
                    .padding(.top, Spacing.s1)
            }
        }
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: Spacing.s1 + 1) {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.ink3)
                .accessibilityHidden(true)
            Text("영업 정보는 공공데이터 기반이며 실시간과 다를 수 있어요. 방문 전 전화 확인을 권장합니다.")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Filtering Logic (mockPlaces 기반 — 소아과 외 카테고리용)

    private var filteredMockPlaces: [NearbyPlace] {
        // activeFilters 제거 — 필터칩이 없으므로 카테고리 필터 + 거리순 정렬만 유지.
        mockPlaces
            .filter { $0.category == selectedCategory }
            .sorted { $0.distanceMeters < $1.distanceMeters }
    }
}

// MARK: - HospitalCard (ProviderFactory HospitalInfo용)

// MARK: - PlaceResultCard (키즈카페·놀이터 — 애플 지도 결과)

private struct PlaceResultCard: View {
    let place: Place
    let category: PlaceCategory
    var isSelected: Bool = false
    var onTap: () -> Void = {}

    private var distanceText: String {
        place.distanceM >= 1000 ? String(format: "%.1fkm", Double(place.distanceM) / 1000) : "\(place.distanceM)m"
    }

    var body: some View {
        BLCard(padding: Spacing.s4) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(category.iconBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: category.systemIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(category.iconColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.s2) {
                    Text(place.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(distanceText) · \(category.rawValue)")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                HStack(spacing: Spacing.s2) {
                    if !place.phone.isEmpty {
                        Button {
                            let raw = place.phone.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(raw)") { UIApplication.shared.open(url) }
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .fill(MotionIconPalette.green).frame(width: 44, height: 44)
                                PhoneMotionIcon(color: .white, size: 22, animated: isSelected)
                            }.blShadow(.chip)
                        }
                        .buttonStyle(LiquidPressStyle(scale: 0.94))
                        .accessibilityLabel("전화하기")
                    }
                    Button {
                        let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "http://maps.apple.com/?q=\(q)") { UIApplication.shared.open(url) }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(MotionIconPalette.greenSoft).frame(width: 44, height: 44)
                            MapPinMotionIcon(color: MotionIconPalette.green, size: 22, animated: isSelected)
                        }.blShadow(.chip)
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.94))
                    .accessibilityLabel("길찾기")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(place.name), \(distanceText), \(category.rawValue)")
    }
}

private struct HospitalCard: View {
    let hospital: HospitalInfo
    /// 약국/소아과 구분 — 아이콘·톤 분기용 (데이터엔 카테고리 필드가 없어 화면 선택값 전달)
    var category: PlaceCategory = .hospital
    /// 실제 영업 상태(상세 영업시간 조회 결과). 미조회=확인중, 조회실패=미확인.
    var openState: HospitalOpenState = .unknown
    /// 선택됨 — 전화·지도·공유 아이콘 연속 애니메이션.
    var isSelected: Bool = false
    /// 카드 탭 콜백(선택 토글).
    var onTap: () -> Void = {}

    /// 1km 이상이면 km, 미만이면 m로 표기.
    static func distanceText(_ m: Int) -> String {
        m >= 1000 ? String(format: "%.1fkm", Double(m) / 1000) : "\(m)m"
    }

    /// 약국은 알약 아이콘, 그 외(소아과)는 진료 케이스 아이콘 — 한눈에 종별 구분.
    private var iconName: String {
        category == .pharmacy ? "pills.fill" : "cross.case.fill"
    }
    /// 약국은 민트(약국 팔레트), 소아과는 코랄 톤.
    private var iconTone: BadgeTone {
        category == .pharmacy ? .mint : .coral
    }

    var body: some View {
        BLCard(padding: Spacing.s4) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                // 카테고리 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(iconTone.bg)
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(iconTone.ink)
                }
                .accessibilityHidden(true)

                // 텍스트 정보
                VStack(alignment: .leading, spacing: Spacing.s2) {
                    // 이름 — 긴 이름은 2줄까지 표시(짤림 방지)
                    Text(hospital.name)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(2)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    // 영업상태 뱃지 — 병원·약국 공통. 시간 데이터를 알면 영업중/종료, 없으면 전화 확인.
                    // (약국 시간은 응급의료포털 약국정보 서비스 구독 시 채워짐 → openState가 open/closed 반환)
                    HStack(spacing: Spacing.s2) {
                        switch openState {
                        case .open:
                            BLBadge(tone: .mint, text: "영업중", systemIcon: nil, dot: true).fixedSize()
                        case .closed:
                            BLBadge(tone: .grey, text: "영업종료", systemIcon: nil, dot: false).fixedSize()
                        case .checking:
                            BLBadge(tone: .grey, text: "영업시간 확인 중…", systemIcon: nil, dot: false).fixedSize()
                        case .unknown:
                            // 시간 데이터가 없는 곳 — 추측하지 않고 전화 확인을 안내.
                            BLBadge(tone: .grey, text: "전화로 확인", systemIcon: "phone.fill", dot: false).fixedSize()
                        }
                        Spacer(minLength: 0)
                    }

                    // 거리 · 진료과목 — 배지와 분리된 줄(전폭 사용으로 짤림 방지)
                    Text("\(Self.distanceText(hospital.distanceM)) · \(hospital.department)")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)

                // 액션 버튼 (전화 / 길찾기 / 공유)
                actionButtons
            }
        }
        // 카드(버튼 외 영역) 탭 → 선택 토글(선택된 카드만 아이콘 연속 애니메이션)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    // 전화 / 길찾기 — 한 줄(각 44pt 터치 타깃). 공유 버튼 제거.
    private var actionButtons: some View {
        HStack(spacing: Spacing.s2) {
            phoneButton
            directionsButton
        }
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
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(MotionIconPalette.green)
                    .frame(width: 44, height: 44)
                PhoneMotionIcon(color: .white, size: 22, animated: isSelected)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("전화하기")
        .accessibilityHint("\(hospital.name)에 전화합니다")
    }

    // 길찾기 — Apple 지도 앱에서 장소명 검색 (좌표는 합성이므로 이름 검색)
    private var directionsButton: some View {
        Button {
            let q = hospital.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(MotionIconPalette.greenSoft)
                    .frame(width: 44, height: 44)
                MapPinMotionIcon(color: MotionIconPalette.green, size: 22, animated: isSelected)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("길찾기")
        .accessibilityHint("\(hospital.name) 위치를 지도 앱에서 열어봅니다")
    }

    // 공유 — 이름 + 주소 텍스트 공유
    private var shareButton: some View {
        ShareLink(item: "\(hospital.name) \(hospital.address)") {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(MotionIconPalette.greenSoft)
                    .frame(width: 44, height: 44)
                ShareMotionIcon(color: MotionIconPalette.green, size: 22, animated: isSelected)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("공유하기")
        .accessibilityHint("\(hospital.name) 정보를 공유합니다")
    }

    private var accessibilityDescription: String {
        let status: String
        switch openState {
        case .open: status = "영업중"
        case .closed: status = "영업종료"
        case .checking: status = "영업시간 확인 중"
        case .unknown: status = "영업시간 미확인, 전화로 확인 권장"
        }
        return "\(hospital.name), \(status), \(hospital.distanceM)미터, \(hospital.department)"
    }
}

// MARK: - PlaceCard (mockPlaces — 소아과 외 카테고리용, EmergencyScreen 공용)

private struct PlaceCard: View {
    let place: NearbyPlace

    var body: some View {
        BLCard(padding: Spacing.s4) {
            HStack(alignment: .center, spacing: Spacing.s3) {
                // 카테고리 아이콘
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(place.category.iconBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: place.category.systemIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(place.category.iconColor)
                }
                .accessibilityHidden(true)

                // 텍스트 정보
                VStack(alignment: .leading, spacing: 5) {
                    // 이름 + 영업 상태 뱃지
                    HStack(alignment: .center, spacing: Spacing.s2) {
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
                    HStack(spacing: Spacing.s1 + 2) {
                        Text("\(place.distanceMeters)m")
                            .font(AppFont.num(12.5))
                            .foregroundStyle(AppColors.ink2)

                        Text("·").foregroundStyle(AppColors.line2)

                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.gold)
                            Text(String(format: "%.1f", place.rating))
                                .font(AppFont.num(12.5))
                                .foregroundStyle(AppColors.ink2)
                        }

                        if place.hasNightCare {
                            Text("·").foregroundStyle(AppColors.line2)
                            Text("야간진료")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(BadgeTone.purple.ink)
                        }
                    }

                    // 신뢰도 뱃지 ("○분 전 확인")
                    confirmBadge
                }

                Spacer(minLength: 0)

                // 액션 버튼 (전화 / 길찾기 / 공유)
                actionButtons
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    // 전화 / 길찾기 — 한 줄(각 44pt 터치 타깃). 공유 버튼 제거.
    private var actionButtons: some View {
        HStack(spacing: Spacing.s2) {
            phoneButton
            directionsButton
        }
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
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: "phone.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("전화하기")
        .accessibilityHint("\(place.name)에 전화합니다")
    }

    // 길찾기 — Apple 지도 앱에서 장소명 검색 (좌표는 합성이므로 이름 검색)
    private var directionsButton: some View {
        Button {
            let q = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "http://maps.apple.com/?q=\(q)") {
                UIApplication.shared.open(url)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.surface2)
                    .frame(width: 44, height: 44)
                Image(systemName: "map.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("길찾기")
        .accessibilityHint("\(place.name) 위치를 지도 앱에서 열어봅니다")
    }

    // 공유 — 이름 + 전화번호 텍스트 공유
    private var shareButton: some View {
        ShareLink(item: "\(place.name) \(shareablePhone)") {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(AppColors.surface2)
                    .frame(width: 44, height: 44)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
            }
            .blShadow(.chip)
        }
        .buttonStyle(LiquidPressStyle(scale: 0.94))
        .accessibilityLabel("공유하기")
        .accessibilityHint("\(place.name) 정보를 공유합니다")
    }

    // place.phone은 "tel://..." 형태이므로 공유용으로 스킴을 제거
    private var shareablePhone: String {
        place.phone.replacingOccurrences(of: "tel://", with: "")
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
