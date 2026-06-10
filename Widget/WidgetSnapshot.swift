// WidgetSnapshot.swift — BabyLog Widget Extension
// 위젯에 표시할 순수 데이터 모델 + 목업 Provider
//
// NOTE: App Group 공유는 후속 작업.
// 현재는 목업 데이터만 사용. 실 데이터 연동 시:
//   1. App Target & Widget Extension 모두 com.babylog.app.group App Group 추가
//   2. UserDefaults(suiteName: "group.com.babylog.app") 또는 FileManager
//      containerURL(forSecurityApplicationGroupIdentifier:) 로 JSON 읽기
//   3. WidgetSnapshotProvider.load() 구현 교체

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
    let name: String           // "하준"
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
    let name: String          // "연세소아과"
    let isOpenNow: Bool
    let distanceMeter: Int?   // nil = 위치 권한 없음
}

// MARK: - 위젯 Entry 데이터 컨테이너

struct BabyLogWidgetData {
    let date: Date
    let tasks: [TodayTask]          // 오늘·내일 이내 할 일 (최대 3)
    let child: ChildSummary?        // 첫 번째 아이 요약
    let clinics: [NearbyClinic]     // 주변 소아과 (최대 2)

    var openClinic: NearbyClinic? { clinics.first(where: { $0.isOpenNow }) }
    var urgentTaskCount: Int { tasks.filter(\.isUrgent).count }
}

// MARK: - 목업 데이터 Provider

enum WidgetSnapshotProvider {

    // TODO: App Group 연동 후 이 메서드를 공유 컨테이너 읽기로 교체
    static func load() -> BabyLogWidgetData {
        let today = Date()
        let cal   = Calendar.current

        // 오늘 할 일 목업
        let tasks: [TodayTask] = [
            TodayTask(
                id: UUID(),
                kind: .vaccine,
                title: "DTaP 4차 접종",
                dueDate: today,
                isUrgent: true
            ),
            TodayTask(
                id: UUID(),
                kind: .subsidy,
                title: "아동수당 6월 신청",
                dueDate: cal.date(byAdding: .day, value: 2, to: today) ?? today,
                isUrgent: false
            )
        ]

        // 아이 요약 목업 — 생후 120일 아이
        let birthDate = cal.date(byAdding: .day, value: -120, to: today) ?? today
        let child = ChildSummary(
            name: "하준",
            birthDate: birthDate,
            latestPhotoPath: nil  // App Group 연동 전
        )

        // 주변 소아과 목업
        let clinics: [NearbyClinic] = [
            NearbyClinic(id: UUID(), name: "연세소아과의원", isOpenNow: true,  distanceMeter: 320),
            NearbyClinic(id: UUID(), name: "튼튼어린이의원",  isOpenNow: false, distanceMeter: 580)
        ]

        return BabyLogWidgetData(date: today, tasks: tasks, child: child, clinics: clinics)
    }

    /// placeholder용 — 빠른 렌더, 고정값
    static func placeholder() -> BabyLogWidgetData {
        let today = Date()
        let cal   = Calendar.current
        let birthDate = cal.date(byAdding: .day, value: -90, to: today) ?? today
        return BabyLogWidgetData(
            date: today,
            tasks: [
                TodayTask(id: UUID(), kind: .vaccine, title: "예방접종 예정",
                          dueDate: today, isUrgent: true)
            ],
            child: ChildSummary(name: "아기", birthDate: birthDate, latestPhotoPath: nil),
            clinics: [
                NearbyClinic(id: UUID(), name: "소아과", isOpenNow: true, distanceMeter: nil)
            ]
        )
    }
}
