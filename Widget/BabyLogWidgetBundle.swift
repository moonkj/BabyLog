// BabyLogWidgetBundle.swift — BabyLog Widget Extension
// WidgetBundle 진입점 (@main)
// Bundle ID: com.vibelab.babylog.widget
// Deployment Target: iOS 17.0+

import WidgetKit
import SwiftUI

@main
struct BabyLogWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyLogWidget()
        // 추후 위젯 추가 시 이곳에 나열
        // e.g. BabyLogLockScreenWidget()
    }
}
