// FamilyShareScreen.swift
// BabyLog — 조부모/가족 사진 공유
//
// 사용자 본인 iCloud(사진 앱)를 이용해 무료로 손주 사진을 공유한다. 우리 서버 비용 0.
//  · 아이폰 조부모: iCloud 공유 앨범 구독 → 사진 앱에서 큰 사진으로 봄
//  · 안드로이드 조부모: 공유 앨범 '공개 웹사이트' 링크 → 브라우저로 봄(Apple ID 불필요)
// 앱은 '사진 앱 전용 앨범에 담기 + 단계 안내'까지 돕는다(공개 링크 생성 API는 iOS 미제공).

import SwiftUI
import UIKit

struct FamilyShareScreen: View {
    @EnvironmentObject private var store: AppStore

    @State private var exporting = false
    @State private var didExport = false
    @State private var resultMsg: String? = nil
    @State private var quickImages: [UIImage] = []
    @State private var showQuickShare = false

    private var child: Child? { store.selectedChild }
    private var albumName: String? { child.map { "베이비로그 · \($0.name)" } }

    /// 선택 아이의 모든 사진(프로필 + 다이어리, 오래된→최신, 중복 제거).
    private var photoRefs: [String] {
        guard let cid = child?.id else { return [] }
        var refs: [String] = []
        if let p = child?.profileImageRef { refs.append(p) }
        let entries = store.diaryEntries.filter { $0.childId == cid }.sorted { $0.date < $1.date }
        for e in entries { refs.append(contentsOf: e.photoRefList) }
        var seen = Set<String>()
        return refs.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s5) {
                BLScreenHeader(title: "가족과 사진 공유", eyebrow: "조부모님도 함께")

                if photoRefs.isEmpty {
                    BLEmptyState(icon: "photo.on.rectangle.angled",
                                 title: "공유할 사진이 아직 없어요",
                                 message: "기록 탭에서 아이 사진을 남기면 여기서 가족과 공유할 수 있어요.")
                } else {
                    introCard
                    photoSummaryCard
                    exportCard
                    if didExport { iphoneGuideCard; androidGuideCard }
                    quickShareCard
                }
            }
            .padding(.horizontal, Spacing.s5)
            .padding(.top, Spacing.s2)
            .padding(.bottom, Spacing.s8)
        }
        .background(AppColors.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showQuickShare) {
            FamilyShareSheet(activityItems: quickImages)
        }
    }

    // MARK: - 소개

    private var introCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("내 iCloud로 무료 공유")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: {
                    Image(systemName: "icloud.and.arrow.up.fill").foregroundStyle(AppColors.primary)
                }
                Text("사진은 내 iCloud(사진 앱)에만 올라가고, 우리 서버를 거치지 않아요. 조부모님이 아이폰이든 안드로이드든 모두 볼 수 있습니다.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
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
                    Text("사진 \(photoRefs.count)장")
                        .font(AppFont.num(13)).foregroundStyle(AppColors.ink3)
                }
                let preview = Array(photoRefs.suffix(6).reversed())
                HStack(spacing: Spacing.s2) {
                    ForEach(preview, id: \.self) { ref in
                        if let img = PhotoStore.image(ref) {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        }
                    }
                    if photoRefs.count > 6 {
                        Text("+\(photoRefs.count - 6)")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(AppColors.ink3)
                            .frame(width: 48, height: 48)
                            .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 사진 앱에 담기

    private var exportCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("1단계 · 사진 앱 앨범에 담기")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("아이 사진을 사진 앱의 ‘\(albumName ?? "베이비로그")’ 앨범에 모아둬요. 이게 공유 앨범의 재료가 됩니다.")
                    .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)

                Button { doExport() } label: {
                    HStack(spacing: Spacing.s2) {
                        if exporting { ProgressView().tint(.white) }
                        Image(systemName: "rectangle.stack.badge.plus")
                        Text(exporting ? "담는 중…" : "사진 앱 앨범에 담기")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                }
                .buttonStyle(LiquidPressStyle(scale: 0.98))
                .disabled(exporting)

                if let msg = resultMsg {
                    Text(msg)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(didExport ? AppColors.primary : AppColors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if didExport {
                    Button { openPhotosApp() } label: {
                        HStack(spacing: Spacing.s2) {
                            Image(systemName: "photo.fill.on.rectangle.fill")
                            Text("사진 앱 열기")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.primary)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 조부모 안내 (아이폰)

    private var iphoneGuideCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("조부모님이 아이폰을 쓰면").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: { Image(systemName: "apple.logo").foregroundStyle(AppColors.ink) }
                guideStep(1, "사진 앱에서 ‘\(albumName ?? "베이비로그")’ 앨범을 열어요.")
                guideStep(2, "공유 버튼 → ‘공유 앨범에 추가’로 새 공유 앨범을 만들어요.")
                guideStep(3, "조부모님을 구성원으로 초대하면, 사진 앱에서 자동으로 큰 사진을 보세요.")
            }
        }
    }

    // MARK: - 조부모 안내 (안드로이드)

    private var androidGuideCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Label {
                    Text("조부모님이 안드로이드를 쓰면").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                } icon: { Image(systemName: "globe").foregroundStyle(AppColors.primary) }
                guideStep(1, "위에서 만든 공유 앨범 설정에서 ‘공개 웹사이트’를 켜요.")
                guideStep(2, "생성된 웹 주소를 복사해 카카오톡 등으로 조부모님께 보내요.")
                guideStep(3, "조부모님은 안드로이드·PC 브라우저로 열어서 봐요. Apple ID도 필요 없어요.")
                Text("※ Apple 정책상 공개 링크는 앱이 자동으로 만들 수 없어, 사진 앱에서 한 번만 켜시면 됩니다.")
                    .font(.system(size: 11.5, weight: .regular)).foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
    }

    // MARK: - 빠른 공유

    private var quickShareCard: some View {
        BLCard {
            VStack(alignment: .leading, spacing: Spacing.s3) {
                Text("바로 몇 장만 보내기").font(.system(size: 15, weight: .bold)).foregroundStyle(AppColors.ink)
                Text("앨범을 만들지 않고, 최근 사진을 카카오톡·메시지나 iCloud 링크로 바로 보낼 수도 있어요.")
                    .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Button { prepareQuickShare() } label: {
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "square.and.arrow.up")
                        Text("최근 사진 바로 공유")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(AppColors.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(AppColors.line, lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func guideStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s3) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(AppColors.primary, in: Circle())
            Text(text)
                .font(.system(size: 13, weight: .regular)).foregroundStyle(AppColors.ink2)
                .fixedSize(horizontal: false, vertical: true).lineSpacing(2)
            Spacer(minLength: 0)
        }
    }

    private func exportedKey() -> String { "bl_family_exported_\(child?.id.uuidString ?? "none")" }

    private func doExport() {
        guard let name = albumName else { return }
        let refs = photoRefs
        let skip = Set(UserDefaults.standard.stringArray(forKey: exportedKey()) ?? [])
        exporting = true; resultMsg = nil
        Task {
            defer { exporting = false }
            do {
                let (added, exported) = try await FamilyPhotoExporter.export(refs: refs, albumName: name, skip: skip)
                var set = skip; exported.forEach { set.insert($0) }
                UserDefaults.standard.set(Array(set), forKey: exportedKey())
                didExport = true
                resultMsg = added > 0
                    ? "사진 \(added)장을 ‘\(name)’ 앨범에 담았어요. 아래 안내대로 공유 앨범을 만들면 됩니다."
                    : "이미 모든 사진이 ‘\(name)’ 앨범에 담겨 있어요. 아래 안내대로 공유하면 됩니다."
                Haptics.success()
            } catch FamilyPhotoExporter.ExportError.noPermission {
                resultMsg = "사진 접근 권한이 필요해요. 설정 > 베이비로그 > 사진에서 ‘추가’ 또는 ‘전체’를 허용해 주세요."
                Haptics.warning()
            } catch {
                resultMsg = "사진을 담는 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요."
                Haptics.warning()
            }
        }
    }

    private func prepareQuickShare() {
        // 최근 사진 최대 20장만(공유 시트 메모리 보호)
        let recent = Array(photoRefs.suffix(20).reversed())
        quickImages = recent.compactMap { PhotoStore.image($0) }
        guard !quickImages.isEmpty else { return }
        showQuickShare = true
    }

    private func openPhotosApp() {
        if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
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
