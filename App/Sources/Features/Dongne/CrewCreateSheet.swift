// CrewCreateSheet.swift
// BabyLog · Features/Dongne — 동네 모임 만들기 (로컬 백본)

import SwiftUI

struct CrewCreateSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var place = ""
    @State private var when = ""
    @State private var capacityText = "6"
    @State private var type: CrewMeetupType = .park
    @State private var desc = ""

    private var nickname: String { UserDefaults.standard.string(forKey: "bl_nickname") ?? "양육자님" }
    private var canSave: Bool { !place.trimmingCharacters(in: .whitespaces).isEmpty }

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
                    }

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3, action: {
                        guard canSave else { return }
                        let cap = max(2, Int(capacityText.filter(\.isNumber)) ?? 6)
                        let meetup = CrewMeetup(
                            place: place.trimmingCharacters(in: .whitespaces),
                            when: when.isEmpty ? "일정 협의" : when,
                            hostName: nickname, hostTier: .new, joined: 0,
                            capacity: cap, meetupType: type, description: desc, mine: true
                        )
                        store.addCrew(meetup)
                        Haptics.success()
                        dismiss()
                    }) {
                        Text("모임 만들기").frame(maxWidth: .infinity)
                    }
                    .padding(.top, Spacing.s2)
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("모임 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } } }
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
