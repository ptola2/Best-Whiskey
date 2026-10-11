import SwiftUI
#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseCore
#endif

@main
struct WaterFastingApp: App {
    init() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        // Cloud backup switches on only when GoogleService-Info.plist is in the app bundle.
        if FirebaseApp.app() == nil, Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
    }
}
