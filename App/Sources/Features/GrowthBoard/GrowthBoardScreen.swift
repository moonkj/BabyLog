// GrowthBoardScreen.swift
// BabyLog · 성장 보드 — 흰 캔버스에 폴라로이드 카드를 자유 배치(Re-Link 캔버스 컨셉).
// 1단계: pan/zoom 캔버스 + "+" FAB로 카드 추가 + 카드 탭 상세(사진 등록/텍스트/삭제).
// (연결선·스티커·PDF/액자 내보내기는 후속 단계.)

import SwiftUI
import PhotosUI

struct GrowthBoardScreen: View {
    let childId: UUID
    var boardId: UUID                 // 열어볼 보드(아이당 여러 개)
    var childName: String = ""
    var onClose: () -> Void = {}

    /// 표시용 보드 이름 — 사용자 지정이 없으면 "{아이}의 성장 보드".
    private var displayTitle: String {
        if !board.title.isEmpty { return board.title }
        return childName.isEmpty ? "성장 보드" : "\(childName)의 성장 보드"
    }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// 편집 가능 여부 — 캡처값이 아닌 스토어에서 실시간 계산(세션 중 Pro 만료/구매에 즉시 반응).
    private var editable: Bool { store.isBoardEditable(boardId, childId: childId) }

    // 보드 로컬 사본 — 드래그/편집은 여기서, 커밋 시 store.upsertBoard로 저장(자동저장 폭주 방지).
    @State private var board: GrowthBoard = GrowthBoard(childId: UUID())

    // 카메라(캔버스 좌표 ↔ 스크린 좌표)
    @State private var scale: CGFloat = 0.7
    @State private var lastScale: CGFloat = 0.7
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // 카드 드래그 / 선택 / 회전(핸들)
    @State private var draggingId: UUID? = nil
    @State private var dragDelta: CGSize = .zero
    @State private var selectedCardId: UUID? = nil
    @State private var deleteCardConfirmId: UUID? = nil
    @State private var rotatingId: UUID? = nil
    @State private var liveRotation: Double = 0   // 회전 핸들 드래그 중 절대 각(라디안)

    // 상세 시트
    @State private var detailCardId: UUID? = nil
    @State private var justAddedCardId: UUID? = nil   // 방금 추가한 카드(빈 채로 닫으면 폐기)
    @State private var photoLoadInFlight = false       // 상세 시트의 비동기 사진 로딩 중
    @State private var pendingDiscardCardId: UUID? = nil   // 로딩 끝난 뒤 폐기 판정 보류분

    // 연결 모드
    @State private var connectMode = false
    @State private var connectFirst: UUID? = nil
    @State private var editingConnId: UUID? = nil
    @State private var connLabelText: String = ""

    // 스티커
    @State private var showStickerTray = false
    @State private var draggingStickerId: UUID? = nil
    @State private var stickerDragDelta: CGSize = .zero
    @State private var selectedStickerId: UUID? = nil
    @State private var stickerHandleId: UUID? = nil    // 회전/크기 핸들 조작 중
    @State private var liveStRot: Double = 0
    @State private var liveStScale: Double = 1

    // 플로팅 툴바 위치(꾹 눌러 이동 — 화면 비율로 저장, -1=기본 우하단)
    @AppStorage("bl_board_tb_fx") private var tbFx: Double = -1
    @AppStorage("bl_board_tb_fy") private var tbFy: Double = -1
    @State private var tbDragging = false
    @State private var tbDragOffset: CGSize = .zero
    @State private var immersive = false   // 전체화면: 미니맵·툴바 숨김
    @State private var shareFile: ShareFile?   // 보드 전체를 JPG로 내보내 공유/저장
    @State private var exporting = false
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showReadOnlyUpsell = false   // 보기 전용 보드에서 Pro 안내

    private let focus = CGPoint(x: GrowthBoard.canvasSize/2, y: GrowthBoard.canvasSize/2)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 배경 — 팬·줌 제스처를 배경 레이어에만 둠(카드/스티커/버튼 탭과 충돌 없음). 탭 시 선택 해제.
                AppColors.canvas.ignoresSafeArea()
                    .gesture(panGesture)
                    .simultaneousGesture(zoomGesture)
                    .onTapGesture { selectedCardId = nil; selectedStickerId = nil; connectFirst = nil }

                // 연결선 레이어(카드 뒤)
                connectionCanvas(geo: geo).allowsHitTesting(false)

                // 카드들 — 스크린 좌표로 직접 배치
                ForEach(board.cards) { card in
                    let pos = screenPos(card: card, in: geo.size)
                    let liveRot = Angle.radians(rotatingId == card.id ? liveRotation : card.rotation)
                    let isSel = selectedCardId == card.id
                    Group {
                        if card.kind == "memo" { MemoCardView(card: card) }
                        else { PolaroidCardView(card: card, photo: photo(for: card)) }
                    }
                        .scaleEffect(scale * (draggingId == card.id ? 1.05 : 1.0))
                        .rotationEffect(liveRot)
                        .overlay {
                            if connectFirst == card.id || isSel {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(AppColors.primary, lineWidth: 3)
                                    .scaleEffect(scale).rotationEffect(liveRot)
                            }
                        }
                        // 연결 모드의 첫 카드 표시(색만이 아닌 아이콘 — 색3중). 일반 선택은 아래 '편집' 알약이 표시.
                        .overlay(alignment: .topTrailing) {
                            if connectFirst == card.id {
                                Image(systemName: "link.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white, AppColors.primary)
                                    .padding(4 * scale).scaleEffect(scale)
                            }
                        }
                        .position(pos)
                        .shadow(color: .black.opacity(draggingId == card.id ? 0.25 : 0.12),
                                radius: draggingId == card.id ? 12 : 6, y: 4)
                        .zIndex((draggingId == card.id || rotatingId == card.id || isSel) ? 10 : 0)
                        .gesture(cardDrag(card), including: editable ? .all : .none)   // 보기 전용: 제스처 비활성 → 배경 팬으로 통과(카드 위에서도 이동 가능)
                        .accessibilityAddTraits(isSel ? [.isSelected, .isButton] : [.isButton])
                        .accessibilityHint(editable ? "두 번 탭하면 편집" : "두 번 탭하면 Pro 안내")
                        // 커스텀 드래그는 VoiceOver가 못 누르므로 명시적 동작 제공.
                        .accessibilityAction {
                            if editable { selectedCardId = card.id; detailCardId = card.id }
                            else { showReadOnlyUpsell = true }
                        }
                        .accessibilityActions {
                            if editable {
                                Button("삭제") { deleteCardConfirmId = card.id }
                            }
                        }
                }

                // 선택된 카드 회전 핸들(한 손가락 드래그) — 줌과 완전 분리.
                if editable, let sid = selectedCardId, let card = board.cards.first(where: { $0.id == sid }) {
                    rotateHandle(card, geo: geo)
                    cardDeleteHandle(card, geo: geo)
                    editPill(card, geo: geo)   // 선택 시 '편집' 알약 — 재탭 편집을 명시적 버튼으로(발견성)
                }

                // 스티커 — 카드 위 레이어(카드 뒤로 가려지지 않게).
                ForEach(board.stickers) { sticker in
                    let stRot = (stickerHandleId == sticker.id ? liveStRot : sticker.rotation)
                    let stScale = (stickerHandleId == sticker.id ? liveStScale : sticker.scale)
                    Image("sticker_\(sticker.kind)")
                        .resizable().scaledToFit()
                        .frame(width: 128 * scale * stScale, height: 128 * scale * stScale)
                        .rotationEffect(.radians(stRot))
                        .position(stickerPos(sticker, in: geo.size))
                        .zIndex(draggingStickerId == sticker.id ? 20 : 15)
                        .gesture(stickerDrag(sticker), including: editable ? .all : .none)   // 보기 전용: 배경 팬 통과
                        .accessibilityLabel("스티커, \(BoardSticker.displayName(sticker.kind))")
                        .accessibilityAddTraits(selectedStickerId == sticker.id ? [.isSelected] : [])
                }

                // 선택된 스티커: 우상단 회전/크기 핸들 + 좌상단 삭제.
                if editable, let sid = selectedStickerId, let st = board.stickers.first(where: { $0.id == sid }) {
                    stickerHandles(st, geo: geo)
                }

                // 연결선 라벨 칩(선 중앙) — 라벨 있는 연결만(없으면 칩 없음). connectionMid 선형스캔을 라벨분으로 한정.
                ForEach(board.connections.filter { !($0.label ?? "").isEmpty }) { conn in
                    if let mid = connectionMid(conn, in: geo.size) {
                        connectionLabelChip(conn).position(mid)
                    }
                }

                if board.cards.isEmpty && board.stickers.isEmpty { emptyHint }

                // UI 컨트롤은 항상 카드·스티커(zIndex≤20) 위에.
                topBar(geo: geo).zIndex(100)
                if connectMode && !immersive { connectBanner.zIndex(100) }   // 전체화면에선 배너도 숨김(탈출구 없음 방지)
                if !editable && !immersive { readOnlyBanner.zIndex(100) }     // 보기 전용 안내 + Pro
                if !immersive {
                    if editable { sideToolbar(geo: geo).zIndex(100).transition(.opacity) }   // 편집 도구는 편집 가능할 때만
                    // 미니맵은 내용이 있을 때만 — 빈 보드에서 컨트롤이 과해 보이지 않게.
                    // (좌측 +/- 줌 버튼은 제거 — 핀치 줌과 우상단 '가운데로'로 충분.)
                    if !(board.cards.isEmpty && board.stickers.isEmpty) {
                        miniMap(geo: geo).zIndex(100).transition(.opacity)
                    }
                }
            }
            // 줌·팬은 배경 레이어에만 부착(컨테이너 제스처가 버튼 첫 탭을 먹던 문제 해결).
            .coordinateSpace(name: "board")
        }
        .onAppear {
            board = store.board(id: boardId) ?? GrowthBoard(id: boardId, childId: childId)
            // 첫 진입 시 캔버스 중앙이 화면 중앙에 오도록(offset 0 = 중앙). scale만 적용.
        }
        // 같은 커버가 다른 보드로 재사용될 경우 대비(현재 플로우엔 없지만 방어적) — 로컬 board 재동기화.
        .onChange(of: boardId) { _, newId in board = store.board(id: newId) ?? GrowthBoard(id: newId, childId: childId) }
        .sheet(item: Binding(get: { detailCardId.map { IdentBox(id: $0) } },
                             set: { detailCardId = $0?.id }),
               onDismiss: {
                   // 빈 카드는 먼저 폐기한 뒤 확정 저장 — 빈 카드가 디스크에 남지 않게.
                   // 사진 로딩 중이면 폐기 판정을 로딩 종료까지 보류(사진이 늦게 들어올 수 있음).
                   if photoLoadInFlight { pendingDiscardCardId = justAddedCardId; justAddedCardId = nil }
                   else { discardEmptyNewCardIfNeeded() }
                   if editable { store.upsertBoard(board) }   // 스와이프로 닫아도 남은 편집 확정 저장(보기전용/세션중 Pro만료 보드엔 미반영)
               }) { boxed in
            CardDetailSheet(
                card: binding(for: boxed.id),
                onDelete: { deleteCard(boxed.id) },
                diaryPhotos: diaryPhotoOptions(),
                onCommit: { justAddedCardId = nil; if editable { store.upsertBoard(board) } },
                loadInFlight: $photoLoadInFlight
            )
            .environmentObject(store)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: photoLoadInFlight) { _, loading in
            // 로딩이 끝났는데 보류된 폐기 판정이 있으면 지금 처리(성공=사진有→유지, 실패=빈카드→폐기).
            guard !loading, let id = pendingDiscardCardId else { return }
            pendingDiscardCardId = nil
            discardEmptyNewCard(id)
        }
        .sheet(isPresented: $showStickerTray) { stickerTray }
        // 보드 전체 JPG 내보내기 — '이미지 저장'(사진앱)·카카오톡·AirDrop 등.
        .sheet(item: $shareFile) { ShareFileView(url: $0.url) }
        // 연결선 메모 — 커스텀 시트(알림창의 TextField는 첫 탭이 키보드만 내려 버튼이 두 번 눌리는 UIKit 버그가 있어 시트로 대체).
        .sheet(item: Binding(get: { editingConnId.map { IdentBox(id: $0) } },
                             set: { editingConnId = $0?.id })) { boxed in
            BoardTextInputSheet(
                title: "연결선 메모",
                message: "선 위에 표시할 글이에요. 비워두면 글 없이 선만 남아요.",
                placeholder: "예: 첫 만남, 100일 → 돌",
                secondaryLabel: "지우기",
                initial: connLabelText,
                onSave: { saveConnLabel(id: boxed.id, text: $0) },
                onSecondary: { saveConnLabel(id: boxed.id, text: "") }
            )
        }
        .confirmationDialog("이 카드를 삭제할까요?", isPresented: Binding(
            get: { deleteCardConfirmId != nil }, set: { if !$0 { deleteCardConfirmId = nil } }
        ), titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                if let id = deleteCardConfirmId { deleteCard(id); selectedCardId = nil }
                deleteCardConfirmId = nil
            }
            Button("취소", role: .cancel) { deleteCardConfirmId = nil }
        } message: {
            // 기록에서 가져온 사진은 보드 카드만 지워도 원본이 보존됨을 안내(신뢰·데이터 인질극 금지).
            if let id = deleteCardConfirmId,
               let c = board.cards.first(where: { $0.id == id }), c.sourceEntryId != nil {
                Text("카드만 지워요. 기록의 원본 사진은 그대로 남아요.")
            }
        }
        .sheet(isPresented: $showRename) {
            BoardTextInputSheet(
                title: "보드 이름",
                message: "성장 보드에 표시할 이름이에요. 비우면 '\(childName.isEmpty ? "성장 보드" : childName + "의 성장 보드")'로 돌아가요.",
                placeholder: "예: 우리 시온이의 첫 1년",
                secondaryLabel: "기본값으로",
                initial: renameText,
                onSave: { saveBoardTitle(text: $0) },
                onSecondary: { saveBoardTitle(text: "") }
            )
        }
        .sheet(isPresented: $showReadOnlyUpsell) { ProUpsellSheet().environmentObject(store) }
    }

    private func saveBoardTitle(text: String) {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count > 24 { t = String(t.prefix(24)) }
        // 기본 이름을 그대로 저장하면 빈 값으로 정규화(기본 자동 추종).
        let defaultName = childName.isEmpty ? "성장 보드" : "\(childName)의 성장 보드"
        board.title = (t == defaultName) ? "" : t
        store.upsertBoard(board)
        Haptics.light()
    }

    // MARK: 연결선 라벨

    /// 연결선 중점(살짝 휜 곡선 위)의 스크린 좌표.
    private func connectionMid(_ conn: BoardConnection, in size: CGSize) -> CGPoint? {
        guard let a = board.cards.first(where: { $0.id == conn.fromId }),
              let b = board.cards.first(where: { $0.id == conn.toId }) else { return nil }
        let pa = screenPos(card: a, in: size), pb = screenPos(card: b, in: size)
        let vx = pb.x - pa.x, vy = pb.y - pa.y
        let len = (vx*vx + vy*vy).squareRoot()
        let mid = CGPoint(x: (pa.x + pb.x)/2, y: (pa.y + pb.y)/2)
        guard len > 1 else { return mid }
        let bow = min(len * 0.12, 40) * 0.75    // 곡선 중점 오프셋(connectionCanvas와 일치)
        return CGPoint(x: mid.x + (-vy/len)*bow, y: mid.y + (vx/len)*bow)
    }

    @ViewBuilder
    private func connectionLabelChip(_ conn: BoardConnection) -> some View {
        // 라벨이 있을 때만 칩 표시(없으면 선만). 칩 탭하면 수정.
        if let label = conn.label, !label.isEmpty {
            Text(label)
                .font(AppFont.caption).fontWeight(.bold).foregroundStyle(AppColors.ink)   // 화면 위 칩은 Dynamic Type 존중
                .lineLimit(1)
                .padding(.horizontal, 10).frame(minHeight: 28)
                .background(AppColors.surface, in: Capsule())
                .overlay(Capsule().stroke(AppColors.primary.opacity(0.4), lineWidth: 1))
                .blShadow(.card)
                .onTapGesture { if editable { connLabelText = label; editingConnId = conn.id } }
                .accessibilityLabel("연결: \(label)")
                .accessibilityHint(editable ? "탭하면 연결선 글 수정" : "")
        }
    }

    private func saveConnLabel(id: UUID, text: String) {
        guard let i = board.connections.firstIndex(where: { $0.id == id }) else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        board.connections[i].label = t.isEmpty ? nil : t
        store.upsertBoard(board)
        editingConnId = nil
    }

    // MARK: 이미지 내보내기

    /// 보드 전체(줌·팬과 무관)를 한 장의 JPG로 렌더해 공유/저장 시트를 띄운다.
    /// (추후 고화질 PDF는 Pro 판매로 연계 — 같은 BoardExportView 재사용.)
    private func exportBoardImage() {
        guard !exporting else { return }
        exporting = true
        Haptics.light()
        // 다음 런루프에 렌더 — 버튼의 hourglass 상태가 먼저 반영되도록.
        DispatchQueue.main.async {
            shareFile = BoardExport.renderJPEGFile(board, name: displayTitle).map { ShareFile(url: $0) }
            exporting = false
        }
    }

    // MARK: 좌표 변환

    private func screenPos(card: BoardCard, in size: CGSize) -> CGPoint {
        var cx = card.x, cy = card.y
        if draggingId == card.id {
            cx += Double(dragDelta.width / scale)
            cy += Double(dragDelta.height / scale)
        }
        return CGPoint(
            x: (cx - Double(focus.x)) * Double(scale) + Double(size.width)/2 + Double(offset.width),
            y: (cy - Double(focus.y)) * Double(scale) + Double(size.height)/2 + Double(offset.height)
        )
    }

    // MARK: 제스처

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                // 핸들 조작(회전·크기) 중 두 번째 손가락으로 배경을 끌어 카메라가 흔들리는 것 방지.
                guard rotatingId == nil && stickerHandleId == nil else { return }
                offset = CGSize(width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { m in scale = min(max(lastScale * m, 0.1), 2.5) }   // 0.1까지 축소 → 보드 전체 한눈에
            .onEnded { _ in lastScale = scale }
    }

    /// 탭+드래그 통합 — minimumDistance 0이라 단일 탭이 한 번에 동작(별도 onTapGesture가 첫 탭을 먹던 문제 해결).
    private func cardDrag(_ card: BoardCard) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard editable else { return }   // 보기 전용: 카드 이동 없음
                guard draggingId == nil || draggingId == card.id else { return }   // 멀티터치: 다른 카드 드래그 중이면 무시(상태 충돌 방지)
                if abs(v.translation.width) > 4 || abs(v.translation.height) > 4 {
                    draggingId = card.id; dragDelta = v.translation
                }
            }
            .onEnded { v in
                let moved = abs(v.translation.width) > 4 || abs(v.translation.height) > 4
                if moved && editable {
                    guard draggingId == nil || draggingId == card.id else { return }   // 다른 카드가 점유 중이면 커밋 스킵
                    if let i = board.cards.firstIndex(where: { $0.id == card.id }) {
                        board.cards[i].x += Double(v.translation.width / scale)
                        board.cards[i].y += Double(v.translation.height / scale)
                    }
                    store.upsertBoard(board, immediate: false)   // 위치 = 잦은 변경 → debounce 저장
                } else {
                    onCardTap(card.id)   // 이동 없음 = 탭
                }
                draggingId = nil; dragDelta = .zero
            }
    }

    // MARK: 카드 추가/삭제

    /// 화면 중앙(캔버스 좌표)에 카드 생성. 사진 카드는 그냥 생성(탭해서 채움), 메모 카드는 바로 상세(글 입력).
    private func addCard(kind: String) {
        let cx = Double(focus.x) - Double(offset.width / scale)
        let cy = Double(focus.y) - Double(offset.height / scale)
        let jitter = Double.random(in: -0.05...0.05)
        var card = BoardCard(kind: kind, x: cx, y: cy, rotation: jitter)
        if kind == "memo" { card.theme = "mint" }   // 캡션은 비워둠(사용자가 직접 입력)
        board.cards.append(card)   // 로컬에만 추가(즉시 렌더). 영속화는 내용 입력(onCommit)·닫기(onDismiss) 시 — 빈 카드 유령 방지.
        Haptics.light()
        justAddedCardId = card.id
        detailCardId = card.id   // 사진·메모 모두 추가 즉시 상세 입력 팝업
    }

    private func deleteCard(_ id: UUID) {
        guard let i = board.cards.firstIndex(where: { $0.id == id }) else { return }
        let removed = board.cards[i]
        board.connections.removeAll { $0.fromId == id || $0.toId == id }   // 끊긴 연결선 정리
        board.cards.remove(at: i)
        // 삭제된 카드에 묶인 일시 상태 정리(핸들이 사라지며 onEnded가 안 와 stuck 되는 것 방지).
        if rotatingId == id { rotatingId = nil }
        if draggingId == id { draggingId = nil; dragDelta = .zero }
        if selectedCardId == id { selectedCardId = nil }
        store.upsertBoard(board)                       // 먼저 스토어에서 카드 제거(반영)
        store.cleanupBoardCardPhoto(removed)           // 그 뒤 정리 — 공유 사진은 ref-count로 보존
    }

    private func binding(for id: UUID) -> Binding<BoardCard> {
        Binding(
            get: { board.cards.first(where: { $0.id == id }) ?? BoardCard() },
            set: { newVal in
                if let i = board.cards.firstIndex(where: { $0.id == id }) { board.cards[i] = newVal }
                else if let ref = newVal.photoRef, !ref.isEmpty, newVal.sourceEntryId == nil {
                    PhotoStore.delete(ref)   // 카드가 이미 삭제됐는데 비동기 로딩이 보드전용 사진을 붙였으면 고아 정리
                }
            }
        )
    }

    // 캔버스 폴라로이드는 작게(~176pt) 렌더 — 4096px 풀해상도 대신 썸네일로 메모리 절감(줌 여유로 700px).
    private func photo(for card: BoardCard) -> UIImage? { PhotoStore.thumbnail(card.photoRef, maxPixel: 700) }

    /// 기록(다이어리)에서 가져올 사진 후보 — (ref, 원본 entryId).
    private func diaryPhotoOptions() -> [(ref: String, entryId: String)] {
        store.diaryEntries
            .filter { $0.childId == childId }
            .sorted { $0.date > $1.date }
            .flatMap { e in e.photoRefList.map { (ref: $0, entryId: e.id.uuidString) } }
    }

    // MARK: 보조 뷰

    private var emptyHint: some View {
        VStack(spacing: Spacing.s3) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .light)).foregroundStyle(AppColors.ink3)
            Text("첫 폴라로이드를 붙여볼까요?")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.ink)
            Text("‘사진’ 도구를 누르면 바로 채울 수 있어요.\n나중에 카드를 탭하면 다시 편집할 수 있어요.")
                .font(AppFont.callout).foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .accessibilityElement(children: .combine)
    }

    private func topBar(geo: GeometryProxy) -> some View {
        VStack {
            HStack {
                Button {
                    // 편집 가능한 보드만 처리 — 보기 전용 보드는 절대 건드리지 않음(닫기만 해도 지워지면 데이터 유실).
                    if editable {
                        // 빈 보드(카드·스티커 0)는 닫을 때 정리 — 실수로 만든 보드가 슬롯 점유/목록을 어지럽히지 않게.
                        if board.cards.isEmpty && board.stickers.isEmpty { store.deleteBoard(id: boardId) }
                        else { store.persistNow() }   // 그 외엔 마지막 위치 변경(debounce 대기분) 확정 저장
                    }
                    onClose(); dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink2)
                        .frame(width: 40, height: 40).background(AppColors.surface, in: Circle()).blShadow(.card)
                }
                .accessibilityLabel("닫기")
                Spacer()
                Button {
                    renameText = board.title   // 비어 있으면 기본 이름을 입력란에 채워 편집 시작
                    if renameText.isEmpty { renameText = displayTitle }
                    showRename = true
                } label: {
                    HStack(spacing: 5) {
                        Text(displayTitle)
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(AppColors.ink).lineLimit(1)
                        if editable {
                            Image(systemName: "pencil").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                        }
                    }
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(AppColors.surface, in: Capsule()).blShadow(.card)
                }
                .disabled(!editable)   // 보기 전용 보드는 이름 변경 불가
                .accessibilityLabel("보드 이름 편집")
                Spacer()
                HStack(spacing: Spacing.s2) {
                    if !(board.cards.isEmpty && board.stickers.isEmpty) {
                        Button { exportBoardImage() } label: {
                            Image(systemName: exporting ? "hourglass" : "square.and.arrow.down")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink2)
                                .frame(width: 40, height: 40).background(AppColors.surface, in: Circle()).blShadow(.card)
                        }
                        .disabled(exporting)
                        .accessibilityLabel("보드 전체를 사진으로 저장")
                        .accessibilityHint("보드 전체가 한 장의 JPG로 저장돼요")
                    }
                    Button { withAnimation(.easeOut(duration: 0.25)) { resetCamera(geo: geo) } } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink2)
                            .frame(width: 40, height: 40).background(AppColors.surface, in: Circle()).blShadow(.card)
                    }
                    .accessibilityLabel("가운데로")
                    .accessibilityHint("길게 누르면 도구막대 위치도 기본값으로 되돌려요")
                    .onLongPressGesture { tbFx = -1; tbFy = -1; Haptics.success() }   // 툴바 위치 초기화(실수로 옮겼을 때)
                    Button {
                        // 전체화면 진입 시 모드/선택 정리 — 숨겨진 컨트롤에 갇히지 않게.
                        if !immersive { connectMode = false; connectFirst = nil; selectedCardId = nil; selectedStickerId = nil }
                        withAnimation(.easeInOut(duration: 0.25)) { immersive.toggle() }
                        Haptics.light()
                    } label: {
                        Image(systemName: immersive ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(immersive ? .white : AppColors.ink2)
                            .frame(width: 40, height: 40)
                            .background(immersive ? AppColors.primary : AppColors.surface, in: Circle()).blShadow(.card)
                    }
                    .accessibilityLabel(immersive ? "전체화면 끄기" : "전체화면")
                }
            }
            .padding(.horizontal, Spacing.s4).padding(.top, Spacing.s2)
            Spacer()
        }
    }

    // MARK: 세로 플로팅 툴바 (카드추가 · 연결 · 스티커) — 꾹 눌러 위치 이동
    private static let tbHalfW: CGFloat = 44
    private static let tbHalfH: CGFloat = 132

    /// 툴바 중심 좌표(저장된 비율 → 화면 좌표, 화면 안으로 클램프). 기본 우하단.
    private func toolbarCenter(in size: CGSize) -> CGPoint {
        let fx = tbFx < 0 ? 1.0 : tbFx
        let fy = tbFy < 0 ? 1.0 : tbFy
        let m: CGFloat = 16
        let x = min(max(size.width * CGFloat(fx), Self.tbHalfW + m), size.width - Self.tbHalfW - m)
        let y = min(max(size.height * CGFloat(fy), Self.tbHalfH + 70), size.height - Self.tbHalfH - m)
        return CGPoint(x: x, y: y)
    }

    private func sideToolbar(geo: GeometryProxy) -> some View {
        let base = toolbarCenter(in: geo.size)
        let center = tbDragging ? CGPoint(x: base.x + tbDragOffset.width, y: base.y + tbDragOffset.height) : base
        return VStack(spacing: Spacing.s2) {
            toolButton(title: "사진", icon: "photo.badge.plus", active: false) { addCard(kind: "photo") }
            toolButton(title: "메모", icon: "note.text.badge.plus", active: false) { addCard(kind: "memo") }
            toolButton(title: "연결", icon: "link", active: connectMode,
                       disabled: board.cards.count < 2) {   // 카드 2장 이상일 때만 — 연결할 게 없는데 모드 진입 방지
                connectMode.toggle(); connectFirst = nil; Haptics.light()
            }
            toolButton(title: "스티커", icon: "sparkles", active: false) { showStickerTray = true }
        }
        .padding(.vertical, Spacing.s3).padding(.horizontal, Spacing.s2)
        .background(AppColors.surface, in: Capsule())
        .overlay(alignment: .top) {
            // 꾹 누르면 이동 가능 — 잡았을 때 그립 표시.
            if tbDragging {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(5).background(AppColors.primary, in: Circle()).offset(y: -10)
            }
        }
        .scaleEffect(tbDragging ? 1.06 : 1.0)
        .blShadow(.fab)
        .position(center)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: tbDragging)
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    if case .second(true, let drag?) = value {
                        if !tbDragging { Haptics.medium() }
                        tbDragging = true
                        tbDragOffset = drag.translation
                    }
                }
                .onEnded { value in
                    if case .second(_, .some(let drag)) = value {
                        let nx = base.x + drag.translation.width
                        let ny = base.y + drag.translation.height
                        tbFx = Double(min(max(nx / geo.size.width, 0), 1))
                        tbFy = Double(min(max(ny / geo.size.height, 0), 1))
                    }
                    tbDragging = false
                    tbDragOffset = .zero
                }
        )
    }

    private func toolButton(title: String, icon: String, active: Bool, disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: { Haptics.light(); action() }) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(active ? .white : AppColors.ink2)
            .frame(width: 64, height: 52)
            .background(active ? AppColors.primary : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(LiquidPressStyle(scale: 0.95))
        .disabled(disabled).opacity(disabled ? 0.4 : 1)
        .accessibilityLabel(title)
    }

    /// 보기 전용(무료 비대표 보드) 안내 배너 — 탭하면 Pro 안내.
    private var readOnlyBanner: some View {
        VStack {
            Button { showReadOnlyUpsell = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "eye").foregroundStyle(AppColors.gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("이 보드는 안전하게 보관돼 있어요")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(AppColors.ink)
                        Text("보기는 언제나 무료 · 편집하려면 Pro")
                            .font(.system(size: 11, weight: .medium)).foregroundStyle(AppColors.ink2)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(AppColors.ink3)
                }
                .padding(.horizontal, Spacing.s4).padding(.vertical, 8)
                .background(AppColors.surface, in: Capsule()).blShadow(.card)
            }
            .accessibilityLabel("이 보드는 안전하게 보관돼 있어요. 보기는 무료, 편집하려면 Pro. 탭하면 안내")
            .padding(.top, 60)
            Spacer()
        }
    }

    private var connectBanner: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(AppColors.primary)
                Text(connectFirst == nil ? "연결할 첫 카드를 탭하세요" : "연결할 다음 카드를 탭하세요 (이미 연결돼 있으면 해제)")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColors.ink)
                // 모드 탈출구를 항상 노출 — 연결 모드에 갇히지 않게.
                Button { connectMode = false; connectFirst = nil; Haptics.light() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(AppColors.ink3)
                }
                .accessibilityLabel("연결 그만두기")
            }
            .padding(.horizontal, Spacing.s4).frame(height: 44)
            .background(AppColors.surface, in: Capsule()).blShadow(.card)
            .padding(.top, 64)
            Spacer()
        }
    }

    // MARK: 미니맵 (좌하단 전체 보기)

    private func miniMap(geo: GeometryProxy) -> some View {
        let mm: CGFloat = 116
        let cs = CGFloat(GrowthBoard.canvasSize)
        let r = mm / cs                                   // 캔버스 → 미니맵 비율
        let vpW = min((geo.size.width / scale) * r, mm)
        let vpH = min((geo.size.height / scale) * r, mm)
        // 뷰포트 사각형 중심을 미니맵 안으로 클램프 — 저배율·먼 팬에서 표시 사각형이 미니맵 밖으로 나가는 것 방지.
        let vcx = min(max((CGFloat(focus.x) - offset.width / scale) * r, vpW/2), mm - vpW/2)
        let vcy = min(max((CGFloat(focus.y) - offset.height / scale) * r, vpH/2), mm - vpH/2)
        // 툴바가 좌하단으로 오면 미니맵은 우하단으로 자동 회피.
        let tbBase = toolbarCenter(in: geo.size)
        let tbC = tbDragging ? CGPoint(x: tbBase.x + tbDragOffset.width, y: tbBase.y + tbDragOffset.height) : tbBase
        let onRight = tbC.x < geo.size.width * 0.5 && tbC.y > geo.size.height * 0.5
        return VStack {
            Spacer()
            HStack {
                if onRight { Spacer() }
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppColors.surface.opacity(0.94))
                    // 점들을 개별 뷰 대신 단일 Canvas로 — 카드 수만큼 뷰를 매 팬 프레임 재배치하던 비용 제거.
                    Canvas { ctx, _ in
                        for c in board.cards {
                            let p = CGPoint(x: CGFloat(c.x) * r, y: CGFloat(c.y) * r)
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
                                     with: .color(AppColors.primary))
                        }
                        for s in board.stickers {
                            let p = CGPoint(x: CGFloat(s.x) * r, y: CGFloat(s.y) * r)
                            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)),
                                     with: .color(AppColors.gold))
                        }
                    }
                    .frame(width: mm, height: mm)
                    Rectangle().stroke(AppColors.ink2, lineWidth: 1)
                        .frame(width: vpW, height: vpH).position(x: vcx, y: vcy)
                }
                .frame(width: mm, height: mm)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.line, lineWidth: 1))
                .blShadow(.card)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        // 손가락 위치(미니맵)를 캔버스 좌표로 → 그 지점이 화면 중앙에 오게(연속 추적)
                        let cx = Double(v.location.x / r), cy = Double(v.location.y / r)
                        offset = CGSize(width: (Double(focus.x) - cx) * Double(scale),
                                        height: (Double(focus.y) - cy) * Double(scale))
                    }
                    .onEnded { _ in lastOffset = offset })
                .accessibilityLabel("미니맵")
                .padding(onRight ? .trailing : .leading, Spacing.s4).padding(.bottom, Spacing.s6)
                if !onRight { Spacer() }
            }
        }
    }

    // MARK: 연결선

    private func connectionCanvas(geo: GeometryProxy) -> some View {
        Canvas { ctx, _ in
            // 카드 id→카드 사전을 1회만 만들어 O(연결·카드) 선형스캔을 O(연결)로 — 연결 많은 보드 프레임비용 절감.
            let byId = Dictionary(board.cards.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for conn in board.connections {
                guard let a = byId[conn.fromId], let b = byId[conn.toId] else { continue }
                let pa = screenPos(card: a, in: geo.size)
                let pb = screenPos(card: b, in: geo.size)
                // Re-Link 스타일 — 약간 휜 부드러운 곡선(실선). 점선 아님.
                let vx = pb.x - pa.x, vy = pb.y - pa.y
                let len = (vx*vx + vy*vy).squareRoot()
                var path = Path(); path.move(to: pa)
                if len > 1 {
                    let perpX = -vy/len, perpY = vx/len
                    let bow = min(len * 0.12, 40)
                    let c1 = CGPoint(x: pa.x + vx*0.3 + perpX*bow, y: pa.y + vy*0.3 + perpY*bow)
                    let c2 = CGPoint(x: pb.x - vx*0.3 + perpX*bow, y: pb.y - vy*0.3 + perpY*bow)
                    path.addCurve(to: pb, control1: c1, control2: c2)
                } else { path.addLine(to: pb) }
                ctx.stroke(path, with: .color(AppColors.primary.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func onCardTap(_ id: UUID) {
        guard editable else { showReadOnlyUpsell = true; return }   // 보기 전용: 편집 진입 대신 Pro 안내
        if connectMode {
            if let first = connectFirst {
                if first == id { connectFirst = nil }
                else { toggleConnection(first, id); connectFirst = nil; Haptics.light() }
            } else {
                connectFirst = id
            }
        } else {
            // 첫 탭 = 선택(회전 핸들 표시), 선택된 카드 재탭 = 상세 편집.
            if selectedCardId == id { justAddedCardId = nil; detailCardId = id }   // 기존 카드 편집 — 빈카드 폐기 대상 아님
            else { selectedCardId = id }
        }
    }

    /// 방금 추가한 카드를 내용 입력 없이 닫으면 폐기(빈 폴라로이드/메모가 쌓이지 않게).
    private func discardEmptyNewCardIfNeeded() {
        guard let id = justAddedCardId else { return }
        justAddedCardId = nil
        discardEmptyNewCard(id)
    }

    private func discardEmptyNewCard(_ id: UUID) {
        guard let card = board.cards.first(where: { $0.id == id }) else { return }
        let hasPhoto = !(card.photoRef ?? "").isEmpty
        let empty = !hasPhoto
            && card.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && card.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if empty { deleteCard(id); if selectedCardId == id { selectedCardId = nil } }
    }

    private func toggleConnection(_ a: UUID, _ b: UUID) {
        if let i = board.connections.firstIndex(where: {
            ($0.fromId == a && $0.toId == b) || ($0.fromId == b && $0.toId == a)
        }) {
            board.connections.remove(at: i)   // 이미 연결됨 → 해제
            store.upsertBoard(board)
        } else {
            let conn = BoardConnection(fromId: a, toId: b)
            board.connections.append(conn)
            store.upsertBoard(board)
            // 연결 직후 라벨 입력 기회(선택) — 비우면 글 없이 선만.
            connLabelText = ""; editingConnId = conn.id
        }
    }

    // MARK: 스티커

    private func stickerPos(_ s: BoardSticker, in size: CGSize) -> CGPoint {
        var cx = s.x, cy = s.y
        if draggingStickerId == s.id {
            cx += Double(stickerDragDelta.width / scale)
            cy += Double(stickerDragDelta.height / scale)
        }
        return CGPoint(
            x: (cx - Double(focus.x)) * Double(scale) + Double(size.width)/2 + Double(offset.width),
            y: (cy - Double(focus.y)) * Double(scale) + Double(size.height)/2 + Double(offset.height)
        )
    }

    private func stickerDrag(_ s: BoardSticker) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                guard editable else { return }   // 보기 전용: 스티커 이동 없음
                guard draggingStickerId == nil || draggingStickerId == s.id else { return }   // 멀티터치 충돌 방지
                if abs(v.translation.width) > 4 || abs(v.translation.height) > 4 {
                    draggingStickerId = s.id; stickerDragDelta = v.translation
                }
            }
            .onEnded { v in
                guard editable else { showReadOnlyUpsell = true; return }   // 보기 전용: 편집 대신 Pro 안내
                let moved = abs(v.translation.width) > 4 || abs(v.translation.height) > 4
                if moved {
                    if let i = board.stickers.firstIndex(where: { $0.id == s.id }) {
                        board.stickers[i].x += Double(v.translation.width / scale)
                        board.stickers[i].y += Double(v.translation.height / scale)
                    }
                    store.upsertBoard(board, immediate: false)   // 위치 = 잦은 변경 → debounce 저장
                } else {
                    selectedStickerId = (selectedStickerId == s.id) ? nil : s.id   // 탭 = 선택(핸들 표시)
                    selectedCardId = nil
                }
                draggingStickerId = nil; stickerDragDelta = .zero
            }
    }

    /// 카드 실제 표시 크기(캔버스 좌표). 사진/메모 종류별로 다름 — 핸들 위치 정확도용.
    private func cardSize(_ card: BoardCard) -> CGSize {
        card.kind == "memo"
            ? CGSize(width: MemoCardView.width, height: MemoCardView.height)
            : CGSize(width: PolaroidCardView.baseWidth, height: PolaroidCardView.totalHeight)
    }

    /// 선택된 카드의 회전 핸들(카드 우상단 코너 바깥). 한 손가락으로 끌어 회전 — 줌과 분리.
    @ViewBuilder
    private func rotateHandle(_ card: BoardCard, geo: GeometryProxy) -> some View {
        let center = screenPos(card: card, in: geo.size)
        let rot = (rotatingId == card.id ? liveRotation : card.rotation)
        let sz = cardSize(card)
        let halfW = Double(sz.width) / 2 * Double(scale)
        let halfH = Double(sz.height) / 2 * Double(scale)
        let dist = max((halfW * halfW + halfH * halfH).squareRoot() + 14, 46)   // 코너까지 + 여유(저배율서 겹침 방지 하한)
        let cornerLocal = atan2(-halfH, halfW)        // 우상단 코너 방향(로컬, 카드 비율 반영)
        let hp = CGPoint(x: center.x + CGFloat(cos(rot + cornerLocal) * dist),
                         y: center.y + CGFloat(sin(rot + cornerLocal) * dist))
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(AppColors.primary, in: Circle()).blShadow(.card)
            .frame(width: 44, height: 44).contentShape(Circle())   // 터치 영역 44pt(시각 크기는 유지)
            .position(hp)
            .zIndex(30)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
                .onChanged { v in
                    rotatingId = card.id
                    let dx = Double(v.location.x - center.x), dy = Double(v.location.y - center.y)
                    liveRotation = atan2(dy, dx) - cornerLocal   // 핸들 로컬각만큼 보정
                }
                .onEnded { _ in
                    if let i = board.cards.firstIndex(where: { $0.id == card.id }) {
                        board.cards[i].rotation = liveRotation
                    }
                    rotatingId = nil
                    store.upsertBoard(board, immediate: false)   // 회전 = 잦은 변경 → debounce 저장
                })
            .accessibilityLabel("카드 회전 핸들")
    }

    /// 선택된 카드의 삭제 핸들(좌상단 코너). 탭하면 확인 팝업.
    @ViewBuilder
    private func cardDeleteHandle(_ card: BoardCard, geo: GeometryProxy) -> some View {
        let center = screenPos(card: card, in: geo.size)
        let rot = (rotatingId == card.id ? liveRotation : card.rotation)
        let sz = cardSize(card)
        let halfW = Double(sz.width) / 2 * Double(scale)
        let halfH = Double(sz.height) / 2 * Double(scale)
        let dist = max((halfW * halfW + halfH * halfH).squareRoot() + 14, 46)
        let cornerLocal = atan2(-halfH, -halfW)       // 좌상단 코너 방향
        let dp = CGPoint(x: center.x + CGFloat(cos(rot + cornerLocal) * dist),
                         y: center.y + CGFloat(sin(rot + cornerLocal) * dist))
        Button { deleteCardConfirmId = card.id } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.red, in: Circle()).blShadow(.card)
                .frame(width: 44, height: 44).contentShape(Circle())   // 터치 영역 44pt
        }
        .position(dp).zIndex(30)
        .accessibilityLabel("카드 삭제")
    }

    /// 선택된 카드 아래 '편집' 알약 — 두 단계 탭(선택→재탭 편집)을 눈에 보이는 버튼으로 만들어 발견성 확보.
    @ViewBuilder
    private func editPill(_ card: BoardCard, geo: GeometryProxy) -> some View {
        let center = screenPos(card: card, in: geo.size)
        let sz = cardSize(card)
        let halfDiag = (pow(Double(sz.width)/2, 2) + pow(Double(sz.height)/2, 2)).squareRoot() * Double(scale)
        let p = CGPoint(x: center.x, y: center.y + CGFloat(max(halfDiag + 20, 44)))
        Button { detailCardId = card.id } label: {
            Label("편집", systemImage: "pencil")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).frame(height: 36)
                .background(AppColors.primary, in: Capsule()).blShadow(.card)
        }
        .position(p).zIndex(30)
        .accessibilityLabel("편집")
    }

    private func addSticker(_ kind: String) {
        var cx = Double(focus.x) - Double(offset.width / scale)
        var cy = Double(focus.y) - Double(offset.height / scale)
        // 기존 스티커와 겹치면 나선형으로 빈 자리 탐색(스티커끼리 안 겹치게).
        let minDist = 130.0
        func overlaps(_ x: Double, _ y: Double) -> Bool {
            board.stickers.contains { abs($0.x - x) < minDist && abs($0.y - y) < minDist }
        }
        if overlaps(cx, cy) {
            search: for ring in 1...10 {
                for deg in stride(from: 0.0, to: 360.0, by: 45.0) {
                    let r = Double(ring) * minDist
                    let nx = cx + cos(deg * .pi/180) * r
                    let ny = cy + sin(deg * .pi/180) * r
                    if !overlaps(nx, ny) { cx = nx; cy = ny; break search }
                }
            }
        }
        board.stickers.append(BoardSticker(kind: kind, x: cx, y: cy))
        store.upsertBoard(board)
        showStickerTray = false
        Haptics.light()
    }

    /// 선택된 스티커: 우상단 회전+크기 핸들, 좌상단 삭제 — 카드와 동일한 패턴(팝업 없음).
    @ViewBuilder
    private func stickerHandles(_ s: BoardSticker, geo: GeometryProxy) -> some View {
        let center = stickerPos(s, in: geo.size)
        let stRot = (stickerHandleId == s.id ? liveStRot : s.rotation)
        let stScale = (stickerHandleId == s.id ? liveStScale : s.scale)
        let half = 128.0 * Double(scale) * stScale / 2
        let dist = max(half * 1.414 + 18, 46)   // 저배율서 핸들이 스티커에 겹치지 않게 하한
        let rp = CGPoint(x: center.x + CGFloat(cos(stRot - .pi/4) * dist),
                         y: center.y + CGFloat(sin(stRot - .pi/4) * dist))
        let dp = CGPoint(x: center.x + CGFloat(cos(stRot - .pi*3/4) * dist),
                         y: center.y + CGFloat(sin(stRot - .pi*3/4) * dist))
        Group {
            // 우상단: 드래그로 회전(각도) + 크기(중심 거리).
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AppColors.primary, in: Circle()).blShadow(.card)
                .frame(width: 44, height: 44).contentShape(Circle())   // 터치 영역 44pt
                .position(rp).zIndex(30)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
                    .onChanged { v in
                        stickerHandleId = s.id
                        let dx = Double(v.location.x - center.x), dy = Double(v.location.y - center.y)
                        liveStRot = atan2(dy, dx) + .pi/4
                        let base = 128.0 * Double(scale) / 2 * 1.414
                        liveStScale = min(max((max(hypot(dx, dy) - 18, 8)) / base, 0.4), 4)
                    }
                    .onEnded { _ in
                        if let i = board.stickers.firstIndex(where: { $0.id == s.id }) {
                            board.stickers[i].rotation = liveStRot
                            board.stickers[i].scale = liveStScale
                        }
                        stickerHandleId = nil
                        store.upsertBoard(board, immediate: false)   // 회전·크기 = 잦은 변경 → debounce 저장
                    })
                .accessibilityLabel("스티커 회전·크기")
            // 좌상단: 삭제.
            Button { deleteSticker(s.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.red, in: Circle()).blShadow(.card)
                    .frame(width: 44, height: 44).contentShape(Circle())   // 터치 영역 44pt
            }
            .position(dp).zIndex(30)
            .accessibilityLabel("스티커 삭제")
        }
    }

    private func deleteSticker(_ id: UUID) {
        board.stickers.removeAll { $0.id == id }
        if selectedStickerId == id { selectedStickerId = nil }
        if stickerHandleId == id { stickerHandleId = nil }
        if draggingStickerId == id { draggingStickerId = nil; stickerDragDelta = .zero }
        store.upsertBoard(board); Haptics.light()
    }

    private var stickerTray: some View {
        // 디자인 스티커 33종(diary_stickers_handoff). 카테고리별 그룹.
        let groups: [(String, [String])] = [
            ("감정", ["smile", "giggle", "love", "sleepy", "cry", "heart-pink", "heart-coral", "heart-gold"]),
            ("기념일", ["cake", "crown", "medal", "firststep", "tooth"]),
            ("가족", ["boy", "girl", "mom", "dad", "grandma", "grandpa"]),
            ("사물", ["bottle", "paci", "rattle", "foot", "bib"]),
            ("꾸미기", ["sun", "moon", "star", "cloud", "flower", "leaf", "ribbon", "sparkle", "speech"]),
        ]
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.s4) {
                    ForEach(groups, id: \.0) { group in
                        VStack(alignment: .leading, spacing: Spacing.s2) {
                            Text(group.0).font(AppFont.caption).foregroundStyle(AppColors.ink2)
                            LazyVGrid(columns: cols, spacing: 14) {
                                ForEach(group.1, id: \.self) { k in
                                    Button { addSticker(k) } label: {
                                        Image("sticker_\(k)").resizable().scaledToFit()
                                            .frame(width: 54, height: 54)
                                    }
                                    .buttonStyle(LiquidPressStyle(scale: 0.9))
                                    .accessibilityLabel("스티커 \(BoardSticker.displayName(k))")
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.s5)
            }
            .background(AppColors.surface)
            .navigationTitle("스티커")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { showStickerTray = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func resetCamera(geo: GeometryProxy) {
        // 콘텐츠 맞춤 — 멀리 둔 카드도 항상 화면에 들어오게(빈 보드는 캔버스 중심 기본값).
        let pts = board.cards.map { CGPoint(x: $0.x, y: $0.y) } + board.stickers.map { CGPoint(x: $0.x, y: $0.y) }
        guard let minX = pts.map(\.x).min(), let maxX = pts.map(\.x).max(),
              let minY = pts.map(\.y).min(), let maxY = pts.map(\.y).max() else {
            scale = 0.7; lastScale = 0.7; offset = .zero; lastOffset = .zero; return
        }
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let w = (maxX - minX) + 280, h = (maxY - minY) + 360   // 카드 크기·여백 여유
        let fit = min(geo.size.width / CGFloat(w), geo.size.height / CGFloat(h))
        let s = min(max(fit, 0.1), 1.0)
        scale = s; lastScale = s
        offset = CGSize(width: (Double(focus.x) - cx) * Double(s),
                        height: (Double(focus.y) - cy) * Double(s))
        lastOffset = offset
    }

}

/// sheet(item:)용 Identifiable 박스.
private struct IdentBox: Identifiable { let id: UUID }

/// 텍스트 1줄 입력 시트(연결선 메모·보드 이름·홈 섹션 제목 공용). 알림창의 TextField 더블탭 버그 회피용.
struct BoardTextInputSheet: View {
    let title: String
    let message: String
    let placeholder: String
    let secondaryLabel: String
    let initial: String
    var onSave: (String) -> Void
    var onSecondary: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(message)
                    .font(AppFont.caption).foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                TextField(placeholder, text: $text)
                    .font(AppFont.body).focused($focused)
                    .submitLabel(.done).onSubmit { onSave(text); dismiss() }
                    .padding(.horizontal, Spacing.s3).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                HStack(spacing: Spacing.s2) {
                    Button(role: .destructive) { onSecondary(); dismiss() } label: {
                        Text(secondaryLabel)
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(AppColors.danger)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    Button { onSave(text); dismiss() } label: {
                        Text("저장")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.s5)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .onAppear {
            text = initial
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}
