// FamilyShareScreen.swift
// BabyLog — 조부모/가족 사진 공유
//
// 사용자 본인 iCloud '공유 앨범'으로 무료 공유. 핵심:
//  · iCloud '공유 앨범'은 iCloud 저장 용량을 쓰지 않는다(Apple 무료 제공) → 사용자가 iCloud를 추가 결제할 필요 없음.
//  · 우리 서버도 거치지 않는다 → 우리 비용 0 + '사진 서버 비전송' 원칙 유지.
//  · 아이폰 조부모: 공유 앨범 구독(사진 앱에서 큰 사진), 안드로이드 조부모: 공개 웹 링크(브라우저).
//
// 구현 방식: 공유 시트(UIActivityViewController) → '공유 앨범에 추가'.
// (사진을 일반 보관함에 저장하지 않으므로 iCloud 사진 용량을 소모하지 않는다. 공유 앨범은 별도 무료 저장.)
// ⚠️ iOS는 앱이 공유 앨범에 직접 쓰는 API를 막아둠 → 마지막 '추가' 탭은 사용자가 공유 시트에서 한다.

import SwiftUI
import UIKit

struct FamilyShareScreen: View {
    @EnvironmentObject private var store: AppStore

    @State private var shareItems: [Any] = []
    @State private var showShare = false

    private var child: Child? { store.selectedChild }

    /// 선택 아이의 모든 사진(프로필 + 다이어리, 오래된→최신, 중복 제거) — 로컬 파일 URL.
    private var photoURLs: [URL] {
        guard let cid = child?.id else { return [] }
        var refs: [String] = []
        if let p = child?.profileImageRef { refs.append(p) }
        let entries = store.diaryEntries.filter { $0.childId == cid }.sorted { $0.date < $1.date }
        for e in entries { refs.append(contentsOf: e.photoRefList) }
        var seen = Set<String>()
        let unique = refs.filter { seen.insert($0).inserted }
        let fm = FileManager.default
        return unique.compactMap { ref in
            let url = PhotoStore.photosDirectory.appendingPathComponent(ref)
            return fm.fileExists(atPath: url.path) ? url : nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                BLScreenHeader(title: "가족과 사진 공유", eyebrow: "조부모님도 함께")

                if photoURLs.isEmpty {
                    BLEmptyState(icon: "photo.on.rectangle.angled",
                                 title: "공유할 사진이 아직 없어요",
                                 message: "기록 탭에서 아이 사진을 남기면 여기서 가족과 공유할 수 있어요.")
                } else {
                    introCard
                    photoSummaryCard
                    prerequisiteCard
                    shareCard
                    iphoneGuideCard
                    androidGuideCard
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) {
            FamilyShareSheet(activityItems: shareItems)
        }
    }

    // MARK: - 소개 (비용 정직)

    private var introCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("추가 결제 없이 무료 공유")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(AppColors.primary)
                }
                bullet("iCloud ‘공유 앨범’은 iCloud 저장 용량을 쓰지 않아요 — Apple이 무료로 제공합니다. iCloud를 추가로 결제할 필요가 없어요.")
                bullet("사진은 우리 서버를 거치지 않아요. 조부모님이 아이폰이든 안드로이드든 모두 볼 수 있어요.")
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s2) {
            Image(systemName: "circle.fill").font(.system(size: 5))
                .foregroundStyle(AppColors.ink3).padding(.top, 7).accessibilityHidden(true)
            Text(text)
                .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
        }
    }

    // MARK: - 사진 요약 + 미리보기

    private var photoSummaryCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                HStack {
                    Text(child?.name ?? "우리 아이")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                    Spacer()
                    Text("사진 \(photoURLs.count)장")
                        .font(AppFont.num(13)).foregroundStyle(AppColors.ink3)
                }
                let preview = Array(photoURLs.suffix(6).reversed())
                HStack(spacing: Spacing.s2) {
                    ForEach(preview, id: \.self) { url in
                        if let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        }
                    }
                    if photoURLs.count > 6 {
                        Text("+\(photoURLs.count - 6)")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColors.ink3)
                            .frame(width: 48, height: 48)
                            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 준비(공유 앨범 켜기)

    private var prerequisiteCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s2) {
                Label {
                    Text("준비 · ‘공유 앨범’ 켜기 (한 번만)")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: { Image(systemName: "gearshape.fill").foregroundStyle(AppColors.ink3) }
                guideStep(1, "아이폰 ‘설정’ 앱을 열어요.")
                guideStep(2, "‘앱’을 누른 뒤 목록에서 ‘사진’을 찾아 들어가요. (이전 iOS는 ‘설정’에서 바로 ‘사진’이 보이기도 해요.)")
                guideStep(3, "‘공유 앨범’ 스위치를 켜요(초록색).")
                Text("이게 꺼져 있으면 아래 공유 화면에 ‘공유 앨범에 추가’ 항목이 안 보여요.")
                    .font(.system(size: 11.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
    }

    // MARK: - 공유하기

    private var shareCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("공유 앨범에 추가하기")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("아래 버튼 → ‘공유 앨범에 추가’를 누르면 됩니다. 처음엔 새 공유 앨범을 만들고, 다음부턴 같은 앨범을 골라 사진만 더하면 돼요. 링크는 그대로라 다시 보낼 필요 없어요.")
                    .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                Button { startShare() } label: {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "rectangle.stack.badge.person.crop.fill")
                        Text("공유 앨범에 추가")
                    }
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))

                Text("‘공유 앨범’ 항목이 안 보이면 설정 > 사진 > 공유 앨범을 켜주세요. 최근 사진부터 한 번에 최대 200장씩 추가돼요.")
                    .font(.system(size: 11.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 조부모 안내

    private var iphoneGuideCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("조부모님이 아이폰을 쓰면 — 구성원 초대").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: { Image(systemName: "apple.logo").foregroundStyle(AppColors.ink) }
                Text("처음 한 번 공유 앨범을 만들면서 조부모님을 초대하면 돼요.")
                    .font(.system(size: 12.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                guideStep(1, "위 ‘공유 앨범에 추가’를 누르면 나오는 화면에서, ‘공유 앨범:’ 줄을 눌러 ‘새 공유 앨범…’을 골라요.")
                guideStep(2, "앨범 이름(예: ‘라온이 앨범’)을 적고 오른쪽 위 ‘다음’을 눌러요.")
                guideStep(3, "‘받는 사람’ 칸에 조부모님 전화번호나 Apple ID 이메일을 입력하고 ‘만들기’ → 마지막으로 ‘게시’를 눌러요.")
                guideStep(4, "조부모님 아이폰에 초대 알림이 가요. ‘수락’하면 그분들 사진 앱 > ‘앨범’ 탭 > ‘공유 앨범’에 자동으로 나타나고, 이후 새 사진도 자동 표시돼요.")
                Text("나중에 더 초대하려면: 사진 앱 > ‘앨범’ 탭 > 아래 ‘공유 앨범’에서 그 앨범 열기 > 오른쪽 위 ‘사람 모양 아이콘’ > ‘사람 초대’.")
                    .font(.system(size: 11.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
    }

    private var androidGuideCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("조부모님이 안드로이드를 쓰면 — 웹 링크").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: { Image(systemName: "globe").foregroundStyle(AppColors.primary) }
                Text("공유 앨범의 ‘공개 웹사이트’를 켜고 그 링크를 보내면 돼요.")
                    .font(.system(size: 12.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                guideStep(1, "사진 앱을 열고 화면 아래 ‘앨범’ 탭을 눌러요.")
                guideStep(2, "아래로 내려 ‘공유 앨범’ 칸에서 만든 앨범을 열어요.")
                guideStep(3, "오른쪽 위 ‘사람 모양 아이콘’(없으면 ‘⋯’)을 눌러 앨범 설정을 열어요.")
                guideStep(4, "‘공개 웹사이트’ 스위치를 켜요(초록색).")
                guideStep(5, "바로 아래 생긴 ‘링크 공유’를 눌러 카카오톡 등으로 조부모님께 주소를 보내요.")
                guideStep(6, "조부모님은 안드로이드·PC 브라우저로 그 주소를 열면 사진을 봐요(Apple ID·로그인 불필요). 늘 같은 주소로 최신 사진이 보여요.")
                Text("※ Apple 정책상 공개 링크는 앱이 자동으로 만들 수 없어, 사진 앱에서 위 단계를 한 번만 해주시면 됩니다.")
                    .font(.system(size: 11.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
    }

    // MARK: - Helpers

    private func guideStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(AppColors.primary, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
            Spacer(minLength: 0)
        }
    }

    private func startShare() {
        // 최근 200장(공유 앨범 1회 추가 한도 고려). 파일 URL이라 메모리 부담 적음.
        shareItems = Array(photoURLs.suffix(200))
        guard !shareItems.isEmpty else { return }
        Haptics.light()
        showShare = true
    }
}

// MARK: - Share Sheet

private struct FamilyShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
