import SwiftUI

// MARK: - BLEmptyState
// DESIGN.md §10.1 — 빈 상태는 이 앱 UX의 숨은 핵심.
// 죄책감/부정 공백 금지. 권유형 카피, 따뜻한 일러스트(SF Symbol 대형).
// 색+아이콘+레이블 3중 인코딩 (§11.1). 터치 타깃 44pt 이상.

struct BLEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    // 빈 상태 아이콘에 부드러운 부유 모션 (DESIGN.md §8.4 — 빈 상태 둥실)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    var body: some View {
        VStack(spacing: Spacing.s6) {
            // 대형 SF Symbol 일러스트 영역
            ZStack {
                // 따뜻한 배경 원형
                Circle()
                    .fill(AppColors.primaryTint)
                    .frame(width: 96, height: 96)

                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    // 색+아이콘 2중 (텍스트가 3중 완성)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true) // 타이틀/메시지로 의미 전달
            }
            .offset(y: (!reduceMotion && floating) ? -6 : 0)
            .animation(
                reduceMotion ? nil :
                    .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                value: floating
            )
            .onAppear { floating = true }
            .onDisappear { floating = false }

            // 텍스트 블록
            VStack(spacing: Spacing.s2) {
                Text(title)
                    .font(AppFont.title)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, Spacing.s7)

            // 옵셔널 CTA
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(actionTitle)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(AppColors.primary)
                    .padding(.horizontal, Spacing.s6)
                    .frame(minHeight: 44) // 44pt 터치 타깃
                    .background(AppColors.primarySoft, in: Capsule())
                }
                .buttonStyle(LiquidPressStyle(scale: 0.97))
                .accessibilityLabel(actionTitle)
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.vertical, Spacing.s9)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

// MARK: - BLSampleNote
// 키/백엔드 미연동으로 샘플 데이터를 보여줄 때의 정직한 안내 배너.
// "안 되는 것"이 아니라 "곧 실제 정보로 채워질" 상태임을 알린다.

struct BLSampleNote: View {
    var message: String = "지금은 샘플 데이터예요. 곧 우리 동네 실제 정보로 채워질 거예요."

    var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.primary)
                .accessibilityHidden(true)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppColors.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s2)
        .background(AppColors.primaryTint, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("안내: \(message)")
    }
}

// MARK: - BLExpectationState
// DESIGN.md §10.1 — 콜드스타트형 변형 (기대감 UI).
// SPEC.md 14.5(기능 13.5) — 진행바·대기명단·오픈알림으로 부정적 공백 대체.

struct BLExpectationState: View {
    let progress: Double          // 0.0 ~ 1.0
    let title: String
    let message: String
    let ctaTitle: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0
    @State private var pulse = false

    private var progressPercent: Int { Int(progress * 100) }

    var body: some View {
        VStack(spacing: Spacing.s6) {
            // 아이콘 + 진행 링 오버레이
            ZStack {
                Circle()
                    .fill(AppColors.primaryTint)
                    .frame(width: 96, height: 96)

                // 진행 아크
                Circle()
                    .trim(from: 0, to: reduceMotion ? progress : animatedProgress)
                    .stroke(
                        AppColors.primary,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .scaleEffect((!reduceMotion && pulse) ? 1.07 : 1)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: pulse
                    )
            }
            .onAppear {
                pulse = true
                if !reduceMotion {
                    withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                        animatedProgress = progress
                    }
                } else {
                    animatedProgress = progress
                }
            }

            // 텍스트 블록
            VStack(spacing: Spacing.s2) {
                Text(title)
                    .font(AppFont.title)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, Spacing.s7)

            // 진행 바 + 퍼센트 (색+수치+텍스트 3중)
            VStack(alignment: .leading, spacing: Spacing.s2) {
                HStack {
                    // 색+아이콘 — 퍼센트 레이블이 3중 완성
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppColors.primary)
                        .accessibilityHidden(true)
                    Text("우리 동네 \(progressPercent)% 준비됨")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink2)
                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .fill(AppColors.surface3)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: Radius.pill, style: .continuous)
                            .fill(AppColors.primary)
                            .frame(
                                width: geo.size.width * (reduceMotion ? progress : animatedProgress),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, Spacing.s7)
            .accessibilityLabel("준비 진행률 \(progressPercent)퍼센트")
            .accessibilityValue("\(progressPercent)%")

            // 오픈 알림 CTA (LiquidButton)
            LiquidButton(fill: AppColors.primary, action: {}) {
                HStack(spacing: Spacing.s2) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .accessibilityHidden(true)
                    Text(ctaTitle)
                }
            }
            .padding(.horizontal, Spacing.s7)
            .accessibilityLabel(ctaTitle)
            .accessibilityAddTraits(.isButton)
        }
        .padding(.vertical, Spacing.s9)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BLSkeleton
// DESIGN.md §10.2 — shimmer 애니메이션 플레이스홀더.
// reduceMotion 대응: 정적 grey 유지. transform/opacity만 사용 → 60fps 보장.

/// Shimmer 그라디언트 Phase 소스 (캔버스 상대 좌표)
private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        let w = geo.size.width
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.55), location: 0.45),
                                .init(color: .white.opacity(0.55), location: 0.55),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: w * 0.5)
                        .offset(x: phase * w * 1.5)
                        .animation(
                            .linear(duration: 1.5).repeatForever(autoreverses: false),
                            value: phase
                        )
                    }
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                phase = 1.2
            }
    }
}

extension View {
    fileprivate func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// 기본 스켈레톤 블록 — 너비/높이/radius 자유 지정
struct BLSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Radius.xs

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.surface3)
            .frame(width: width, height: height)
            .shimmer()
            .accessibilityHidden(true)
    }
}

/// 리스트 행 형태 스켈레톤 — 아이콘 + 2줄 텍스트
struct BLSkeletonRow: View {
    var body: some View {
        HStack(spacing: Spacing.s4) {
            // 아바타/아이콘 자리
            BLSkeleton(width: 44, height: 44, cornerRadius: Radius.sm)

            VStack(alignment: .leading, spacing: Spacing.s2) {
                // 제목 줄
                BLSkeleton(height: 14, cornerRadius: Radius.xs)
                    .frame(maxWidth: .infinity)

                // 보조 줄 (70% 너비)
                HStack {
                    BLSkeleton(height: 12, cornerRadius: Radius.xs)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                // 70% 너비 구현: 오른쪽 30% 빈 공간
                .overlay(
                    GeometryReader { geo in
                        Color.clear.frame(width: geo.size.width * 0.3)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.s3)
        .padding(.horizontal, Spacing.s4)
        .accessibilityHidden(true)
    }
}

/// 카드 형태 스켈레톤 — 사진 + 텍스트 블록
struct BLSkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            // 사진 영역
            BLSkeleton(height: 160, cornerRadius: Radius.md)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Spacing.s2) {
                // 제목
                BLSkeleton(height: 15, cornerRadius: Radius.xs)
                    .frame(maxWidth: .infinity)

                // 설명 3줄 (100%, 80%, 60%)
                BLSkeleton(height: 12, cornerRadius: Radius.xs)
                    .frame(maxWidth: .infinity)

                HStack {
                    BLSkeleton(height: 12, cornerRadius: Radius.xs)
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 48) // 약 80% 너비

                HStack {
                    BLSkeleton(height: 12, cornerRadius: Radius.xs)
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 96) // 약 60% 너비
            }
            .padding(.horizontal, Spacing.s1)
        }
        .padding(Spacing.s4)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .blShadow(.card)
        .accessibilityHidden(true)
    }
}

// MARK: - BLErrorState
// DESIGN.md §10.3 — 에러는 사용자 탓이 아닌 친절한 톤.
// 따뜻한 일러스트·카피, 재시도 LiquidButton, 오프라인 안내.
// 색+아이콘+레이블 3중 인코딩, 44pt 터치 타깃.

struct BLErrorState: View {
    let message: String
    var retry: (() -> Void)? = nil

    // 가벼운 흔들기 모션 — DESIGN.md §8.5 에러 가벼운 흔들림
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakeOffset: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.s6) {
            // 아이콘 영역 — 위험색 대신 따뜻한 앰버 톤 (공포 조장 금지)
            ZStack {
                Circle()
                    .fill(AppColors.goldTint)
                    .frame(width: 96, height: 96)

                // 색(amber 배경)+아이콘+레이블 3중
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppColors.gold)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            .offset(x: shakeOffset)
            .onAppear {
                guard !reduceMotion, !appeared else { return }
                appeared = true
                // 부드러운 첫 등장 흔들림 (가볍게, 3회)
                withAnimation(.easeInOut(duration: 0.07).repeatCount(4, autoreverses: true)) {
                    shakeOffset = 5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        shakeOffset = 0
                    }
                }
            }

            // 텍스트 블록
            VStack(spacing: Spacing.s2) {
                Text("잠깐, 연결이 불안정해요")
                    .font(AppFont.title)
                    .foregroundStyle(AppColors.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppFont.callout)
                    .foregroundStyle(AppColors.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // 오프라인 안내 (인라인)
                HStack(spacing: Spacing.s1) {
                    // 아이콘 (색+아이콘+텍스트 3중)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .accessibilityHidden(true)
                    Text("저장된 기록은 오프라인에서도 볼 수 있어요")
                        .font(AppFont.caption)
                        .foregroundStyle(AppColors.ink3)
                }
                .padding(.top, Spacing.s1)
            }
            .padding(.horizontal, Spacing.s7)

            // 재시도 버튼 (LiquidButton)
            if let retry {
                LiquidButton(fill: AppColors.ink, action: retry) {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("다시 시도하기")
                    }
                }
                .padding(.horizontal, Spacing.s7)
                .accessibilityLabel("다시 시도하기")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.vertical, Spacing.s9)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("연결 오류. \(message). 저장된 기록은 오프라인에서도 볼 수 있어요.")
    }
}

// MARK: - Previews

#Preview("빈 상태 — 타임라인") {
    ScrollView {
        BLEmptyState(
            icon: "sparkles",
            title: "첫 순간을 담아볼까요?",
            message: "사진 한 장이면 충분해요.\n아이의 소중한 순간이 하나씩 쌓여갑니다.",
            actionTitle: "첫 기록 남기기",
            action: {}
        )
    }
    .background(AppColors.canvas)
}

#Preview("빈 상태 — 마켓") {
    ScrollView {
        BLEmptyState(
            icon: "tag.fill",
            title: "아직 올라온 매물이 없어요",
            message: "아이가 졸업한 물건을 나눠보세요.\n같은 동네 양육자가 기다리고 있을지도요.",
            actionTitle: "첫 매물 올리기",
            action: {}
        )
    }
    .background(AppColors.canvas)
}

#Preview("기대감 UI — 콜드스타트") {
    ScrollView {
        BLExpectationState(
            progress: 0.78,
            title: "우리 동네 크루 준비 중이에요",
            message: "조금만 더 모이면 열려요!\n친구를 초대하면 더 빨리 만날 수 있어요.",
            ctaTitle: "오픈 알림 받기"
        )
    }
    .background(AppColors.canvas)
}

#Preview("스켈레톤 — 리스트") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(0..<5) { _ in
                BLSkeletonRow()
                Divider().padding(.leading, 62)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .padding(.horizontal, Spacing.s4)
        .padding(.top, Spacing.s4)
    }
    .background(AppColors.canvas)
}

#Preview("스켈레톤 — 카드") {
    ScrollView {
        VStack(spacing: Spacing.s4) {
            BLSkeletonCard()
            BLSkeletonCard()
        }
        .padding(Spacing.s4)
    }
    .background(AppColors.canvas)
}

#Preview("에러 상태") {
    ScrollView {
        BLErrorState(
            message: "서버와 연결하는 중 문제가 생겼어요.\n잠시 후 다시 시도해 주세요.",
            retry: {}
        )
    }
    .background(AppColors.canvas)
}

#Preview("에러 — 재시도 없음") {
    ScrollView {
        BLErrorState(
            message: "네트워크가 연결되지 않았어요.\n연결 후 앱을 다시 열어보세요."
        )
    }
    .background(AppColors.canvas)
}
