// Features/Record/RecordVaccineSection.swift
// BabyLog · 성장 기록 탭 — 예방접종 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI

// MARK: - 예방접종 섹션

struct VaccineSection: View {
    @EnvironmentObject private var store: AppStore

    @State private var vaccines: [VaccineRecord] = []
    @State private var isLoading = false

    // 접종 병원 입력 시트(.alert) 상태
    @State private var hospitalPromptVaccineId: String?   // 입력 대상 vaccineId (nil이면 닫힘)
    @State private var hospitalPromptName: String = ""     // 다이얼로그 타이틀용 표시명
    @State private var hospitalInput: String = ""          // TextField 바인딩

    /// 현재 선택 아이 ID (접종 완료 영속 키 구성용)
    private var childId: UUID? { store.selectedChild?.id }

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
        guard !isDone(record) else { return nil }
        guard let scheduled = record.scheduledDate else { return nil }
        let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                   to: Calendar.current.startOfDay(for: scheduled)).day ?? 0
        if diff > 0  { return "D-\(diff)" }
        if diff == 0 { return "D-Day" }
        return nil  // 이미 지난 날짜는 nil (완료 처리 안 됐어도 배지 없음)
    }

    private func isDone(_ record: VaccineRecord) -> Bool {
        guard let cid = childId else { return false }
        return store.isVaccineDone(childId: cid, vaccineId: record.vaccineId)
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
        // 접종 일정 로드: 항상 렌더되는 루트에 부착해 첫 등장·아이 전환 시 반드시 실행
        // (vaccines가 비어 있는 초기 상태에서도 트리거되도록 조건부 밖으로 이동)
        .task(id: store.selectedChild?.id) {
            guard let child = store.selectedChild else { return }
            await loadVaccines(birthDate: child.birthDate)
        }
        // 접종 병원 입력/수정 다이얼로그 (선택 입력 — 건너뛰기 허용)
        .alert(
            hospitalPromptName.isEmpty ? "접종 병원" : "\(hospitalPromptName) 접종 병원",
            isPresented: Binding(
                get: { hospitalPromptVaccineId != nil },
                set: { if !$0 { hospitalPromptVaccineId = nil } }
            )
        ) {
            TextField("어디서 접종하셨나요? (선택)", text: $hospitalInput)
                .textInputAutocapitalization(.never)
            Button("저장") { saveHospitalPrompt() }
            Button("건너뛰기", role: .cancel) { hospitalPromptVaccineId = nil }
        } message: {
            Text("기록해두면 완료 목록에서 바로 확인하고 지도로 찾아볼 수 있어요.")
        }
    }

    // MARK: - 접종 병원 입력

    /// 병원 입력 다이얼로그를 띄운다(신규 완료 시 또는 수정 탭 시).
    private func presentHospitalPrompt(vaccineId: String, name: String) {
        guard let cid = childId else { return }
        hospitalInput = store.vaccineHospital(childId: cid, vaccineId: vaccineId) ?? ""
        hospitalPromptName = name
        hospitalPromptVaccineId = vaccineId
    }

    /// 입력값을 저장한다(빈 값이면 setVaccineHospital이 nil로 정리).
    private func saveHospitalPrompt() {
        guard let cid = childId, let vid = hospitalPromptVaccineId else { return }
        store.setVaccineHospital(childId: cid, vaccineId: vid, hospital: hospitalInput)
        Haptics.success()
        hospitalPromptVaccineId = nil
    }

    /// Apple 지도에서 병원명으로 검색해 연다.
    private func openInMaps(_ hospital: String) {
        #if canImport(UIKit)
        let query = hospital.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? hospital
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
            Haptics.light()
            UIApplication.shared.open(url)
        }
        #endif
    }

    @ViewBuilder
    private func vaccineContent(child: Child) -> some View {
        if isLoading {
            vaccineSkeletonView
        } else if vaccines.isEmpty {
            BLEmptyState(
                icon: "syringe",
                title: "접종 일정을 불러오지 못했어요",
                message: "네트워크 상태를 확인하고\n잠시 후 다시 시도해주세요."
            )
        } else {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                // 임박 접종 배너 (다음 예정 접종 기반)
                if let next = nextUpcoming {
                    upcomingBanner(for: next, birthDate: child.birthDate)
                }

                // 전체 리스트
                ForEach(vaccines) { v in
                    let name = displayName(for: v.vaccineId)
                    VaccineRow(
                        vaccineId: v.vaccineId,
                        displayName: name,
                        ageLabel: ageLabel(for: v, birthDate: child.birthDate),
                        // 영속화된 병원만 노출 (목 데이터 v.hospital은 더 이상 사용 안 함)
                        hospital: store.vaccineHospital(childId: child.id, vaccineId: v.vaccineId),
                        done: isDone(v),
                        dDay: dDayLabel(for: v),
                        onToggle: {
                            let wasDone = isDone(v)
                            withAnimation(.easeOut(duration: 0.18)) {
                                store.toggleVaccine(childId: child.id, vaccineId: v.vaccineId)
                            }
                            // 새로 '완료'가 됐고 병원 기록이 없으면 입력 유도.
                            // 토글·체크 드로우 모션이 먼저 보이도록 다이얼로그는 살짝 지연 표시.
                            if !wasDone,
                               store.vaccineHospital(childId: child.id, vaccineId: v.vaccineId) == nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    presentHospitalPrompt(vaccineId: v.vaccineId, name: name)
                                }
                            }
                        },
                        onTapHospital: { openInMaps($0) },
                        onEditHospital: { presentHospitalPrompt(vaccineId: v.vaccineId, name: name) }
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
    let onTapHospital: (String) -> Void
    let onEditHospital: () -> Void

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
                        if done {
                            Text("·").foregroundStyle(AppColors.ink3)
                            if let hosp = hospital, !hosp.isEmpty {
                                // 병원명 탭 → Apple 지도 검색
                                Button { onTapHospital(hosp) } label: {
                                    HStack(spacing: 2) {
                                        Text(hosp)
                                        Image(systemName: "map")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                    .foregroundStyle(AppColors.primary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("접종 병원 \(hosp), 지도에서 보기")
                                // 병원명 수정
                                Button(action: onEditHospital) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(AppColors.ink3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("접종 병원 수정")
                            } else {
                                // 병원 미기록 → 추가 유도
                                Button(action: onEditHospital) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "plus.circle")
                                            .font(.system(size: 9, weight: .semibold))
                                        Text("병원 기록")
                                    }
                                    .foregroundStyle(AppColors.ink3)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("접종 병원 기록하기")
                            }
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
        // 병원/지도/수정/토글이 각각 독립 동작이므로 children을 합치지 않고 개별 접근 유지
        .accessibilityElement(children: .contain)
    }
}
