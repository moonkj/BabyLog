// AddExpenseSheet.swift
// BabyLog — Features/Budget
//
// 지출 직접 추가 시트. store.addExpense로 실제 영속된다.

import SwiftUI

struct AddExpenseSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .diaper
    @State private var date: Date = Date()
    @State private var memo: String = ""
    @State private var shakeTrigger = 0

    private var amount: Int { Int(amountText.filter(\.isNumber)) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {

                    // 금액
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("금액").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack(spacing: Spacing.s2) {
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 30, weight: .heavy).monospacedDigit())
                                .foregroundStyle(AppColors.ink)
                            Text("원").font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.ink3)
                        }
                        .padding(.horizontal, Spacing.s4)
                        .frame(height: 64)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .blShake(shakeTrigger)
                    }

                    // 카테고리 (색+아이콘+레이블 3중)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("카테고리").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 4),
                                  spacing: Spacing.s2) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                                categoryChip(cat)
                            }
                        }
                    }

                    // 날짜
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("날짜").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }

                    // 메모
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("메모 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("예: 기저귀 대용량", text: $memo)
                            .font(AppFont.body)
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 48)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }

                    Spacer(minLength: Spacing.s4)

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3,
                                 cornerRadius: Radius.md) {
                        guard canSave else {
                            shakeTrigger += 1   // 금액 미입력 시 흔들림 + 경고 햅틱
                            return
                        }
                        store.addExpense(amount: amount, category: category, date: date,
                                         memo: memo.isEmpty ? nil : memo)
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("저장하기").frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel("지출 저장하기")
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.canvas.ignoresSafeArea())
            .navigationTitle("지출 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func categoryChip(_ cat: ExpenseCategory) -> some View {
        let selected = cat == category
        return Button {
            Haptics.selection()
            category = cat
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.systemIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(selected ? cat.badgeTone.ink : AppColors.ink3)
                Text(cat.displayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(selected ? AppColors.ink : AppColors.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(selected ? cat.badgeTone.bg : AppColors.surface,
                        in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(selected ? cat.badgeTone.ink.opacity(0.5) : .clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(LiquidPressStyle(scale: 0.95))
        .accessibilityLabel(cat.accessibilityLabel)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

#if DEBUG
#Preview {
    AddExpenseSheet().environmentObject(AppStore())
}
#endif
