// AddChildSheet.swift
// BabyLog — 아이 추가/등록 시트
//
// 홈 다자녀 칩의 "+" 또는 빈 상태에서 호출. store.completeBabyOnboarding으로 실제 영속된다.

import SwiftUI

struct AddChildSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var shakeTrigger = 0

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

                    Text("등록하면 홈·기록·성장 곡선이 이 아이 기준으로 채워져요.")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)

                    Spacer(minLength: Spacing.s4)

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3,
                                 cornerRadius: Radius.md) {
                        guard canSave else { shakeTrigger += 1; return }
                        store.completeBabyOnboarding(name: trimmedName, birthDate: birthDate, gender: nil)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("등록하기").frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("아이 등록하기")
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("아이 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    AddChildSheet().environmentObject(AppStore())
}
#endif
