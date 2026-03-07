import SwiftUI

// MARK: - Navigation Item
enum SidebarItem: String, CaseIterable, Identifiable {
    case home, settings, toolbox
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .home: return "連線至 Mac"
        case .settings: return "設定連線參數"
        case .toolbox: return "工具箱"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "display"
        case .settings: return "gearshape.fill"
        case .toolbox: return "archivebox.fill"
        }
    }
    
    @ViewBuilder
    func destination(for item: SidebarItem, sidebarSelection: Binding<SidebarItem?>, tabSelection: Binding<SidebarItem>) -> some View {
        switch item {
        case .home: HomeView()
        case .settings: SettingsView()
        case .toolbox: ToolboxView()
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var manager: ConnectionManager
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var selectedSidebarItem: SidebarItem? = .home
    @State private var selectedTab = SidebarItem.home
    
    var body: some View {
        if sizeClass == .regular {
            // iPad Sidebar Layout
            NavigationSplitView {
                List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                    NavigationLink(value: item) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 400)
            } detail: {
                if let item = selectedSidebarItem {
                    item.destination(for: item, sidebarSelection: $selectedSidebarItem, tabSelection: $selectedTab)
                } else {
                    Text("請從側邊欄選擇功能")
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // iPhone TabView Layout
            TabView(selection: $selectedTab) {
                ForEach(SidebarItem.allCases) { item in
                    item.destination(for: item, sidebarSelection: $selectedSidebarItem, tabSelection: $selectedTab)
                        .tabItem {
                            Label(item.title, systemImage: item.icon)
                        }
                        .tag(item)
                }
            }
            .tint(.blue)
        }
    }
}
