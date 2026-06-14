// AddExpenseSheet.swift
// BabyLog — Features/Budget
//
// 지출 직접 추가 시트. store.addExpense로 실제 영속된다.

import SwiftUI

struct AddExpenseSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var category: ExpenseCategory = .diaper
    @State private var date: Date = Date()
    @State private var titleShake = 0
    @State private var amountShake = 0

    // 포커스된 필드에 primary 보더로 입력 위치를 또렷이 안내
    private enum Field { case title, amount }
    @FocusState private var focusedField: Field?

    private var amount: Int { Int(amountText.filter(\.isNumber)) ?? 0 }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    // 금액만 필수(2탭 완료 원칙). 제목 비우면 카테고리명으로 표시(addExpense가 빈 memo→nil 처리).
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s5) {

                    // 제목 (항목 이름)
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("제목 (선택)").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        TextField("예: 기저귀 (비우면 카테고리명)", text: $title)
                            .font(.system(size: 18, weight: .bold))
                            .focused($focusedField, equals: .title)
                            .padding(.horizontal, Spacing.s4)
                            .frame(height: 56)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(focusedField == .title ? AppColors.primary : AppColors.line,
                                                  lineWidth: focusedField == .title ? 1.5 : 1)
                            }
                            .animation(.easeInOut(duration: 0.18), value: focusedField)
                            .submitLabel(.done)
                            .blShake(titleShake)
                            .accessibilityLabel("지출 제목 입력")
                    }

                    // 금액
                    VStack(alignment: .leading, spacing: Spacing.s2) {
                        Text("금액").font(AppFont.subhead).foregroundStyle(AppColors.ink2)
                        HStack(spacing: Spacing.s2) {
                            TextField("0", text: $amountText)
                                .keyboardType(.numberPad)
                                .font(.system(size: 30, weight: .heavy).monospacedDigit())
                                .foregroundStyle(AppColors.ink)
                                .focused($focusedField, equals: .amount)
                            Text("원").font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppColors.ink3)
                        }
                        .padding(.horizontal, Spacing.s4)
                        .frame(height: 64)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(focusedField == .amount ? AppColors.primary : AppColors.line,
                                              lineWidth: focusedField == .amount ? 1.5 : 1)
                        }
                        .animation(.easeInOut(duration: 0.18), value: focusedField)
                        .blShake(amountShake)
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
                        HStack {
                            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .tint(AppColors.primary)
                                .labelsHidden()
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, Spacing.s4)
                        .frame(height: 52)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .stroke(AppColors.line, lineWidth: 1)
                        }
                    }

                    Spacer(minLength: Spacing.s4)

                    LiquidButton(fill: canSave ? AppColors.primary : AppColors.ink3,
                                 cornerRadius: Radius.md) {
                        guard canSave else {
                            if amount <= 0 { amountShake += 1 }
                            return
                        }
                        store.addExpense(amount: amount, category: category, date: date,
                                         memo: trimmedTitle)
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
                // 숫자 패드는 리턴키가 없어 키보드가 갇힌다 → '완료'로 내릴 수 있게.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedField = nil }
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
