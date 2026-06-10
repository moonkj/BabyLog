// Features/Record/RecordVaccineSection.swift
// BabyLog · 성장 기록 탭 — 예방접종 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI

// MARK: - 예방접종 섹션

struct VaccineSection: View {
    @EnvironmentObject private var store: AppStore

    @State private var vaccines: [VaccineRecord] = []
    @State private var isLoading = false
    @State private var completedSet: Set<UUID> = []

    // vaccineId → 한국어 표시명 매핑
    private func displayName(for vaccineId: String) -> String {
        switch vaccineId {
        case "BCG":    return "BCG (결핵)"
        case "HepB-1": return "B형간염 1차"
        case "HepB-2": return "B형간염 2차"
        case "DTaP-1": return "DTaP 1차"
        case "DTaP-2": return "DTaP 2차"
        case "DTaP-3": return "DTaP 3차"
        case "DTaP-4": return "DTaP 4차"
        case "IPV-1":  return "폴리오(IPV) 1차"
        case "Hib-1":  return "Hib 1차"
        case "PCV-1":  return "폐렴구균(PCV) 1차"
        case "MMR-1":  return "MMR 1차"
        case "Varicella": return "수두"
        default:       return vaccineId
        }
    }

    // scheduledDate와 birthDate를 바탕으로 ageLabel 생성
    private func ageLabel(for record: VaccineRecord, birthDate: Date) -> String {
        guard let scheduled = record.scheduledDate else { return "–" }
        let months = AgeCalculator.childAgeMonths(birthDate: birthDate, asOf: scheduled).months
        switch months {
        case 0:  return "출생 시"
        case 1:  return "생후 1개월"
        default: return "생후 \(months)개월"
        }
    }

    // D-day 계산: 미래 예정일만 표시 (완료 여부와 무관하게 날짜 기반)
    private func dDayLabel(for record: VaccineRecord) -> String? {
        guard record.completedDate == nil, !completedSet.contains(record.id) else { return nil }
        guard let scheduled = record.scheduledDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: scheduled)).day ?? 0
        if diff > 0  { return "D-\(diff)" }
        if diff == 0 { return "D-Day" }
        return nil  // 이미 지난 날짜는 nil (완료 처리 안 됐어도 배지 없음)
    }

    private func isDone(_ record: VaccineRecord) -> Bool {
        completedSet.contains(record.id) || record.completedDate != nil
    }

    // 가장 임박한 미래 예정 접종
    private var nextUpcoming: VaccineRecord? {
        vaccines
            .filter { !isDone($0) }
            .filter {
                guard let d = $0.scheduledDate else { return false }
                return d >= Calendar.current.startOfDay(for: Date())
            }
            .min { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
    }

    var body: some View {
        Group {
            if let child = store.selectedChild {
                vaccineContent(child: child)
            } else {
                BLEmptyState(
                    icon: "syringe",
                    title: "아이 등록 후 접종 일정이 생성돼요",
                    message: "아이 정보를 등록하면\n질병관리청 표준 접종 일정을 안내해드려요."
                )
            }
        }
    }

    @ViewBuilder
    private func vaccineContent(child: Child) -> some View {
        if isLoading {
            vaccineSkeletonView
        } else if vaccines.isEmpty {
            BLEmptyState(
                icon: "syringe",
                title: "접종 일정을 불러오는 중이에요",
                message: "잠시 후 다시 시도해보세요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 임박 접종 배너 (다음 예정 접종 기반)
                if let next = nextUpcoming {
                    upcomingBanner(for: next, birthDate: child.birthDate)
                }

                // 전체 리스트
                ForEach(vaccines) { v in
                    VaccineRow(
                        vaccineId: v.vaccineId,
                        displayName: displayName(for: v.vaccineId),
                        ageLabel: ageLabel(for: v, birthDate: child.birthDate),
                        hospital: v.hospital,
                        done: isDone(v),
                        dDay: dDayLabel(for: v),
                        onToggle: {
                            withAnimation(.easeOut(duration: 0.18)) {
                                if isDone(v) {
                                    completedSet.remove(v.id)
                                } else {
                                    completedSet.insert(v.id)
                                }
                            }
                        }
                    )
                }

                // 의료 면책 안내 문구
                Text("⚠️ 이 일정은 질병관리청 표준 스케줄 참고용이에요. 실제 접종 일정은 담당 소아과 선생님과 확인하세요.")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s2)
                    .accessibilityLabel("접종 일정 안내: 질병관리청 표준 스케줄 참고용이며, 실제 접종은 소아과 의사와 확인하세요.")
            }
            .task(id: child.id) {
                await loadVaccines(birthDate: child.birthDate)
            }
        }
    }

    private var vaccineSkeletonView: some View {
        VStack(spacing: Spacing.s3) {
            // 배너 스켈레톤
            BLCard(padding: 16) {
                HStack(spacing: 12) {
                    BLSkeleton(width: 46, height: 46, cornerRadius: Radius.sm)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        BLSkeleton(height: 14, cornerRadius: Radius.xs).frame(maxWidth: 180)
                        BLSkeleton(height: 12, cornerRadius: Radius.xs).frame(maxWidth: 240)
                    }
                    .frame(maxWidth: .infinity)
                    BLSkeleton(width: 52, height: 28, cornerRadius: 8)
                }
            }
            // 행 스켈레톤 x4
            ForEach(0..<4, id: \.self) { _ in
                BLSkeletonRow()
            }
        }
    }

    @ViewBuilder
    private func upcomingBanner(for record: VaccineRecord, birthDate: Date) -> some View {
        let name = displayName(for: record.vaccineId)
        let dLabel = dDayLabel(for: record) ?? "D-Day"
        let dNum: Int = {
            guard let d = record.scheduledDate else { return 0 }
            return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: Date()),
                to: Calendar.current.startOfDay(for: d)).day ?? 0
        }()

        BLCard(padding: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(AppColors.surface)
                        .frame(width: 46, height: 46)
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(name)가 다가와요")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(AppColors.ink)
                    Text("질병관리청 스케줄 기준 · D-7 알림 설정됨")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                }
                Spacer()
                Text(dLabel)
                    .font(AppFont.num(22, weight: .heavy))
                    .foregroundStyle(AppColors.gold)
                    .accessibilityLabel("\(dNum)일 후")
            }
        }
        .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) 접종 \(dNum)일 후 예정. 알림 설정됨.")
    }

    // MARK: - Async

    private func loadVaccines(birthDate: Date) async {
        isLoading = true
        do {
            let result = try await ProviderFactory.vaccine().schedule(birthDate: birthDate)
            vaccines = result
        } catch {
            vaccines = []
        }
        isLoading = false
    }
}

private struct VaccineRow: View {
    // VaccineSection.MockVaccine은 private이므로 필요한 필드만 받는다
    let vaccineId: String
    let displayName: String
    let ageLabel: String
    let hospital: String?
    let done: Bool
    let dDay: String?
    let onToggle: () -> Void

    var body: some View {
        BLCard(padding: 14, flat: true) {
            HStack(spacing: 12) {
                // 색+아이콘 3중 인코딩
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(done ? AppColors.primarySoft : AppColors.surface3)
                        .frame(width: 38, height: 38)
                    Image(systemName: done ? "checkmark.circle.fill" : "syringe")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(done ? AppColors.primary : AppColors.ink3)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    HStack(spacing: 4) {
                        Text(ageLabel)
                        if let hosp = hospital, done {
                            Text("·").foregroundStyle(AppColors.ink3)
                            Text(hosp)
                        }
                    }
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                }

                Spacer()

                // 상태 배지
                if done {
                    BLBadge(tone: .mint, text: "완료", systemIcon: "checkmark")
                        .accessibilityLabel("접종 완료")
                } else if let d = dDay {
                    BLBadge(tone: d == "D-Day" ? .coral : .amber,
                            text: d,
                            systemIcon: "calendar")
                    .accessibilityLabel("접종 예정 \(d)")
                } else {
                    BLBadge(tone: .grey, text: "예정", systemIcon: "clock")
                        .accessibilityLabel("접종 예정")
                }

                // 체크 버튼 (44pt 터치타깃) — 체크 드로우 모션(§8.5)
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .strokeBorder(done ? AppColors.primary : AppColors.line2,
                                          lineWidth: 2)
                            .frame(width: 24, height: 24)
                        CheckDrawView(isOn: done, size: 14, color: AppColors.primary)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.93))
                .accessibilityLabel(done ? "접종 완료 취소" : "\(displayName) 접종 완료로 표시")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
