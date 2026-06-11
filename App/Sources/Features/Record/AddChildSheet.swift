// AddChildSheet.swift
// BabyLog — 아이 등록/수정 시트
//
// editing == nil 이면 신규 등록(completeBabyOnboarding),
// editing 이 있으면 해당 아이 수정/삭제(updateChild/deleteChild).

import SwiftUI

struct AddChildSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 수정 대상 아이 (nil = 신규 등록)
    let editing: Child?

    @State private var name: String
    @State private var birthDate: Date
    @State private var gender: Gender?
    @State private var shakeTrigger = 0
    @State private var showDeleteConfirm = false

    init(editing: Child? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _birthDate = State(initialValue: editing?.birthDate ?? Date())
        _gender = State(initialValue: editing?.gender)
    }

    private var isEditing: Bool { editing != nil }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {

                    // 이름/태명
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("아이 이름 (또는 태명)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("예: 지호", text: $name)
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 56)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .submitLabel(.done)
                            .blShake(shakeTrigger)
                            .accessibilityLabel("아이 이름 입력")
                    }

                    // 생년월일
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("생년월일").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    // 성별 (선택)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("성별 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack(spacing: Spacing.s2) {
                            genderChip(nil, "선택 안 함")
                            genderChip(.boy, "남아")
                            genderChip(.girl, "여아")
                        }
                    }

                    Text(isEditing
                         ? "수정한 정보가 홈·기록·성장 곡선에 바로 반영돼요."
                         : "등록하면 홈·기록·성장 곡선이 이 아이 기준으로 채워져요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)

                    Spacer(minLength: Spacing.s4)

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3,
                                 cornerRadius: Radius.md) {
                        guard canSave else { shakeTrigger += 1; return }
                        if let editing {
                            store.updateChild(id: editing.id, name: trimmedName, birthDate: birthDate, gender: gender)
                        } else {
                            store.completeBabyOnboarding(name: trimmedName, birthDate: birthDate, gender: gender)
                        }
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text(isEditing ? "저장하기" : "등록하기").frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(isEditing ? "아이 정보 저장" : "아이 등록하기")

                    // 삭제 (수정 모드)
                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("이 아이 삭제")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.danger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .accessibilityLabel("이 아이 삭제")
                    }
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle(isEditing ? "아이 정보 수정" : "아이 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .confirmationDialog("이 아이의 기록도 함께 삭제돼요. 계속할까요?",
                                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let editing { store.deleteChild(id: editing.id) }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
        }
    }

    private func genderChip(_ value: Gender?, _ label: String) -> some View {
        let selected = gender == value
        return Button {
            Haptics.selection()
            gender = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Color.white : AppColors.ink2)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(selected ? AppColors.primary : AppColors.surface2,
                            in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.96))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview {
    AddChildSheet().environmentObject(AppStore())
}
#endif
