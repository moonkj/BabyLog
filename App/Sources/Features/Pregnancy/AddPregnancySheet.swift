// AddPregnancySheet.swift
// BabyLog — 임신 등록/수정 시트
//
// editing == nil 이면 신규(startPregnancy), 있으면 수정/삭제(updatePregnancy/deletePregnancy).

import SwiftUI

struct AddPregnancySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let editing: Pregnancy?

    @State private var nickname: String
    @State private var edd: Date
    @State private var useLMP: Bool
    @State private var lmp: Date
    @State private var shakeTrigger = 0
    @State private var showDeleteConfirm = false

    init(editing: Pregnancy? = nil) {
        self.editing = editing
        _nickname = State(initialValue: editing?.nickname ?? "")
        let defaultEDD = Calendar.current.date(byAdding: .day, value: 140, to: Date()) ?? Date()
        _edd = State(initialValue: editing?.eddDate ?? defaultEDD)
        _useLMP = State(initialValue: editing?.lmpDate != nil)
        _lmp = State(initialValue: editing?.lmpDate
                     ?? Calendar.current.date(byAdding: .day, value: -140, to: Date()) ?? Date())
    }

    private var isEditing: Bool { editing != nil }
    private var trimmed: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {

                    // 태명
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("태명").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("예: 튼튼이", text: $nickname)
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 56)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .submitLabel(.done)
                            .blShake(shakeTrigger)
                            .accessibilityLabel("태명 입력")
                    }

                    // 출산 예정일
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("출산 예정일").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        DatePicker("", selection: $edd, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    // 마지막 생리일 (선택 — 더 정확한 주차)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Toggle(isOn: $useLMP) {
                            Text("마지막 생리일로 주차 계산 (선택)")
                                .font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        }
                        .tint(AppColors.pregnancyPink)
                        if useLMP {
                            DatePicker("", selection: $lmp, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }

                    Text("의료 정보를 대체하지 않아요. 주차·예정일은 담당 의료진과 확인하세요.")
                        .font(AppFont.caption).foregroundStyle(AppColors.ink3)

                    Spacer(minLength: Spacing.s4)

                    LiquidButton(fill: AppColors.pregnancyPink, cornerRadius: Radius.md) {
                        let name = trimmed.isEmpty ? nil : trimmed
                        let lmpVal = useLMP ? lmp : nil
                        if let editing {
                            store.updatePregnancy(id: editing.id, nickname: name, lmp: lmpVal, edd: edd)
                        } else {
                            store.startPregnancy(lmp: lmpVal, edd: edd, nickname: name)
                        }
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text(isEditing ? "저장하기" : "임신 등록하기").frame(maxWidth: .infinity)
                    }

                    if isEditing {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Text("임신 기록 삭제")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.danger)
                                .frame(maxWidth: .infinity).frame(height: 44)
                        }
                    }
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle(isEditing ? "임신 정보 수정" : "임신 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() } }
            }
            .confirmationDialog("임신 기록을 삭제할까요? 관련 기록도 함께 삭제돼요.",
                                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let editing { store.deletePregnancy(id: editing.id) }
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            }
        }
    }
}

#if DEBUG
#Preview {
    AddPregnancySheet().environmentObject(AppStore())
}
#endif
