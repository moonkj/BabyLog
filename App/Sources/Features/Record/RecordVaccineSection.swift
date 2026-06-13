// Features/Record/RecordVaccineSection.swift
// BabyLog · 성장 기록 탭 — 예방접종 섹션
// (RecordScreen에서 분리된 순수 구조 분해; 동작·카피 변경 없음)

import SwiftUI

// MARK: - 예방접종 섹션

struct VaccineSection: View {
    @EnvironmentObject private var store: AppStore

    @State private var vaccines: [VaccineRecord] = []
    @State private var isLoading = true   // 첫 렌더에 빈상태(실패) 깜빡임 방지 — 로드 완료까지 스켈레톤
    /// 펼쳐진 백신 그룹 키(접힘 기본). 펼치면 회차별 개별 행 노출.
    @State private var expandedGroups: Set<String> = []
    /// 완료(모든 회차 접종) 그룹 묶음 펼침 여부.
    @State private var showCompletedGroups = false

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
        case "HepB-3": return "B형간염 3차"
        case "DTaP-1": return "DTaP 1차"
        case "DTaP-2": return "DTaP 2차"
        case "DTaP-3": return "DTaP 3차"
        case "DTaP-4": return "DTaP 4차"
        case "IPV-1":  return "폴리오(IPV) 1차"
        case "IPV-2":  return "폴리오(IPV) 2차"
        case "IPV-3":  return "폴리오(IPV) 3차"
        case "Hib-1":  return "Hib 1차"
        case "Hib-2":  return "Hib 2차"
        case "Hib-3":  return "Hib 3차"
        case "Hib-4":  return "Hib 4차"
        case "PCV-1":  return "폐렴구균(PCV) 1차"
        case "PCV-2":  return "폐렴구균(PCV) 2차"
        case "PCV-3":  return "폐렴구균(PCV) 3차"
        case "PCV-4":  return "폐렴구균(PCV) 4차"
        case "RV-1":   return "로타바이러스 1차"
        case "RV-2":   return "로타바이러스 2차"
        case "MMR-1":  return "MMR 1차"
        case "Varicella": return "수두"
        case "HepA-1": return "A형간염 1차"
        case "JEV-1":  return "일본뇌염 1차"
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
            // 표준 일정은 폴백으로 거의 항상 채워지나, 만일 비면 빈 상태 대신 '재시도' 표준 패턴.
            BLErrorState(
                message: "접종 일정을 불러오지 못했어요.\n네트워크 상태를 확인하고 다시 시도해 주세요.",
                retry: { Task { await loadVaccines(birthDate: child.birthDate) } }
            )
        } else {
            let groups = makeGroups(vaccines)
            let ongoing = groups.filter { !isGroupDone($0) }
            let completed = groups.filter { isGroupDone($0) }
            VStack(alignment: .leading, spacing: Spacing.s4) {
                // 다음 접종 — 어떤 접힘 상태에서도 항상 최상단 노출(후속 접종 누락 방지)
                if let next = nextUpcoming {
                    upcomingBanner(for: next, birthDate: child.birthDate)
                }

                // 진행 요약 — 분모에 '0~18개월 표준' 범위를 명시(평생 일정으로 오인 방지)
                progressSummary

                // 진행 중인 접종 그룹(미완 회차가 남은 것)
                if !ongoing.isEmpty {
                    BLSectionHead(title: "진행 중인 접종")
                        .accessibilityAddTraits(.isHeader)
                    BLCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(ongoing.enumerated()), id: \.element.id) { idx, g in
                                if idx > 0 { Divider().background(AppColors.line).padding(.leading, 64) }
                                vaccineGroupRow(g, child: child)
                            }
                        }
                    }
                }

                // 완료한 접종 — 접기 기본(사용자가 '늘어놓을 필요 없다'던 항목)
                if !completed.isEmpty {
                    Button {
                        Haptics.light()
                        withAnimation(.easeInOut(duration: 0.2)) { showCompletedGroups.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.primary)
                            Text("완료한 접종 \(completed.count)종")
                                .font(.system(size: 13.5, weight: .bold)).foregroundStyle(AppColors.ink2)
                            Image(systemName: showCompletedGroups ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(LiquidPressStyle(scale: 0.98))
                    .accessibilityLabel(showCompletedGroups ? "완료한 접종 \(completed.count)종 접기" : "완료한 접종 \(completed.count)종 펼치기")

                    if showCompletedGroups {
                        BLCard(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(Array(completed.enumerated()), id: \.element.id) { idx, g in
                                    if idx > 0 { Divider().background(AppColors.line).padding(.leading, 64) }
                                    vaccineGroupRow(g, child: child)
                                }
                            }
                        }
                    }
                }

                // 의료 면책 + 범위 고지(상시 노출) — 0~18개월 외 접종이 '없는' 게 아니라 '범위 밖'임을 정직하게.
                Text("⚠️ 질병관리청 표준 **0~18개월** 일정 참고용이에요. 만 4~6세 추가접종·매년 독감은 포함되지 않으니 담당 소아과 선생님과 확인하세요.")
                    .font(AppFont.caption)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.s2)
                    .accessibilityLabel("안내: 질병관리청 표준 0~18개월 일정 참고용이며, 만 4~6세 추가접종과 매년 독감은 포함되지 않습니다. 실제 접종은 소아과 의사와 확인하세요.")
            }
        }
    }

    // MARK: - 백신 그룹(종류별) 구성

    /// 백신 그룹 — 같은 종류(DTaP 등)의 회차들을 묶는다.
    private struct VaccineGroup: Identifiable {
        let id: String          // 그룹 키(접두, 예: "DTaP")
        let name: String        // 표시명
        let doses: [VaccineRecord]   // 회차(접종일순)
    }

    /// vaccineId 접두("DTaP-1"→"DTaP")로 그룹 키 도출.
    private func groupKey(_ vaccineId: String) -> String {
        vaccineId.split(separator: "-").first.map(String.init) ?? vaccineId
    }

    private func groupName(_ key: String) -> String {
        switch key {
        case "BCG":       return "BCG (결핵)"
        case "HepB":      return "B형간염"
        case "DTaP":      return "DTaP"
        case "IPV":       return "폴리오(IPV)"
        case "Hib":       return "Hib"
        case "PCV":       return "폐렴구균(PCV)"
        case "RV":        return "로타바이러스"
        case "MMR":       return "MMR"
        case "Varicella": return "수두"
        case "HepA":      return "A형간염"
        case "JEV":       return "일본뇌염"
        default:          return key
        }
    }

    private func makeGroups(_ records: [VaccineRecord]) -> [VaccineGroup] {
        var map: [String: [VaccineRecord]] = [:]
        for r in records { map[groupKey(r.vaccineId), default: []].append(r) }
        return map.map { key, doses in
            VaccineGroup(id: key, name: groupName(key),
                         doses: doses.sorted { ($0.scheduledDate ?? .distantPast) < ($1.scheduledDate ?? .distantPast) })
        }
        // 가장 이른 회차 순으로 그룹 정렬(0개월대 → 12개월대)
        .sorted { ($0.doses.first?.scheduledDate ?? .distantFuture) < ($1.doses.first?.scheduledDate ?? .distantFuture) }
    }

    private func isGroupDone(_ g: VaccineGroup) -> Bool {
        g.doses.allSatisfy { isDone($0) }
    }

    /// 그룹의 월령 요약(예: "생후 2·4·6·15개월" / 단회는 "생후 2개월").
    private func groupAgeSummary(_ g: VaccineGroup, birthDate: Date) -> String {
        let months = g.doses.compactMap { r -> Int? in
            guard let d = r.scheduledDate else { return nil }
            return AgeCalculator.childAgeMonths(birthDate: birthDate, asOf: d).months
        }
        if months.isEmpty { return "" }
        if months.count == 1 { return months[0] == 0 ? "출생 시" : "생후 \(months[0])개월" }
        return "생후 " + months.map(String.init).joined(separator: "·") + "개월"
    }

    // MARK: - 그룹 행 (접힘=회차 도트 요약 / 펼침=회차별 개별 행)

    @ViewBuilder
    private func vaccineGroupRow(_ g: VaccineGroup, child: Child) -> some View {
        if g.doses.count == 1, let v = g.doses.first {
            singleDoseRow(v, name: g.name, child: child)   // 1회 접종 — 펼치지 않고 행에서 바로 체크
        } else {
            multiDoseGroupRow(g, child: child)             // 다회(1·2·3차) — 펼쳐 회차별 체크
        }
    }

    /// 접종 완료 토글 + 신규 완료 시 병원 입력 유도(회차/단일 공용).
    private func toggleDose(_ v: VaccineRecord, child: Child) {
        let wasDone = isDone(v)
        Haptics.light()
        withAnimation(.easeOut(duration: 0.18)) {
            store.toggleVaccine(childId: child.id, vaccineId: v.vaccineId)
        }
        if !wasDone, store.vaccineHospital(childId: child.id, vaccineId: v.vaccineId) == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                presentHospitalPrompt(vaccineId: v.vaccineId, name: displayName(for: v.vaccineId))
            }
        }
    }

    /// 1회 접종 그룹 — 행 전체를 탭하면 바로 완료 토글(펼침 불필요).
    @ViewBuilder
    private func singleDoseRow(_ v: VaccineRecord, name: String, child: Child) -> some View {
        let done = isDone(v)
        Button { toggleDose(v, child: child) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(done ? AppColors.primarySoft : AppColors.surface3)
                        .frame(width: 40, height: 40)
                    Image(systemName: done ? "checkmark.circle.fill" : "syringe")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(done ? AppColors.primary : AppColors.ink3)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.ink)
                    Text(ageLabel(for: v, birthDate: child.birthDate))
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }

                Spacer(minLength: 0)

                // 상태 배지
                if done {
                    BLBadge(tone: .mint, text: "완료", systemIcon: "checkmark").fixedSize()
                } else if let d = dDayLabel(for: v) {
                    BLBadge(tone: d == "D-Day" ? .coral : .amber, text: d, systemIcon: "calendar").fixedSize()
                } else {
                    BLBadge(tone: .grey, text: "예정", systemIcon: "clock").fixedSize()
                }

                // 체크 인디케이터(행 전체가 토글)
                ZStack {
                    Circle().strokeBorder(done ? AppColors.primary : AppColors.line2, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    CheckDrawView(isOn: done, size: 14, color: AppColors.primary)
                }
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiquidPressStyle(scale: 0.99))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(ageLabel(for: v, birthDate: child.birthDate)), \(done ? "접종 완료" : "미접종")")
        .accessibilityHint(done ? "두 번 탭하면 완료 취소" : "두 번 탭하면 접종 완료로 표시")
        .accessibilityAddTraits(done ? [.isButton, .isSelected] : .isButton)
    }

    /// 다회 접종 그룹 — 요약 행(회차 도트) + 탭하면 회차별 펼침.
    @ViewBuilder
    private func multiDoseGroupRow(_ g: VaccineGroup, child: Child) -> some View {
        let doneCount = g.doses.filter { isDone($0) }.count
        let total = g.doses.count
        let expanded = expandedGroups.contains(g.id)
        let groupDone = doneCount == total

        VStack(spacing: 0) {
            // 요약 행 (탭하면 회차 펼침)
            Button {
                Haptics.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    if expanded { expandedGroups.remove(g.id) } else { expandedGroups.insert(g.id) }
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .fill(groupDone ? AppColors.primarySoft : AppColors.surface3)
                            .frame(width: 40, height: 40)
                        Image(systemName: groupDone ? "checkmark.circle.fill" : "syringe")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(groupDone ? AppColors.primary : AppColors.ink3)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(g.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AppColors.ink)
                        Text(groupAgeSummary(g, birthDate: child.birthDate))
                            .font(AppFont.caption)
                            .foregroundStyle(AppColors.ink3)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    // 회차 진행 — 색+모양(채움/외곽)+레이블 3중 인코딩
                    if total > 1 {
                        doseDots(g)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.ink3)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(LiquidPressStyle(scale: 0.99))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(g.name), \(total)회 중 \(doneCount)회 완료\(groupDone ? "" : ", 미완 회차 있음")")
            .accessibilityHint(expanded ? "접어서 요약 보기" : "펼쳐서 회차별 보기")
            .accessibilityAddTraits(.isButton)

            // 펼침 — 회차별 개별 행(기존 VaccineRow 재사용: 체크·병원 기록)
            if expanded {
                Divider().background(AppColors.line).padding(.leading, 64)
                ForEach(Array(g.doses.enumerated()), id: \.element.id) { idx, v in
                    if idx > 0 { Divider().background(AppColors.line).padding(.leading, 64) }
                    doseRow(v, child: child)
                }
            }
        }
    }

    /// 회차 진행 도트(채움=완료, 외곽=미완, 금색 링=다음 차례) + "N/M" 텍스트.
    @ViewBuilder
    private func doseDots(_ g: VaccineGroup) -> some View {
        let nextId = g.doses.first(where: { !isDone($0) })?.id
        HStack(spacing: 4) {
            ForEach(g.doses) { v in
                let done = isDone(v)
                Circle()
                    .strokeBorder(done ? Color.clear : (v.id == nextId ? AppColors.gold : AppColors.line2),
                                  lineWidth: 1.5)
                    .background(Circle().fill(done ? AppColors.primary : Color.clear))
                    .frame(width: 8, height: 8)
            }
            Text("\(g.doses.filter { isDone($0) }.count)/\(g.doses.count)")
                .font(AppFont.num(11.5, weight: .bold))
                .foregroundStyle(AppColors.ink3)
        }
        .accessibilityHidden(true)   // 그룹 행 레이블이 "N회 중 M회"로 대체 안내
    }

    /// 개별 회차 행 — 기존 VaccineRow + 토글/병원 기록 로직.
    @ViewBuilder
    private func doseRow(_ v: VaccineRecord, child: Child) -> some View {
        let name = displayName(for: v.vaccineId)
        VaccineRow(
            vaccineId: v.vaccineId,
            displayName: name,
            ageLabel: ageLabel(for: v, birthDate: child.birthDate),
            hospital: store.vaccineHospital(childId: child.id, vaccineId: v.vaccineId),
            done: isDone(v),
            dDay: dDayLabel(for: v),
            onToggle: { toggleDose(v, child: child) },
            onTapHospital: { openInMaps($0) },
            onEditHospital: { presentHospitalPrompt(vaccineId: v.vaccineId, name: name) }
        )
    }

    /// 진행 요약 — '0~18개월 표준 N건 중 M건 기록' + 비율 바(색+레이블).
    private var progressSummary: some View {
        let total = vaccines.count
        let done = vaccines.filter { isDone($0) }.count
        let ratio = total > 0 ? Double(done) / Double(total) : 0
        return BLCard(padding: Spacing.s4, flat: true) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("0~18개월 표준 일정")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink2)
                    Spacer()
                    Text("\(done) / \(total) 기록")
                        .font(AppFont.num(13, weight: .heavy)).foregroundStyle(AppColors.primary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.surface3).frame(height: 6)
                        Capsule().fill(AppColors.primary)
                            .frame(width: max(6, geo.size.width * ratio), height: 6)
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("0~18개월 표준 일정 \(total)건 중 \(done)건 기록")
    }

    private var vaccineSkeletonView: some View {
        VStack(spacing: Spacing.s3) {
            // 배너 스켈레톤
            BLCard(padding: Spacing.s4) {
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

        BLCard(padding: Spacing.s4) {
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
                    Text("질병관리청 표준 스케줄 기준")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                }
                Spacer()
                Text(dLabel)
                    .font(AppFont.num(20, weight: .heavy))
                    .foregroundStyle(AppColors.gold)
                    .accessibilityLabel("\(dNum)일 후")
            }
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppColors.gold)
                .frame(width: 4)
                .padding(.vertical, 12)
                .accessibilityHidden(true)
        }
        .background(AppColors.goldTint, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) 접종 \(dNum)일 후 예정. 질병관리청 표준 스케줄 기준.")
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
        BLCard(padding: Spacing.s4, flat: true) {
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
