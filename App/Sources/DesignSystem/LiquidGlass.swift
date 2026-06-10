import SwiftUI

extension View {
    /// iOS 26 네이티브 Liquid Glass. iOS 26 미만은 material로 폴백.
    /// 메뉴·시트·툴바·헤더 등 chrome 표면에 사용 (사용자 요청: "리퀴드 글래스 iOS26 느낌").
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = Radius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}
