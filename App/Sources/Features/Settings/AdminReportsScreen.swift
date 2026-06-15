// AdminReportsScreen.swift
// BabyLog · 운영자 전용 — 신고 목록(상세·증거·대상 이동) + 콘텐츠 관리(모임/크루/매물/게시글 삭제).
// 설정에서 버전 10회 탭 + 비밀번호로 진입. 조회·삭제는 service_role Edge(admin-reports / admin-action)로만.

import SwiftUI

struct AdminReportsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    private enum Tab: String, CaseIterable { case stats = "통계", reports = "신고", content = "콘텐츠", dev = "개발" }
    @State private var tab: Tab = .stats

    /// 운영자 모드 — 켜면 앱에 운영자 전용 도구(크루 오픈전/오픈후 미리보기 등)가 보이고,
    /// 끄면 일반 사용자와 동일한 화면이 된다. (자격은 서버 ADMIN_UIDS가 별도로 강제.)
    @AppStorage("bl_admin_mode") private var adminMode = false

    // 통계
    @State private var stats: AdminStats?
    @State private var loadingStats = true
    @State private var statsYear: Int = Calendar.current.component(.year, from: Date())

    // 신고
    @State private var reports: [AdminReport] = []
    @State private var loadingReports = true
    @State private var reportsFailed = false
    @State private var selectedReport: AdminReport?

    // 콘텐츠
    @State private var meetups: [AdminContentRow] = []
    @State private var groups: [AdminContentRow] = []
    @State private var items: [AdminContentRow] = []
    @State private var posts: [AdminContentRow] = []
    @State private var loadingContent = true
    @State private var contentFailed = false
    @State private var deleting: Set<String> = []
    @State private var pendingDelete: PendingDelete?
    @State private var deleteFailed = false
    @State private var scrollTarget: String?     // 신고 → '대상 보기'로 이동·강조할 콘텐츠 id

    private struct PendingDelete: Identifiable {
        let id = UUID()
        let kind: String      // crew_meetup / crew_group / market_item / crew_post
        let rowId: String
        let label: String
    }

    /// surface → 삭제 가능한 콘텐츠 종류(없으면 이동·삭제 비활성).
    private func deletableKind(_ surface: String?) -> String? {
        switch surface {
        case "market_item": return "market_item"
        case "crew_meetup": return "crew_meetup"
        case "crew_group":  return "crew_group"
        case "crew_post":   return "crew_post"
        default:            return nil
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)

                // 콘텐츠 영역이 항상 남은 높이를 채우게 해서 세그먼트가 위에 고정되도록(빈 상태 중앙 정렬).
                Group {
                    switch tab {
                    case .stats:   statsView
                    case .reports: reportsView
                    case .content: contentView
                    case .dev:     devView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task(id: tab == .stats ? statsYear : -1) { if tab == .stats { await loadStats() } }
            }
            .navigationTitle("운영자")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("새로고침") { Task {
                        switch tab {
                        case .stats: await loadStats()
                        case .reports: await loadReports()
                        default: await loadContent()
                        }
                    } }
                }
            }
            .sheet(item: $selectedReport) { rep in
                reportDetailSheet(rep)
                    .presentationDetents([.large])
            }
            .alert("정말 삭제할까요?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete) { target in
                Button("삭제", role: .destructive) { performDelete(target) }
                Button("취소", role: .cancel) {}
            } message: { target in
                Text("‘\(target.label)’ 을(를) 삭제합니다. 되돌릴 수 없어요. (관련 채팅·참여자도 함께 삭제됩니다)")
            }
            .alert("삭제하지 못했어요", isPresented: $deleteFailed) {
                Button("확인", role: .cancel) {}
            } message: { Text("네트워크 또는 권한 문제예요. 잠시 후 다시 시도해 주세요.") }
        }
        .task { await loadReports(); await loadContent() }
    }

    // MARK: - 통계 탭

    private func loadStats() async {
        loadingStats = true
        stats = await ReportBackend.adminStats(year: statsYear)
        loadingStats = false
    }

    @ViewBuilder private var statsView: some View {
        if loadingStats && stats == nil {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let s = stats {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    // 활성 인원(A) + 역대(B)
                    Text("활성 접속 인원").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink3)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s3) {
                        statCard("오늘", s.today)
                        statCard("최근 7일", s.week)
                        statCard("최근 30일", s.month)
                        statCard("\(statsYear)년", s.year, accessory: AnyView(yearMenu))
                    }
                    statCard("역대 누적(설치)", s.allTime)

                    Divider().padding(.vertical, 2)

                    Text("신규 · 재방문 (오늘)").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink3)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s3) {
                        statCard("신규", s.newToday)
                        statCard("재방문", s.returningToday)
                    }

                    Text("리텐션 (재방문율)").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink3)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.s3) {
                        statCard("1일+", s.retD1, suffix: "%")
                        statCard("7일+", s.retD7, suffix: "%")
                        statCard("30일+", s.retD30, suffix: "%")
                    }

                    if !s.versions.isEmpty {
                        Text("앱 버전 (최근 30일)").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink3)
                        VStack(spacing: 0) {
                            ForEach(Array(s.versions.enumerated()), id: \.element.id) { idx, ver in
                                if idx > 0 { Divider() }
                                HStack {
                                    Text(ver.v).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink)
                                    Spacer()
                                    Text("\(ver.n)명").font(AppFont.num(14)).foregroundStyle(AppColors.ink2)
                                }
                                .padding(.vertical, Spacing.s2)
                            }
                        }
                        .padding(.horizontal, Spacing.s3)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }

                    Text("운영자 본인은 집계에서 제외돼요. 기기당 하루 1회, KST 기준. 개인·아동 정보 없는 익명 집계.")
                        .font(.system(size: 11)).foregroundStyle(AppColors.ink3)
                        .padding(.top, Spacing.s1)
                }
                .padding(Spacing.s4)
            }
        } else {
            BLEmptyState(icon: "chart.bar", title: "불러오지 못했어요", message: "운영자 권한 또는 네트워크를 확인하세요.")
        }
    }

    private var yearMenu: some View {
        // 최근 5년 + 데이터가 있는 연도를 항상 제공(데이터 없는 해도 선택해 0 확인 가능).
        let cur = Calendar.current.component(.year, from: Date())
        let yrs = Array(Set(Array((cur - 4)...cur)).union(stats?.years ?? [])).sorted(by: >)
        return Menu {
            ForEach(yrs, id: \.self) { y in
                Button {
                    statsYear = y
                } label: {
                    if y == statsYear { Label("\(y)년", systemImage: "checkmark") } else { Text("\(y)년") }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text("\(statsYear)").font(AppFont.num(13, weight: .bold)).foregroundStyle(AppColors.primary)
                Image(systemName: "chevron.down.circle.fill")
                    .font(.system(size: 16)).foregroundStyle(AppColors.primary)
            }
        }
        .accessibilityLabel("연도 선택, 현재 \(statsYear)년")
    }

    private func statCard(_ label: String, _ value: Int, suffix: String = "", accessory: AnyView? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.ink3)
                Spacer(minLength: 4)
                if let accessory { accessory }
            }
            Text("\(value)\(suffix)").font(AppFont.num(26, weight: .heavy)).foregroundStyle(AppColors.ink)
        }
        .padding(Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
    }

    // MARK: - 신고 탭

    @ViewBuilder private var reportsView: some View {
        if loadingReports {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if reportsFailed {
            BLEmptyState(icon: "lock.slash", title: "불러오지 못했어요", message: "비밀번호 또는 네트워크를 확인하세요.")
        } else if reports.isEmpty {
            BLEmptyState(icon: "checkmark.shield", title: "접수된 신고가 없어요", message: "새 신고가 들어오면 여기 표시됩니다.")
        } else {
            List(reports) { r in
                Button { selectedReport = r } label: { reportRow(r) }
                    .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func reportRow(_ r: AdminReport) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(surfaceLabel(r.surface))
                        .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(AppColors.primary, in: Capsule())
                    Text(r.reason ?? "신고").font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.danger)
                    Spacer()
                    Text(shortDate(r.created_at)).font(.system(size: 11)).foregroundStyle(AppColors.ink3)
                }
                Text("대상: \(r.reported_name ?? "-")  ·  신고자: \(String((r.reporter ?? "-").prefix(8)))")
                    .font(.system(size: 12)).foregroundStyle(AppColors.ink2)
                if let note = r.note, !note.isEmpty {
                    Text(note).font(.system(size: 12)).foregroundStyle(AppColors.ink3).lineLimit(1)
                }
                if let t = r.transcript, !t.isEmpty {
                    Label("대화 증거 \(t.count)건", systemImage: "text.bubble")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(AppColors.ink3)
                }
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.ink3)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    // MARK: - 신고 상세 시트

    private func reportDetailSheet(_ r: AdminReport) -> some View {
        let kind = deletableKind(r.surface)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    // 요약
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        HStack(spacing: 6) {
                            Text(surfaceLabel(r.surface))
                                .font(.system(size: 12, weight: .heavy)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(AppColors.primary, in: Capsule())
                            Text(shortDate(r.created_at)).font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                        }
                        Text(r.reason ?? "신고")
                            .font(.system(size: 20, weight: .heavy)).foregroundStyle(AppColors.danger)
                    }

                    detailField("신고 대상", r.reported_name ?? "-")
                    if let rid = r.reported, !rid.isEmpty { detailField("대상 식별자", rid) }
                    detailField("신고자", r.reporter ?? "-")
                    if let cid = r.context_id, !cid.isEmpty { detailField("콘텐츠 id", cid) }
                    if let note = r.note, !note.isEmpty { detailField("메모", note) }

                    // 신고 시점 저장본(스냅샷) — 원본 삭제와 무관하게 보존되는 증거. 항상 표시.
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("신고 시점 저장본").font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink2)
                        Text("원본(채팅·글)이 삭제돼도 이 스냅샷은 남아요. 삭제 전 내용은 여기서 확인하세요.")
                            .font(.system(size: 11)).foregroundStyle(AppColors.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                        if let t = r.transcript, !t.isEmpty {
                            VStack(alignment: .leading, spacing: Spacing.s2) {
                                ForEach(t) { line in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.speaker).font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                                        Text(line.text ?? "").font(.system(size: 13)).foregroundStyle(AppColors.ink)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.s2)
                                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        } else {
                            Text("저장된 대화 스냅샷이 없는 신고예요(콘텐츠 자체 신고 등).")
                                .font(.system(size: 13)).foregroundStyle(AppColors.ink3)
                                .padding(Spacing.s2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }

                    // 조치
                    if let kind, let cid = r.context_id, !cid.isEmpty {
                        VStack(spacing: Spacing.s2) {
                            Button {
                                selectedReport = nil
                                tab = .content
                                scrollTarget = cid
                            } label: {
                                Label("원본 콘텐츠 열기 (삭제됐을 수 있어요)", systemImage: "arrow.right.circle.fill")
                                    .font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).frame(height: 48)
                                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                    .foregroundStyle(.white)
                            }
                            Button {
                                let label = r.reported_name ?? r.reason ?? "콘텐츠"
                                selectedReport = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    pendingDelete = PendingDelete(kind: kind, rowId: cid, label: label)
                                }
                            } label: {
                                Label("신고 대상 콘텐츠 삭제", systemImage: "trash.fill")
                                    .font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).frame(height: 48)
                                    .background(AppColors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                    .foregroundStyle(AppColors.danger)
                            }
                        }
                        .padding(.top, Spacing.s2)
                    } else {
                        Text("이 신고는 이동/삭제할 콘텐츠 위치 정보가 없어요.")
                            .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                    }
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("신고 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("닫기") { selectedReport = nil } } }
        }
    }

    private func detailField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(AppColors.ink3)
            Text(value).font(.system(size: 14)).foregroundStyle(AppColors.ink)
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 콘텐츠 탭

    @ViewBuilder private var contentView: some View {
        if loadingContent {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if contentFailed {
            BLEmptyState(icon: "lock.slash", title: "불러오지 못했어요", message: "비밀번호 또는 네트워크를 확인하세요.")
        } else if meetups.isEmpty && groups.isEmpty && items.isEmpty && posts.isEmpty {
            BLEmptyState(icon: "tray", title: "콘텐츠가 없어요", message: "등록된 모임·크루·매물이 없습니다.")
        } else {
          VStack(spacing: 0) {
            // 이동했는데 원본이 삭제/미수록이면 안내 — 저장본으로 유도(빈 화면 혼란 방지).
            if let t = scrollTarget, !contentContains(t) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.danger)
                    Text("이미 삭제됐거나 최근 목록에 없는 콘텐츠예요. 신고 상세의 ‘신고 시점 저장본’으로 확인하세요.")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.dangerTint)
            }
            ScrollViewReader { proxy in
                List {
                    contentSection(title: "모임 (같이가요)", kind: "crew_meetup", rows: meetups) { r in
                        contentRow(primary: r.title ?? "(제목 없음)",
                                   sub: [r.host_name, r.hood, r.when_text].compactMap { $0 }.joined(separator: " · "),
                                   date: r.created_at)
                    }
                    contentSection(title: "크루 (그룹)", kind: "crew_group", rows: groups) { r in
                        contentRow(primary: r.name ?? "(이름 없음)",
                                   sub: [r.creator_name, r.hood].compactMap { $0 }.joined(separator: " · "),
                                   date: r.created_at)
                    }
                    contentSection(title: "매물", kind: "market_item", rows: items) { r in
                        contentRow(primary: r.title ?? "(제목 없음)",
                                   sub: [r.seller_name, r.status, r.hood].compactMap { $0 }.joined(separator: " · "),
                                   date: r.created_at)
                    }
                    contentSection(title: "크루 게시글", kind: "crew_post", rows: posts) { r in
                        contentRow(primary: r.title ?? "(제목 없음)",
                                   sub: [r.author_name, r.category, r.hood].compactMap { $0 }.joined(separator: " · "),
                                   date: r.created_at)
                    }
                }
                .listStyle(.insetGrouped)
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        withAnimation { proxy.scrollTo(target, anchor: .center) }
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if scrollTarget == target { scrollTarget = nil }
                    }
                }
            }
          }
        }
    }

    private func contentContains(_ id: String) -> Bool {
        meetups.contains { $0.id == id } || groups.contains { $0.id == id }
            || items.contains { $0.id == id } || posts.contains { $0.id == id }
    }

    @ViewBuilder
    private func contentSection(title: String, kind: String, rows: [AdminContentRow],
                                @ViewBuilder content: @escaping (AdminContentRow) -> some View) -> some View {
        if !rows.isEmpty {
            Section("\(title) \(rows.count)") {
                ForEach(rows) { r in
                    HStack {
                        content(r)
                        Spacer(minLength: Spacing.s2)
                        if deleting.contains(r.id) {
                            ProgressView()
                        } else {
                            Button(role: .destructive) {
                                pendingDelete = PendingDelete(kind: kind, rowId: r.id,
                                                              label: r.title ?? r.name ?? "항목")
                            } label: {
                                Image(systemName: "trash").foregroundStyle(AppColors.danger)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .id(r.id)
                    .listRowBackground(scrollTarget == r.id ? AppColors.primaryTint : nil)
                }
            }
        }
    }

    private func contentRow(primary: String, sub: String, date: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(primary).font(.system(size: 14, weight: .bold)).foregroundStyle(AppColors.ink)
            HStack(spacing: 6) {
                if !sub.isEmpty { Text(sub).font(.system(size: 11)).foregroundStyle(AppColors.ink2) }
                Spacer(minLength: 0)
                Text(shortDate(date)).font(.system(size: 10)).foregroundStyle(AppColors.ink3)
            }
        }
    }

    // MARK: - 개발 탭 (운영자 전용 도구)

    @ViewBuilder private var devView: some View {
        List {
            Section("운영자 모드") {
                Toggle(isOn: $adminMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("운영자 모드 켜기").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("켜면 앱에 운영자 전용 도구가 표시돼요(예: 크루 오픈전/오픈후 미리보기). 끄면 일반 사용자와 똑같은 화면이 됩니다.")
                            .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                    }
                }
                .tint(AppColors.primary)
            }
            Section("개발 / 검증") {
                Toggle(isOn: $store.devProOverride) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pro 모드(로컬)").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(AppColors.ink)
                        Text("클라 UI만 Pro로 전환(로컬 검증용). 실제 구독(StoreKit)이 있으면 그것이 우선이며, 서버 등급은 구독으로만 부여 — 이 토글은 서버에 반영되지 않음.")
                            .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                    }
                }
                .tint(AppColors.primary)
                // (제거됨) 서버 is_pro 동기화 — bl_dev_set_pro 백도어 제거(출시 보안). 로컬 토글은 클라 게이트 검증 전용.
            }
            Section("내 운영자 ID (서버 ADMIN_UIDS에 등록)") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AuthStore.shared.userId ?? "로그인 필요")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppColors.ink)
                        .textSelection(.enabled)
                    Text("이 값을 서버 ADMIN_UIDS 시크릿에 넣으면 이 계정만 운영자 조회·삭제가 가능해요. 길게 눌러 복사.")
                        .font(.system(size: 11)).foregroundStyle(AppColors.ink3)
                }
            }
            Section {
                Text("운영자 전용 도구입니다. 권한은 서버(JWT uid 화이트리스트)가 최종 강제합니다.")
                    .font(.system(size: 12)).foregroundStyle(AppColors.ink3)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 삭제

    private func performDelete(_ target: PendingDelete) {
        deleting.insert(target.rowId)
        Task { @MainActor in
            let ok = await ReportBackend.adminDelete(kind: target.kind, id: target.rowId)
            deleting.remove(target.rowId)
            if ok {
                meetups.removeAll { $0.id == target.rowId }
                groups.removeAll { $0.id == target.rowId }
                items.removeAll { $0.id == target.rowId }
                posts.removeAll { $0.id == target.rowId }
            } else {
                deleteFailed = true
            }
        }
    }

    // MARK: - 로드

    private func loadReports() async {
        loadingReports = true; reportsFailed = false
        if let r = await ReportBackend.adminFetch() { reports = r } else { reportsFailed = true }
        loadingReports = false
    }

    private func loadContent() async {
        loadingContent = true; contentFailed = false
        if let c = await ReportBackend.adminListContent() {
            meetups = c.meetups; groups = c.groups; items = c.items; posts = c.posts
        } else { contentFailed = true }
        loadingContent = false
    }

    // MARK: - 헬퍼

    private func surfaceLabel(_ s: String?) -> String {
        switch s {
        case "market_chat":  return "마켓 채팅"
        case "market_item":  return "마켓 매물"
        case "crew_meetup":  return "크루 모임"
        case "crew_group":   return "크루 그룹"
        case "crew_post":    return "크루 게시글"
        default:             return s ?? "신고"
        }
    }
    private func shortDate(_ s: String?) -> String {
        guard let s else { return "" }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        guard let d else { return String(s.prefix(16)) }
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "M/d HH:mm"
        return f.string(from: d)
    }
}
