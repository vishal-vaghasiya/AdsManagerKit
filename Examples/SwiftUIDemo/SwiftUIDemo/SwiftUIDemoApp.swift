import AdsManagerKit
import SwiftUI

@main
struct SwiftUIDemoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false
    
    var body: some Scene {
        WindowGroup {
            MenuView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                wasInBackground = true
            case .active:
                guard wasInBackground else { return }
                wasInBackground = false
                AdsManager.shared.showAppOpenAdIfAvailable()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
