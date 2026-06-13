import SwiftUI

/// 스플래시 새싹 ★ — DESIGN.md §8.2 (계층1)
/// 콜드 스타트: 나뭇잎이 돋고 → 주위로 원(물결)이 한 번 퍼진 뒤 → 그 원이 다시 돌아와
/// "나뭇잎 + 원" = 앱 아이콘(크림 배경·금색 링·흰 원판·초록 잎)으로 정착한다.
/// transform/opacity만(60fps). reduce motion 시 아이콘 정지 상태만 잠깐 노출.
struct SeedlingSplashView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 단계별 상태
    @State private var leafIn = false      // 잎 돋아남
    @State private var ripple = false      // 원이 바깥으로 퍼짐
    @State private var iconIn = false      // 원이 돌아와 흰 원판 + 금색 링으로 정착
    @State private var titleShow = false
    @State private var fade = false

    // 앱 아이콘 색 (원본 SVG에서 추출)
    private let leafGreen = Color(hex: 0x2E7A5C)
    private let discFill  = Color.white
    private let ringTop   = Color(hex: 0xEBC56C)
    private let ringBot   = Color(hex: 0xC9A24B)
    private let creamHi   = Color(hex: 0xF5EDDC)
    private let creamLo   = Color(hex: 0xE3D4BA)

    private let discSize: CGFloat = 152

    var body: some View {
        ZStack {
            // 아이콘과 동일한 크림 라디얼 배경
            RadialGradient(
                gradient: Gradient(colors: [creamHi, creamLo]),
                center: UnitPoint(x: 0.46, y: 0.40),
                startRadius: 0, endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // 아이콘 조립부 — 흰 원판 / 금색 링 / 물결 / 잎
                ZStack {
                    // 흰 원판 (마지막에 잎 뒤로 페이드인)
                    Circle()
                        .fill(discFill)
                        .frame(width: discSize, height: discSize)
                        .scaleEffect(iconIn ? 1 : 0.7)
                        .opacity(iconIn ? 1 : 0)

                    // 금색 링 (퍼졌던 원이 '돌아오듯' 바깥에서 수축해 정착)
                    Circle()
                        .stroke(
                            LinearGradient(colors: [ringTop, ringBot],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 3
                        )
                        .frame(width: discSize, height: discSize)
                        .scaleEffect(iconIn ? 1 : 1.7)
                        .opacity(iconIn ? 1 : 0)

                    // 물결 — 잎 주위로 한 번 퍼지고 사라짐
                    Circle()
                        .stroke(
                            LinearGradient(colors: [ringTop, ringBot],
                                           startPoint: .top, endPoint: .bottom)
                                .opacity(0.55),
                            lineWidth: 2.5
                        )
                        .frame(width: discSize, height: discSize)
                        .scaleEffect(ripple ? 2.2 : 0.42)
                        .opacity(ripple ? 0 : 0.9)

                    // 나뭇잎 (앱 아이콘과 동일 — 초록 leaf.fill)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 82, weight: .semibold))
                        .foregroundStyle(leafGreen)
                        .scaleEffect(leafIn ? 1 : 0.2)
                        .rotationEffect(.degrees(leafIn ? 0 : -25), anchor: .bottom)
                        .opacity(leafIn ? 1 : 0)
                }
                .frame(width: discSize, height: discSize)

                Text("베이비로그")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(AppColors.ink)
                    .opacity(titleShow ? 1 : 0)
            }
        }
        .opacity(fade ? 0 : 1)
        .onAppear { run() }
        .accessibilityHidden(true)
    }

    private func run() {
        guard !reduceMotion else {
            // 모션 최소화 — 아이콘 정지 상태만 잠깐 보여주고 페이드아웃
            leafIn = true
            withAnimation(.easeOut(duration: 0.25)) { iconIn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.easeInOut(duration: 0.25)) { titleShow = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeIn(duration: 0.35)) { fade = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onFinish() }
            }
            return
        }

        // 1) 잎이 돋아난다
        withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { leafIn = true }

        // 2) 잎 주위로 원이 퍼진다
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.85)) { ripple = true }
        }

        // 3) 그 원이 돌아와 흰 원판 + 금색 링(= 아이콘)으로 정착
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { iconIn = true }
        }

        // 4) 타이틀
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeInOut(duration: 0.4)) { titleShow = true }
        }

        // 5) 페이드아웃 → 완료
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.4)) { fade = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onFinish() }
        }
    }
}
