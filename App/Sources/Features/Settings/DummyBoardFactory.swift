// DummyBoardFactory.swift
// BabyLog · 운영자 전용 — 광고/스크린샷용 '예쁜' 성장 보드 더미데이터 생성기.
//
// 사진은 외부 에셋 없이 즉석 합성(파스텔 그라데이션 + 큰 이모지)해 PhotoStore에 저장하므로
// 자기완결적이다(실제 아동 사진을 쓰지 않음 — 안전·프라이버시). 카드(사진/메모)·스티커·연결선이
// 스크랩북처럼 살짝 기울어 배치된다. 운영자 화면(개발 탭)에서만 호출된다.

import SwiftUI
import UIKit

@MainActor
enum DummyBoardFactory {

    private static func rad(_ deg: Double) -> Double { deg * .pi / 180 }

    /// 광고/데모용 성장 보드 1개 생성(사진·메모·스티커·연결선 포함). 대상 아이가 없으면 샘플 아이를 만든다.
    /// - Returns: 생성한 보드 id.
    @discardableResult
    static func makeSampleBoard(in store: AppStore) -> UUID {
        // 1) 대상 아이 — 선택/첫 아이가 있으면 그 아이, 없으면 데모용 샘플 아이.
        let childId: UUID
        if let c = store.selectedChild ?? store.children.first {
            childId = c.id
        } else {
            let birth = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
            store.completeBabyOnboarding(name: "라온", birthDate: birth, gender: .girl)
            childId = store.children.first!.id
        }

        // 2) 보드 생성(빈 보드 → 아래에서 카드 채워 업서트).
        var board = store.createBoard(childId: childId, title: "라온이의 첫 1년 🌸")

        // 3) 사진 카드 — 파스텔 그라데이션 + 이모지로 즉석 합성.
        func photo(_ emoji: String, _ top: UInt32, _ bottom: UInt32,
                   _ caption: String, _ x: Double, _ y: Double, _ deg: Double) -> BoardCard {
            BoardCard(kind: "photo", photoRef: renderPhoto(emoji: emoji, top: top, bottom: bottom),
                      caption: caption, x: x, y: y, rotation: rad(deg))
        }
        let p1 = photo("👶", 0xFFD9E2, 0xFFB3C7, "처음 만난 날", 1780, 1740, -5)
        let p2 = photo("🎉", 0xCFEFE0, 0x9FE0C4, "백일잔치",     2080, 1710,  5)
        let p3 = photo("🌟", 0xFFE9C2, 0xFFD089, "첫 뒤집기",    1740, 2010,  3)
        let p4 = photo("👣", 0xCFE3FF, 0xA6CBFF, "첫 걸음마",    2030, 2020, -4)
        let p5 = photo("🎂", 0xFFD7CC, 0xFFB59E, "첫 생일",      1850, 2290, -3)

        // 4) 메모 카드 — 따뜻한 카피(성별 중립·민감 톤).
        func memo(_ title: String, _ note: String, _ theme: String,
                  _ x: Double, _ y: Double, _ deg: Double) -> BoardCard {
            BoardCard(kind: "memo", title: title, note: note, theme: theme, x: x, y: y, rotation: rad(deg))
        }
        let m1 = memo("엄마의 한마디", "네가 와줘서\n매일이 선물 같아 💕", "pink", 2360, 1830,  6)
        let m2 = memo("키 · 몸무게",   "76cm · 9.8kg\n쑥쑥 자라는 중 🌱", "blue", 2330, 2120, -4)
        let m3 = memo("오늘의 기록",   "처음으로 ‘엄마’라고\n불러준 날 🥰", "mint", 2150, 2310,  4)

        board.cards = [p1, p2, p3, p4, p5, m1, m2, m3]

        // 5) 스티커 — 빈 면을 채워 풍성하게.
        func st(_ kind: String, _ x: Double, _ y: Double, _ scale: Double, _ deg: Double) -> BoardSticker {
            BoardSticker(kind: kind, x: x, y: y, scale: scale, rotation: rad(deg))
        }
        board.stickers = [
            st("heart-pink", 1980, 1600, 1.10, -8),
            st("cake",       1630, 2170, 1.00,  6),
            st("star",       2300, 2350, 0.95, 10),
            st("foot",       2510, 1990, 0.90, -6),
            st("moon",       1650, 1880, 0.85,  8),
        ]

        // 6) 연결선 — 스토리 흐름(처음 → 첫 생일).
        board.connections = [
            BoardConnection(fromId: p1.id, toId: p5.id, label: "0일 → 첫 생일"),
        ]

        store.upsertBoard(board)
        return board.id
    }

    // MARK: - 사진 합성

    /// 파스텔 그라데이션 배경 + 좌상단 하이라이트 + 큰 이모지 1개로 '사진' 합성 → PhotoStore 저장, 파일명 반환.
    private static func renderPhoto(emoji: String, top: UInt32, bottom: UInt32) -> String? {
        let size = CGSize(width: 1000, height: 1000)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            // 대각선 그라데이션
            if let grad = CGGradient(colorsSpace: space,
                                     colors: [uiColor(top).cgColor, uiColor(bottom).cgColor] as CFArray,
                                     locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero,
                                      end: CGPoint(x: size.width, y: size.height), options: [])
            }
            // 좌상단 부드러운 하이라이트
            if let glow = CGGradient(colorsSpace: space,
                                     colors: [UIColor.white.withAlphaComponent(0.40).cgColor,
                                              UIColor.white.withAlphaComponent(0.0).cgColor] as CFArray,
                                     locations: [0, 1]) {
                let c = CGPoint(x: size.width * 0.32, y: size.height * 0.28)
                cg.drawRadialGradient(glow, startCenter: c, startRadius: 0,
                                      endCenter: c, endRadius: size.width * 0.72, options: [])
            }
            // 큰 이모지 중앙
            let ns = emoji as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 460)]
            let sz = ns.size(withAttributes: attrs)
            ns.draw(at: CGPoint(x: (size.width - sz.width) / 2,
                                y: (size.height - sz.height) / 2 - 20), withAttributes: attrs)
        }
        return PhotoStore.save(img)
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
