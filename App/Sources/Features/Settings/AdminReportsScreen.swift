// AdminReportsScreen.swift
// BabyLog · 운영자 전용 — 접수된 신고 목록(채팅/사용자/매물/게시글).
// 설정에서 버전 10회 탭 + 비밀번호로 진입. 조회는 admin-reports Edge(service_role)로만.

import SwiftUI

struct AdminReportsScreen: View {
    let pass: String
    @Environment(\.dismiss) private var dismiss
    @State private var reports: [AdminReport] = []
    @State private var loading = true
    @State private var failed = false

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

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if failed {
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
            .navigationTitle("운영자 · 신고 \(reports.isEmpty ? "" : "\(reports.count)")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("닫기") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button("새로고침") { Task { await load() } } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true; failed = false
        if let r = await ReportBackend.adminFetch(pass: pass) { reports = r }
        else { failed = true }
        loading = false
    }
}
