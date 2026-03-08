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
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    // Intercepting navigation to warn about unsaved changes
    @State private var intendedDestination: SidebarItem? = nil
    @State private var showUnsavedChangesAlert = false
    
    // Bindings
    var sidebarBinding: Binding<SidebarItem?> {
        Binding(
            get: { selectedSidebarItem },
            set: { newValue in
                guard let newValue = newValue, newValue != selectedSidebarItem else { return }
                if manager.hasUnsavedChanges {
                    intendedDestination = newValue
                    showUnsavedChangesAlert = true
                } else {
                    selectedSidebarItem = newValue
                    selectedTab = newValue
                }
            }
        )
    }
    
    var tabBinding: Binding<SidebarItem> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                guard newValue != selectedTab else { return }
                if manager.hasUnsavedChanges {
                    intendedDestination = newValue
                    showUnsavedChangesAlert = true
                } else {
                    selectedTab = newValue
                    selectedSidebarItem = newValue
                }
            }
        )
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            if sizeClass == .regular {
                // iPad Layout with Split View + Floating Pill
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarContent(selectedItem: sidebarBinding, columnVisibility: $columnVisibility)
                        .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 350)
                } detail: {
                    ZStack(alignment: .top) {
                        if let item = selectedSidebarItem {
                            item.destination(for: item, sidebarSelection: $selectedSidebarItem, tabSelection: $selectedTab)
                                .safeAreaInset(edge: .top) {
                                    Color.clear.frame(height: columnVisibility == .detailOnly ? 140 : 20)
                                }
                                .ignoresSafeArea(.container, edges: .top)
                        } else {
                            Text("請從側邊欄選擇功能")
                                .foregroundStyle(.secondary)
                        }
                        
                        // Apple Podcasts Style Centered Navigation Pill (Only shows when sidebar is hidden)
                        if columnVisibility == .detailOnly {
                            HStack {
                                Spacer()
                                NavigationPill(
                                    selectedItem: Binding(
                                        get: { selectedSidebarItem ?? .home },
                                        set: { newValue in
                                            guard newValue != selectedSidebarItem else { return }
                                            if manager.hasUnsavedChanges {
                                                intendedDestination = newValue
                                                showUnsavedChangesAlert = true
                                            } else {
                                                selectedSidebarItem = newValue
                                                selectedTab = newValue
                                            }
                                        }
                                    ),
                                    columnVisibility: $columnVisibility
                                )
                                Spacer()
                            }
                            .padding(.top, 0)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            } else {
                // iPhone TabView Layout
                TabView(selection: tabBinding) {
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
        .alert("尚未儲存設定", isPresented: $showUnsavedChangesAlert) {
            Button("繼續編輯", role: .cancel) { }
            Button("捨棄變更", role: .destructive) {
                // 回復原狀(清除 flags) 並執行原本的跳頁
                manager.hasUnsavedChanges = false
                if let next = intendedDestination {
                    selectedSidebarItem = next
                    selectedTab = next
                }
            }
        } message: {
            Text("您的連線參數已修改但尚未儲存，若現在離開，將遺失這些變更。")
        }
    }
}

// MARK: - Sidebar Content
struct SidebarContent: View {
    @Binding var selectedItem: SidebarItem?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Removed custom toggle, using system sidebar button
            
            // Menu items moved up
            
            // Main List with Podcasts Style selection
            List(SidebarItem.allCases, selection: $selectedItem) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                    Text(item.title)
                        .font(.system(size: 17, weight: .medium))
                    Spacer()
                }
                .musicSidebarStyle(isSelected: selectedItem == item)
                .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onTapGesture {
                    selectedItem = item
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            Spacer()
            
            // Bottom Profile
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.gray)
                Text("Ryan Chang")
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .background(
            ZStack(alignment: .trailing) {
                // Subtle gradient for depth
                LinearGradient(
                    colors: Theme.sidebarGradients,
                    startPoint: .leading,
                    endPoint: .trailing
                )
                
                // Fine separator line/shadow for distinction
                Rectangle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 0.5)
            }
        )
        .padding(.top, -10)
    }
}

// MARK: - Navigation Pill
struct NavigationPill: View {
    @Binding var selectedItem: SidebarItem
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    var body: some View {
        HStack(spacing: 15) {
            // Sidebar Toggle (Only shows when sidebar is hidden)
            if columnVisibility == .detailOnly {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        columnVisibility = .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Theme.musicRed) // Use Apple Music Red
                }
                .padding(.trailing, 10)
            }
            
            // Text-only Tabs
            HStack(spacing: 20) {
                ForEach(SidebarItem.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedItem = item
                        }
                    } label: {
                        Text(item.title)
                            .font(.system(size: 17, weight: .medium)) // Match sidebar font size
                            .foregroundStyle(selectedItem == item ? Theme.musicRed : .black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedItem == item ? Color.gray.opacity(0.1) : Color.clear)
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(GlassPillBackground())
    }
}

private struct SideBarPresentedKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isSideBarPresented: Bool {
        get { self[SideBarPresentedKey.self] }
        set { self[SideBarPresentedKey.self] = newValue }
    }
}
