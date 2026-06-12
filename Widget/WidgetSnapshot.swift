// WidgetSnapshot.swift — BabyLog Widget Extension
// 위젯에 표시할 순수 데이터 모델 + Provider
//
// 정직성 원칙: 실데이터가 없으면 빈 상태(noData)를 그대로 보여준다.
// 샘플(목업) 데이터는 위젯 갤러리 미리보기(placeholder/snapshot preview)에서만 사용한다.
// 실 데이터 연동 시:
//   1. App Target & Widget Extension 모두 App Group 추가 (group.com.babylog.app)
//   2. FileManager.containerURL(forSecurityApplicationGroupIdentifier:)로 state.json 읽기
//   3. 할 일·주변 소아과 실데이터 소스가 생기면 load()에 추가 (그 전까지는 섹션 숨김)

import Foundation

// MARK: - 오늘 할 일

struct TodayTask: Identifiable {
    enum Kind {
        case vaccine   // 예방접종
        case subsidy   // 지원금 마감
    }
    let id: UUID
    let kind: Kind
    let title: String      // "BCG 2차"  /  "아동수당 6월 신청 마감"
    let dueDate: Date      // 오늘 또는 임박 날짜
    let isUrgent: Bool     // 마감 D-day 이하
}

// MARK: - 아이 요약

struct ChildSummary {
    let name: String           // 아이 이름 (App Group 실데이터)
    let birthDate: Date
    /// App Group 연동 후 공유 컨테이너에서 이미지 경로를 읽어 교체
    /// 현재는 nil → 플레이스홀더 표시
    let latestPhotoPath: String?

    var dPlusDays: Int {
        let cal = Calendar.current
        let birth = cal.startOfDay(for: birthDate)
        let today = cal.startOfDay(for: Date())
        guard today >= birth else { return 0 }
        return (cal.dateComponents([.day], from: birth, to: today).day ?? 0) + 1
    }

    var ageLabel: String {
        let cal = Calendar.current
        let birth = cal.startOfDay(for: birthDate)
        let today = cal.startOfDay(for: Date())
        guard today >= birth else { return "0개월" }
        let comp = cal.dateComponents([.month, .day], from: birth, to: today)
        let months = comp.month ?? 0
        return months >= 1 ? "\(months)개월" : "\((comp.day ?? 0))일"
    }
}

// MARK: - 주변 응급(소아과) 정보

struct NearbyClinic: Identifiable {
    let id: UUID
    let name: String          // 병원명 (실데이터 소스 연동 후 사용)
    let isOpenNow: Bool
    let distanceMeter: Int?   // nil = 위치 권한 없음
}

// MARK: - 위젯 Entry 데이터 컨테이너

struct BabyLogWidgetData {
    let date: Date
    let tasks: [TodayTask]          // 오늘·내일 이내 할 일 (최대 3) — 실데이터 소스 연동 전에는 항상 빈 배열
    let child: ChildSummary?        // 첫 번째 아이 요약 (App Group 실데이터)
    let clinics: [NearbyClinic]     // 주변 소아과 (최대 2) — 실데이터 소스 연동 전에는 항상 빈 배열
    /// 공유된 실데이터가 전혀 없음 → 위젯은 정직한 빈 상태를 렌더한다.
    /// (갤러리 미리보기용 샘플 데이터에서는 false)
    let noData: Bool

    var openClinic: NearbyClinic? { clinics.first(where: { $0.isOpenNow }) }
    var urgentTaskCount: Int { tasks.filter(\.isUrgent).count }
}

// MARK: - App Group 공유 상태 읽기 (앱 모듈 미참조 — 최소 디코딩)

private struct SharedChild: Decodable {
    let name: String
    let birthDate: Date
}
private struct SharedState: Decodable {
    let children: [SharedChild]
}

enum WidgetSnapshotProvider {

    private static let groupId = "group.com.babylog.app"

    /// App Group 컨테이너의 state.json에서 첫 아이를 읽는다. 실패 시 nil(빈 상태 렌더).
    private static func loadSharedChild() -> ChildSummary? {
        guard let container = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: groupId) else { return nil }
        let url = container.appendingPathComponent("state.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let state = try? decoder.decode(SharedState.self, from: data),
              let first = state.children.first else { return nil }
        return ChildSummary(name: first.name, birthDate: first.birthDate, latestPhotoPath: nil)
    }

    /// 실데이터 로드. 목업을 절대 섞지 않는다.
    /// - 공유된 아이가 없으면 noData 빈 상태를 반환한다 (가짜 아이·할 일·소아과 금지).
    /// - 공유된 아이가 있으면 아이 요약만 반환한다. 할 일·주변 소아과는
    ///   실데이터 소스가 아직 없으므로 빈 배열 → 뷰에서 해당 섹션을 숨긴다.
    static func load() -> BabyLogWidgetData {
        let today = Date()

        guard let child = loadSharedChild() else {
            // 실데이터 없음 — 정직한 빈 상태
            return BabyLogWidgetData(date: today, tasks: [], child: nil, clinics: [], noData: true)
        }

        return BabyLogWidgetData(date: today, tasks: [], child: child, clinics: [], noData: false)
    }

    /// 갤러리 미리보기 전용 샘플 — placeholder(in:)/snapshot(isPreview)에서만 사용.
    /// iOS가 위젯 갤러리에 예시 콘텐츠를 기대하는 유일한 경로다. 실제 타임라인에 쓰지 않는다.
    static func placeholder() -> BabyLogWidgetData {
        let today = Date()
        let cal   = Calendar.current
        let birthDate = cal.date(byAdding: .day, value: -90, to: today) ?? today
        return BabyLogWidgetData(
            date: today,
            tasks: [
                TodayTask(id: UUID(), kind: .vaccine, title: "예방접종 예정",
                          dueDate: today, isUrgent: true),
                TodayTask(id: UUID(), kind: .subsidy, title: "지원금 신청 마감",
                          dueDate: cal.date(byAdding: .day, value: 2, to: today) ?? today,
                          isUrgent: false)
            ],
            child: ChildSummary(name: "아기", birthDate: birthDate, latestPhotoPath: nil),
            clinics: [
                NearbyClinic(id: UUID(), name: "소아과의원", isOpenNow: true, distanceMeter: nil)
            ],
            noData: false
        )
    }
}
