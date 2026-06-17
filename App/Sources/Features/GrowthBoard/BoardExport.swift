// BoardExport.swift
// BabyLog · 성장 보드 → 이미지 내보내기.
//
// 화면의 줌·팬과 무관하게 '보드 전체 콘텐츠'를 한 장으로 렌더한다(콘텐츠 바운딩 박스 기준).
// 현재: JPG(무료). 추후: 고화질 PDF는 판매(Pro)로 연계 예정 — renderPDF를 같은 BoardExportView로 추가.

import SwiftUI
import UIKit

// MARK: - 공유 시트(파일 URL)

/// 임시 파일 URL을 공유(이미지 저장·카카오톡·AirDrop 등). 파일이라 '○○의 성장 보드.jpg' 이름이 유지된다.
struct ShareFileView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// `.sheet(item:)`용 래퍼.
struct ShareFile: Identifiable { let id = UUID(); let url: URL }

// MARK: - 내보내기 로직

@MainActor
enum BoardExport {

    /// 카드·스티커가 차지하는 캔버스 영역(회전 여유 포함). 빈 보드면 작은 기본 영역.
    static func contentRect(_ board: GrowthBoard) -> CGRect {
        var minX = Double.greatestFiniteMagnitude, minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        func extend(_ cx: Double, _ cy: Double, _ halfW: Double, _ halfH: Double) {
            let r = (halfW * halfW + halfH * halfH).squareRoot()   // 회전해도 안 잘리게 대각 반지름
            minX = Swift.min(minX, cx - r); maxX = Swift.max(maxX, cx + r)
            minY = Swift.min(minY, cy - r); maxY = Swift.max(maxY, cy + r)
        }
        for c in board.cards {
            if c.kind == "memo" { extend(c.x, c.y, Double(MemoCardView.width)/2, Double(MemoCardView.height)/2) }
            else { extend(c.x, c.y, Double(PolaroidCardView.baseWidth)/2, Double(PolaroidCardView.totalHeight)/2) }
        }
        for s in board.stickers { let half = 64.0 * s.scale; extend(s.x, s.y, half, half) }
        guard minX <= maxX else { return CGRect(x: 1900, y: 1900, width: 220, height: 220) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 보드 전체를 UIImage로 렌더(고화질 — 긴 변 4096px 상한).
    static func renderImage(_ board: GrowthBoard) -> UIImage? {
        let renderer = ImageRenderer(content: BoardExportView(board: board))
        let rect = contentRect(board)
        let longest = Swift.max(rect.width, rect.height) + Double(BoardExportView.margin) * 2
        renderer.scale = CGFloat(Swift.min(3.0, 4096.0 / Swift.max(longest, 1)))
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// 보드를 JPG 파일로 렌더해 임시 URL 반환(공유·저장용). 실패 시 nil.
    static func renderJPEGFile(_ board: GrowthBoard, name: String) -> URL? {
        guard let img = renderImage(board),
              let data = img.jpegData(compressionQuality: 0.92) else { return nil }
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = (base.isEmpty ? "성장 보드" : base).replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).jpg")
        do { try data.write(to: url); return url } catch { return nil }
    }
}

// MARK: - 전체 보드 렌더 뷰(스케일 1·선택/제스처 없음 — 순수 콘텐츠)

struct BoardExportView: View {
    let board: GrowthBoard
    static let margin: CGFloat = 90

    private var rect: CGRect { BoardExport.contentRect(board) }
    private func local(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: x - rect.minX + Double(Self.margin), y: y - rect.minY + Double(Self.margin))
    }

    var body: some View {
        ZStack {
            AppColors.canvas

            // 연결선(카드 뒤) — 화면과 동일한 휜 곡선.
            Canvas { ctx, _ in
                let byId = Dictionary(board.cards.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
                for conn in board.connections {
                    guard let a = byId[conn.fromId], let b = byId[conn.toId] else { continue }
                    let pa = local(a.x, a.y), pb = local(b.x, b.y)
                    let vx = pb.x - pa.x, vy = pb.y - pa.y
                    let len = (vx*vx + vy*vy).squareRoot()
                    var path = Path(); path.move(to: pa)
                    if len > 1 {
                        let perpX = -vy/len, perpY = vx/len
                        let bow = Swift.min(len * 0.12, 40)
                        let c1 = CGPoint(x: pa.x + vx*0.3 + perpX*bow, y: pa.y + vy*0.3 + perpY*bow)
                        let c2 = CGPoint(x: pb.x - vx*0.3 + perpX*bow, y: pb.y - vy*0.3 + perpY*bow)
                        path.addCurve(to: pb, control1: c1, control2: c2)
                    } else { path.addLine(to: pb) }
                    ctx.stroke(path, with: .color(AppColors.primary.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }

            // 카드
            ForEach(board.cards) { card in
                Group {
                    if card.kind == "memo" { MemoCardView(card: card) }
                    else { PolaroidCardView(card: card, photo: PhotoStore.image(card.photoRef)) }
                }
                .rotationEffect(.radians(card.rotation))
                .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
                .position(local(card.x, card.y))
            }

            // 스티커(카드 위)
            ForEach(board.stickers) { st in
                Image("sticker_\(st.kind)").resizable().scaledToFit()
                    .frame(width: 128 * st.scale, height: 128 * st.scale)
                    .rotationEffect(.radians(st.rotation))
                    .position(local(st.x, st.y))
            }

            // 연결선 라벨 칩(선 중앙)
            ForEach(board.connections.filter { !($0.label ?? "").isEmpty }) { conn in
                if let a = board.cards.first(where: { $0.id == conn.fromId }),
                   let b = board.cards.first(where: { $0.id == conn.toId }) {
                    let pa = local(a.x, a.y), pb = local(b.x, b.y)
                    let vx = pb.x - pa.x, vy = pb.y - pa.y
                    let len = (vx*vx + vy*vy).squareRoot()
                    let mid = CGPoint(x: (pa.x + pb.x)/2, y: (pa.y + pb.y)/2)
                    let p = len > 1
                        ? CGPoint(x: mid.x + (-vy/len) * Swift.min(len*0.12, 40) * 0.75,
                                  y: mid.y + ( vx/len) * Swift.min(len*0.12, 40) * 0.75)
                        : mid
                    Text(conn.label ?? "")
                        .font(AppFont.caption).fontWeight(.bold).foregroundStyle(AppColors.ink)
                        .lineLimit(1).padding(.horizontal, 10).frame(minHeight: 28)
                        .background(AppColors.surface, in: Capsule())
                        .overlay(Capsule().stroke(AppColors.primary.opacity(0.4), lineWidth: 1))
                        .position(p)
                }
            }
        }
        .frame(width: rect.width + Double(Self.margin) * 2,
               height: rect.height + Double(Self.margin) * 2)
        // 워터마크 — 우측 하단(무료 JPG 식별·브랜드. 추후 유료 PDF는 워터마크 없이 제공).
        .overlay(alignment: .bottomTrailing) {
            watermark.padding(Double(Self.margin) * 0.42)
        }
    }

    /// BabyLog 워터마크 — 어떤 사진 위에서도 읽히도록 반투명 흰 알약 배경.
    private var watermark: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.primary)
            (Text("Baby").foregroundStyle(AppColors.ink)
             + Text("Log").foregroundStyle(AppColors.primary))
                .font(.system(size: 18, weight: .heavy))
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.white.opacity(0.82), in: Capsule())
        .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }
}
