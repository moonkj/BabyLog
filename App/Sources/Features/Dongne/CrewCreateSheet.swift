// CrewCreateSheet.swift
// BabyLog · Features/Dongne — 동네 모임 만들기 (로컬 백본)

import SwiftUI

struct CrewCreateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var location = NearbyLocationProvider.shared

    @State private var place = ""
    @State private var when = ""
    @State private var capacityText = "6"
    @State private var type: CrewMeetupType = .park
    @State private var desc = ""
    @State private var submitting = false
    @State private var alertMessage: String?

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var canSave: Bool { !place.trimmingCharacters(in: .whitespaces).isEmpty && !submitting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {
                    Text("이웃과 함께할 모임을 열어보세요. 장소만 적어도 만들 수 있어요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    field(title: "장소", placeholder: "예: 망원한강공원 잔디밭", text: $place)
                    field(title: "일시", placeholder: "예: 토요일 오후 3시", text: $when)

                    // 유형
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("유형").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack(spacing: Spacing.s2) {
                            ForEach(CrewMeetupType.allCases, id: \.self) { t in
                                Button { type = t } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: t.systemIcon).font(.system(size: 14, weight: .semibold))
                                        Text(t.label).font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(type == t ? .white : AppColors.ink2)
                                    .frame(maxWidth: .infinity).frame(height: 52)
                                    .background(type == t ? AppColors.ink : AppColors.surface2,
                                                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                }
                                .buttonStyle(LiquidPressStyle(scale: 0.96))
                                .accessibilityAddTraits(type == t ? .isSelected : [])
                            }
                        }
                    }

                    // 정원
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("정원").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack {
                            TextField("6", text: $capacityText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 18, weight: .bold))
                            Text("명").foregroundStyle(AppColors.ink3)
                        }
                        .padding(.horizontal, Spacing.s4).frame(height: 52)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }

                    // 설명
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("소개 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("어떤 모임인지 알려주세요", text: $desc, axis: .vertical)
                            .font(AppFont.body).lineLimit(2...4)
                            .padding(.horizontal, Spacing.s4).padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        if SupabaseConfig.isConfigured {
                            // 정직 고지: 서버 crew_meetup에 소개 컬럼이 아직 없어 이웃에게 전송되지 않음
                            Text("소개는 아직 이웃에게 공유되지 않아요")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(AppColors.ink3)
                        }
                    }

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3, action: save) {
                        Text(submitting ? "만드는 중…" : "모임 만들기").frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                    .padding(.top, Spacing.s2)
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("모임 만들기")
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
        guard canSave else { return }
        let cap = max(2, Int(capacityText.filter(\.isNumber)) ?? 6)
        let placeText = place.trimmingCharacters(in: .whitespaces)
        let whenText = when.isEmpty ? "일정 협의" : when
        let hood = store.selectedDong ?? location.localityName ?? ""

        if SupabaseConfig.isConfigured {
            // 위치 미확보 시 서버 생성이 실패하므로 시도하지 않고 안내.
            guard !hood.isEmpty, hood != "우리 동네" else {
                alertMessage = "위치를 확인하고 있어요. 잠시 후 다시 시도해 주세요."
                return
            }
            // 서버가 원본: 성공(비-nil id)을 확인한 뒤에만 닫는다.
            submitting = true
            Task { @MainActor in
                let id = await CrewBackend.createMeetup(
                    hood: hood, place: placeText, when: whenText,
                    capacity: cap, meetupType: type.rawValue, hostName: nickname)
                submitting = false
                if let id {
                    store.markCrewJoined(id)   // 그 id로 주최자 참가 상태 표시(로컬 목 미삽입)
                    Haptics.success()
                    dismiss()
                } else {
                    alertMessage = "모임을 만들지 못했어요. 잠시 후 다시 시도해 주세요."
                }
            }
        } else {
            // 미구성(로컬 데모): 로컬에만 추가(주최자 자동 참여).
            let meetup = CrewMeetup(
                place: placeText, when: whenText,
                hostName: nickname, hostTier: .new, joined: 0,
                capacity: cap, meetupType: type, description: desc, mine: true
            )
            store.addCrew(meetup)
            Haptics.success()
            dismiss()
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
