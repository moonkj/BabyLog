// AppleLoginGate.swift
// BabyLog · 마켓·크루 작성/참여 전 로그인+닉네임 확보(신뢰·안전: 신상 특정, 운영자 추적).
// 둘러보기는 비로그인 허용. 작성/거래/채팅/참여는 이 게이트를 통과해야 한다.

import SwiftUI

/// 로그인 + 닉네임이 모두 준비됐는지(작성/참여 가능 상태).
enum LoginGate {
    /// 기본 닉네임("양육자님")이거나 비어 있으면 미설정으로 본다.
    static func nicknameSet() -> Bool {
        let n = (UserDefaults.standard.string(forKey: "bl_nickname") ?? "").trimmingCharacters(in: .whitespaces)
        return !n.isEmpty && n != "양육자님"
    }
    @MainActor static func ready() -> Bool { AuthStore.shared.isLoggedIn && nicknameSet() }
}

/// 로그인 + 닉네임 설정 시트. 둘 다 끝나면 onComplete 호출.
struct AppleLoginSheet: View {
    var message: String = "마켓·크루는 신뢰를 위해 로그인이 필요해요."
    var onComplete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth = AuthStore.shared
    @AppStorage("bl_nickname") private var nickname = "양육자님"
    @State private var nickField = ""
    @State private var needsNickname = false

    var body: some View {
        VStack(spacing: Spacing.s4) {
            Spacer(minLength: Spacing.s6)
            ZStack {
                Circle().fill(AppColors.primarySoft).frame(width: 72, height: 72)
                Image(systemName: needsNickname ? "person.text.rectangle" : "lock.shield.fill")
                    .font(.system(size: 32, weight: .semibold)).foregroundStyle(AppColors.primary)
            }.accessibilityHidden(true)

            if needsNickname {
                Text("이웃에게 보일 이름을 정해주세요").font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("마켓·크루에서 이 이름으로 표시돼요. 실명 대신 별명을 권장해요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, Spacing.s5)
                TextField("예: 시온파파, 망원동이웃", text: $nickField)
                    .font(AppFont.body).padding(.horizontal, Spacing.s4).frame(height: 50)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .padding(.horizontal, Spacing.s5)
                Button {
                    let t = nickField.trimmingCharacters(in: .whitespaces)
                    guard !t.isEmpty else { return }
                    nickname = String(t.prefix(20)); Haptics.success()
                    onComplete(); dismiss()
                } label: {
                    Text("완료").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }.buttonStyle(LiquidPressStyle(scale: 0.98))
                .disabled(nickField.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, Spacing.s5)
            } else {
                Text("로그인이 필요해요").font(.system(size: 18, weight: .bold)).foregroundStyle(AppColors.ink)
                Text(message + "\n신뢰할 수 있는 거래를 위해 신원을 확인해요.")
                    .font(.system(size: 13)).foregroundStyle(AppColors.ink2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, Spacing.s5)
                AppleSignInButton { ok in if ok { advanceAfterLogin() } }
                    .frame(height: 52).padding(.horizontal, Spacing.s5)
            }

            Button("나중에") { dismiss() }
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(AppColors.ink3).frame(height: 40)
            Spacer()
        }
        .frame(maxWidth: .infinity).background(AppColors.canvas.ignoresSafeArea())
        .presentationDetents([.height(needsNickname ? 420 : 360)])
        .onAppear { if auth.isLoggedIn && !LoginGate.nicknameSet() { needsNickname = true } }
    }

    private func advanceAfterLogin() {
        if LoginGate.nicknameSet() { onComplete(); dismiss() }
        else { withAnimation { needsNickname = true } }   // 닉네임 단계로
    }
}
