import SwiftUI

@main
struct HeadlessBridgeApp: App {
    @StateObject private var connectionManager = ConnectionManager()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectionManager)
        }
        .onChange(of: scenePhase) { newPhase in
            connectionManager.handleScenePhase(newPhase)
        }
    }
}
