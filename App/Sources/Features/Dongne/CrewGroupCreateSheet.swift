// CrewGroupCreateSheet.swift
// BabyLog · Features/Dongne — 동네 또래 그룹 만들기 (서버 공유)

import SwiftUI

struct CrewGroupCreateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var location = NearbyLocationProvider.shared

    @State private var name = ""
    @State private var ageRange = ""
    @State private var tagsText = ""
    @State private var saving = false
    @State private var alertMessage: String?
    @State private var alreadyHasGroup = false   // 이미 만든 크루가 있으면 추가 생성 차단(1인 1개)

    private let ageSuggestions = ["0–6개월", "6–12개월", "12–24개월", "24–36개월", "전체"]
    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !saving && !alreadyHasGroup }
    private let limitMessage = "크루는 한 사람당 하나만 만들 수 있어요. 참여는 여러 곳에 할 수 있어요. 새로 만들려면 기존 크루를 먼저 삭제해 주세요."

    private var parsedTags: [String] {
        tagsText.split(whereSeparator: { $0 == "," || $0 == "#" || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    if alreadyHasGroup {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(AppColors.danger)
                            Text(limitMessage)
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(AppColors.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Spacing.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.dangerTint, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }

                    Text("같은 또래 양육자와 이어지는 우리 동네 그룹이에요. 이름만 적어도 만들 수 있어요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    field(title: "그룹 이름", placeholder: "예: 복대동 첫돌 또래 모임", text: $name)

                    // 또래 (선택)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("또래 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ageSuggestions, id: \.self) { s in
                                    Button { ageRange = (ageRange == s ? "" : s) } label: {
                                        Text(s)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(ageRange == s ? .white : AppColors.ink2)
                                            .padding(.horizontal, 14).frame(height: 40)
                                            .background(ageRange == s ? AppColors.primary : AppColors.surface2,
                                                        in: Capsule())
                                    }
                                    .buttonStyle(LiquidPressStyle(scale: 0.95))
                                }
                            }
                        }
                    }

                    // 관심사 (선택)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("관심사 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("쉼표로 구분 — 예: 이유식, 공원 산책", text: $tagsText)
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal, Spacing.s4).frame(height: 52)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        if !parsedTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(parsedTags, id: \.self) { t in
                                        Text(t)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AppColors.ink2)
                                            .padding(.horizontal, 10).padding(.vertical, 4)
                                            .background(AppColors.surface2, in: Capsule())
                                    }
                                }
                            }
                        }
                    }

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3, action: save) {
                        Text(saving ? "만드는 중…" : "그룹 만들기").frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                    .padding(.top, Spacing.s2)
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .task { alreadyHasGroup = await CrewBackend.hasCreatedGroup() }
            .navigationTitle("또래 그룹 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
            .alert("알림", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("확인", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func save() {
        // 추가 생성 시도 — 이미 만든 크루가 있으면 알림 후 중단(1인 1개).
        if alreadyHasGroup { alertMessage = limitMessage; return }
        guard canSave else { return }
        let nm = name.trimmingCharacters(in: .whitespaces)
        let age = ageRange.isEmpty ? "전체" : ageRange
        let tags = parsedTags
        let hood = store.selectedDong ?? location.localityName ?? ""
        // 위치 미확보 시 서버 생성이 실패하므로 시도하지 않고 안내.
        guard !hood.isEmpty, hood != "우리 동네" else {
            alertMessage = "위치를 확인하고 있어요. 잠시 후 다시 시도해 주세요."
            return
        }
        saving = true
        Task { @MainActor in
            let id = await CrewBackend.createGroup(
                hood: hood, name: nm, ageRange: age, interestTags: tags, creatorName: nickname)
            // 성공(비-nil id)을 확인한 뒤에만 닫는다.
            if let id {
                store.toggleJoinGroup(id)   // 개설자 가입 상태 반영
                Haptics.success()
                dismiss()
            } else {
                saving = false
                // 서버 트리거(crew_create_limit)로 막혔는지 재확인 → 정확한 안내.
                if await CrewBackend.hasCreatedGroup() {
                    alreadyHasGroup = true
                    alertMessage = limitMessage
                } else {
                    alertMessage = "그룹을 만들지 못했어요. 잠시 후 다시 시도해 주세요."
                }
            }
        }
    }

    private func field(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title).font(AppFont.subhead).foregroundStyle(AppColors.ink2)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, Spacing.s4).frame(height: 52)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}
