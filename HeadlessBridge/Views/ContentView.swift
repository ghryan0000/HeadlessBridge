import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var manager: ConnectionManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("連線", systemImage: "display")
                }
                .tag(0)
            
            DiagnosticView()
                .tabItem {
                    Label("診斷", systemImage: "stethoscope")
                }
                .tag(1)
            
            HistoryView()
                .tabItem {
                    Label("記錄", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
