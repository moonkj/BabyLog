import SwiftUI

@main
struct BabyLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .tint(AppColors.primary)
        }
    }
}
