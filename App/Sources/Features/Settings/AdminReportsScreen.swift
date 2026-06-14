// AdminReportsScreen.swift
// BabyLog · 운영자 전용 — 신고 목록 + 콘텐츠 관리(모임/크루/매물/게시글 삭제).
// 설정에서 버전 10회 탭 + 비밀번호로 진입. 조회·삭제는 service_role Edge(admin-reports / admin-action)로만.
// 비로그인으로 만들어 신원이 바뀌어 본인도 못 지우는 모임/크루를 운영자가 정리할 수 있다.

import SwiftUI

struct AdminReportsScreen: View {
    let pass: String
    @Environment(\.dismiss) private var dismiss

    private enum Tab: String, CaseIterable { case reports = "신고", content = "콘텐츠" }
    @State private var tab: Tab = .reports

    // 신고
    @State private var reports: [AdminReport] = []
    @State private var loadingReports = true
    @State private var reportsFailed = false

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

    private struct PendingDelete: Identifiable {
        let id = UUID()
        let kind: String      // crew_meetup / crew_group / market_item / crew_post
        let rowId: String
        let label: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.s4).padding(.vertical, Spacing.s2)

                switch tab {
                case .reports: reportsView
                case .content: contentView
                }
            }
            .navigationTitle("운영자")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("새로고침") { Task { tab == .reports ? await loadReports() : await loadContent() } }
                }
            }
            .confirmationDialog("정말 삭제할까요?", isPresented: Binding(
                get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }
            ), titleVisibility: .visible, presenting: pendingDelete) { target in
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
                        Text(note).font(.system(size: 12)).foregroundStyle(AppColors.ink3)
                    }
                    if let cid = r.context_id, !cid.isEmpty {
                        Text("위치 id: \(cid)").font(.system(size: 10)).foregroundStyle(AppColors.ink3)
                    }
                }
                .padding(.vertical, 3)
            }
            .listStyle(.plain)
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
        }
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

    // MARK: - 삭제

    private func performDelete(_ target: PendingDelete) {
        deleting.insert(target.rowId)
        Task { @MainActor in
            let ok = await ReportBackend.adminDelete(pass: pass, kind: target.kind, id: target.rowId)
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
        if let r = await ReportBackend.adminFetch(pass: pass) { reports = r } else { reportsFailed = true }
        loadingReports = false
    }

    private func loadContent() async {
        loadingContent = true; contentFailed = false
        if let c = await ReportBackend.adminListContent(pass: pass) {
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
