// GrowthBoardCard.swift
// BabyLog · 성장 보드 — 폴라로이드 카드 뷰 + 카드 상세 편집 시트.

import SwiftUI
import PhotosUI

// MARK: - 폴라로이드 카드 뷰

struct PolaroidCardView: View {
    let card: BoardCard
    let photo: UIImage?

    static let baseWidth: CGFloat = 200   // 캔버스 좌표 기준 폭
    static let totalHeight: CGFloat = 12 + (baseWidth - 24) + 44   // 상단여백 + 사진 + 캡션

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(AppColors.surface2)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40, weight: .light)).foregroundStyle(AppColors.ink3)
                }
            }
            .frame(width: Self.baseWidth - 24, height: Self.baseWidth - 24)
            .clipped()
            .padding(.top, 12).padding(.horizontal, 12)

            // 캡션은 선택 — 비어 있으면 안내문 없이 빈 폴라로이드 하단(여백)만 유지.
            Text(card.caption)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .frame(width: Self.baseWidth - 24, height: 44)
        }
        .frame(width: Self.baseWidth)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color.black.opacity(0.05), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("사진 카드"
            + (card.caption.isEmpty ? "" : ", \(card.caption)")
            + (card.note.isEmpty ? "" : ", \(card.note)"))   // 메모 본문도 VoiceOver로 읽히게(캔버스 전용 텍스트 접근)
    }
}

// MARK: - 메모 카드(텍스트 전용)

struct MemoTheme {
    let paper: Color, ink: Color, rule: Color, tape: Color
    static let keys = ["mint", "pink", "amber", "blue", "coral", "purple"]
    static let labels: [String: String] = ["mint": "민트", "pink": "핑크", "amber": "앰버", "blue": "블루", "coral": "코랄", "purple": "퍼플"]
    private static func C(_ hex: UInt32) -> Color { Color(hex: hex) }
    static func of(_ key: String?) -> MemoTheme {
        switch key {
        case "pink":   return .init(paper: C(0xFCEDF3), ink: C(0x8E3568), rule: C(0xB5478A).opacity(0.16), tape: C(0xF4C9DA))
        case "amber":  return .init(paper: C(0xFBF1DC), ink: C(0x7A5A18), rule: C(0x98711E).opacity(0.16), tape: C(0xF2DCA9))
        case "blue":   return .init(paper: C(0xEAF2FB), ink: C(0x2D5685), rule: C(0x3B6FA8).opacity(0.16), tape: C(0xC7DDF2))
        case "coral":  return .init(paper: C(0xFBEAE4), ink: C(0x8A3B2A), rule: C(0xB45840).opacity(0.16), tape: C(0xF0C6BB))
        case "purple": return .init(paper: C(0xF1EFFB), ink: C(0x46408C), rule: C(0x5B53B0).opacity(0.16), tape: C(0xD8D4F2))
        default:       return .init(paper: C(0xEAF6EF), ink: C(0x27583F), rule: C(0x2E7A5C).opacity(0.16), tape: C(0xBFE0D0))  // mint
        }
    }
}

struct MemoCardView: View {
    let card: BoardCard
    static let width: CGFloat = 210
    static let height: CGFloat = 150
    private static let pitch: CGFloat = 26          // 괘선 간격 = 본문 줄 간격(겹침 방지 핵심)
    private static let bodyFont = UIFont.systemFont(ofSize: 13)

    var body: some View {
        let t = MemoTheme.of(card.theme)
        let bodyTop: CGFloat = card.title.isEmpty ? 22 : 46
        let firstBaseline = bodyTop + Self.bodyFont.ascender   // 첫 줄 글자 베이스라인
        ZStack(alignment: .top) {
            ZStack(alignment: .topLeading) {
                t.paper
                // 괘선 — 글자 베이스라인 바로 아래에 그어 '줄 위에 쓰기' 정렬.
                Canvas { ctx, size in
                    var y = firstBaseline + 3
                    while y < size.height - 8 {
                        var p = Path(); p.move(to: CGPoint(x: 14, y: y)); p.addLine(to: CGPoint(x: size.width - 14, y: y))
                        ctx.stroke(p, with: .color(t.rule), style: StrokeStyle(lineWidth: 1))
                        y += Self.pitch
                    }
                }
                if !card.title.isEmpty {
                    Text(card.title).font(.system(size: 15, weight: .heavy)).foregroundStyle(t.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 14).padding(.top, 14)
                }
                // 본문 — 줄 간격을 괘선 간격에 정확히 일치(lineSpacing = pitch − lineHeight).
                Text(card.note).font(.system(size: 13)).foregroundStyle(t.ink.opacity(0.92))
                    .lineSpacing(Self.pitch - Self.bodyFont.lineHeight)
                    .lineLimit(4).truncationMode(.tail)   // 고정 높이 카드 — 넘치면 말줄임(오버플로 방지)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 14).padding(.top, bodyTop)
                // 접힌 모서리
                Path { p in
                    p.move(to: CGPoint(x: Self.width - 24, y: Self.height))
                    p.addLine(to: CGPoint(x: Self.width, y: Self.height - 24))
                    p.addLine(to: CGPoint(x: Self.width, y: Self.height))
                }.fill(Color.black.opacity(0.06))
            }
            .frame(width: Self.width, height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            // 워시테이프
            RoundedRectangle(cornerRadius: 2).fill(t.tape.opacity(0.7))
                .frame(width: 74, height: 20).rotationEffect(.degrees(-2)).offset(y: -8)
        }
        .frame(width: Self.width, height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("메모 카드"
            + (card.title.isEmpty ? "" : ", \(card.title)")
            + (card.note.isEmpty ? "" : ", \(card.note)"))
    }
}

// MARK: - 카드 상세 편집 시트

struct CardDetailSheet: View {
    @Binding var card: BoardCard
    var onDelete: () -> Void
    var diaryPhotos: [(ref: String, entryId: String)]
    var onCommit: () -> Void
    /// 비동기 사진 로딩 중 표시 — 화면이 '빈 카드 폐기'를 사진이 들어오기 전에 실행하지 않게 함.
    var loadInFlight: Binding<Bool> = .constant(false)

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var showDiaryGrid = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.s4) {
                    if card.kind == "memo" {
                        // 메모 카드 — 텍스트 전용(색 테마 + 제목 + 본문)
                        field(title: "색") { themePicker.padding(.top, 2) }
                        field(title: "제목") {
                            TextField("예: 오늘의 한 줄", text: $card.title)
                                .font(AppFont.body)
                                .padding(.horizontal, Spacing.s3).frame(height: 48)
                                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .onChange(of: card.title) { _, v in if v.count > 30 { card.title = String(v.prefix(30)) } }
                        }
                        field(title: "내용") {
                            TextEditor(text: $card.note)
                                .font(AppFont.body).frame(minHeight: 160)
                                .padding(Spacing.s2)
                                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .scrollContentBackground(.hidden)
                                .onChange(of: card.note) { _, v in if v.count > 500 { card.note = String(v.prefix(500)) } }
                        }
                        .padding(.top, Spacing.s2)
                    } else {
                        // 사진 폴라로이드
                        photoArea.padding(.top, Spacing.s3)
                        field(title: "캡션 (폴라로이드 아래 글씨)") {
                            TextField("예: 20개월, 첫 걸음마 (최대 20자)", text: $card.caption)
                                .font(AppFont.body)
                                .padding(.horizontal, Spacing.s3).frame(height: 48)
                                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .onChange(of: card.caption) { _, v in
                                    if v.count > 20 { card.caption = String(v.prefix(20)) }
                                }
                        }
                        field(title: "메모") {
                            TextEditor(text: $card.note)
                                .font(AppFont.body).frame(minHeight: 100)
                                .padding(Spacing.s2)
                                .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                                .scrollContentBackground(.hidden)
                                .onChange(of: card.note) { _, v in if v.count > 500 { card.note = String(v.prefix(500)) } }
                        }
                    }

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("카드 삭제", systemImage: "trash")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.danger)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .padding(.top, Spacing.s2)
                }
                .padding(.horizontal, Spacing.s5).padding(.bottom, Spacing.s7)
            }
            .background(AppColors.surface)
            .navigationTitle("카드")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { onCommit(); dismiss() }
                        .font(.system(size: 16, weight: .bold))
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loadInFlight.wrappedValue = true   // 로딩 중엔 빈 카드 폐기를 보류(사진이 늦게 들어와도 카드 보존·고아 파일 방지)
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data),
                   let ref = PhotoStore.save(img, maxDimension: 4096) {   // 보드 전용 사진 = 4096(인쇄 화질)
                    await MainActor.run {
                        // 기존 보드 전용 사진이 있으면 교체 전 정리
                        if let old = card.photoRef, !old.isEmpty, card.sourceEntryId == nil { PhotoStore.delete(old) }
                        card.photoRef = ref
                        card.sourceEntryId = nil
                        onCommit()
                    }
                }
                // 성공/실패 모두 로딩 종료 — 실패 시엔 빈 카드면 화면이 폐기 처리(유령 카드 방지).
                await MainActor.run { pickerItem = nil; loadInFlight.wrappedValue = false }
            }
        }
        .sheet(isPresented: $showDiaryGrid) {
            DiaryPhotoPicker(photos: diaryPhotos) { ref, entryId in
                if let old = card.photoRef, !old.isEmpty, card.sourceEntryId == nil { PhotoStore.delete(old) }
                card.photoRef = ref
                card.sourceEntryId = entryId   // 참조(원본 소유 — 삭제 시 보존)
                onCommit()
                showDiaryGrid = false
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("이 카드를 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { onDelete(); dismiss() }
            Button("취소", role: .cancel) {}
        }
    }

    private var photoArea: some View {
        VStack(spacing: Spacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).fill(AppColors.surface2)
                if let img = PhotoStore.thumbnail(card.photoRef, maxPixel: 1000) {
                    // 상세 미리보기는 240pt — 4096px 풀해상도 대신 1000px 썸네일(메모리 절감). scaledToFit으로 안 잘리게.
                    Image(uiImage: img).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.system(size: 32)).foregroundStyle(AppColors.ink3)
                        Text("사진").font(AppFont.caption).foregroundStyle(AppColors.ink3)
                    }
                }
            }
            .frame(height: 240).clipped()

            HStack(spacing: Spacing.s2) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("새 사진", systemImage: "photo")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                Button { showDiaryGrid = true } label: {
                    Label("기록에서", systemImage: "square.grid.2x2")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .disabled(diaryPhotos.isEmpty).opacity(diaryPhotos.isEmpty ? 0.4 : 1)
            }
        }
    }

    private var themePicker: some View {
        HStack(spacing: 10) {
            ForEach(MemoTheme.keys, id: \.self) { key in
                let t = MemoTheme.of(key)
                Circle().fill(t.paper)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke((card.theme ?? "mint") == key ? t.ink : AppColors.line, lineWidth: (card.theme ?? "mint") == key ? 3 : 1))
                    .onTapGesture { card.theme = key }
                    .accessibilityLabel(MemoTheme.labels[key] ?? key)
            }
            Spacer(minLength: 0)
        }
    }

    private func field<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text(title).font(AppFont.caption).foregroundStyle(AppColors.ink2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 기록 사진 그리드 피커

private struct DiaryPhotoPicker: View {
    let photos: [(ref: String, entryId: String)]
    var onPick: (_ ref: String, _ entryId: String) -> Void
    @Environment(\.dismiss) private var dismiss

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(photos, id: \.ref) { item in
                        Button { onPick(item.ref, item.entryId) } label: {
                            if let img = PhotoStore.thumbnail(item.ref, maxPixel: 400) {   // 110pt 그리드 셀 — 썸네일로 충분
                                Image(uiImage: img).resizable().scaledToFill()
                                    .frame(height: 110).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 8).fill(AppColors.surface2).frame(height: 110)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Spacing.s4)
            }
            .background(AppColors.surface)
            .navigationTitle("기록에서 사진 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }
}
