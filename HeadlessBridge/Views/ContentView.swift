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
    func destination(for item: SidebarItem, sidebarSelection: Binding<SidebarItem?>, tabSelection: Binding<SidebarItem>, columnVisibility: Binding<NavigationSplitViewVisibility>) -> some View {
        switch item {
        case .home: HomeView(columnVisibility: columnVisibility)
        case .settings: SettingsView(columnVisibility: columnVisibility)
        case .toolbox: ToolboxView(columnVisibility: columnVisibility)
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
                    if let item = selectedSidebarItem {
                        item.destination(for: item, sidebarSelection: $selectedSidebarItem, tabSelection: $selectedTab, columnVisibility: $columnVisibility)
                            .safeAreaInset(edge: .top) {
                                Color.clear.frame(height: columnVisibility == .detailOnly ? 106 : 20) // Pushed down by 1.1cm as requested
                            }
                            .ignoresSafeArea(.container, edges: .top)
                            .toolbar(.hidden, for: .navigationBar) // Explicitly hide to reclaim space
                    } else {
                        Text("請從側邊欄選擇功能")
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay(alignment: .top) {
                    // GLOBAL OVERLAY: Always captures touches, guaranteed interactivity
                    if columnVisibility == .detailOnly {
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
                        .padding(.top, 0) // Moved UP by 1cm as requested
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            } else {
                // iPhone TabView Layout
                TabView(selection: tabBinding) {
                    ForEach(SidebarItem.allCases) { item in
                        item.destination(for: item, sidebarSelection: $selectedSidebarItem, tabSelection: $selectedTab, columnVisibility: $columnVisibility)
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
    
    // Scale tracking for selection burst
    @State private var selectionScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 12) {
            // Sidebar Toggle (Only shows when sidebar is hidden)
            if columnVisibility == .detailOnly {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        columnVisibility = .all
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .regular))
                        .scaleEffect(1.5) // Scale up as requested
                        .foregroundStyle(Theme.musicRed)
                }
                .buttonStyle(PillButtonStyle())
                .padding(.trailing, 4)
            }
            
            // Vertical Icon + Text Tabs
            HStack(spacing: 10) {
                ForEach(SidebarItem.allCases) { item in
                    let isSelected = selectedItem == item
                    
                    Button {
                        if !isSelected {
                            // 1.5x Scale Burst Animation
                            selectionScale = 1.5
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                selectedItem = item
                            }
                            // Reset scale after short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                    selectionScale = 1.0
                                }
                            }
                        }
                    } label: {
                        VStack(spacing: 3) { // Reduced from 4
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: isSelected ? .bold : .medium)) // Reduced from 22 (approx 20%)
                            
                            Text(item.title)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                        }
                        .frame(minWidth: 90) // Ensure consistent width for vertical layout
                        .padding(.vertical, 7) // Reduced from 10
                        .foregroundStyle(isSelected ? Theme.musicRed : .primary.opacity(0.6))
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Theme.musicRed.opacity(0.15))
                                        .shadow(color: Theme.musicRed.opacity(0.25), radius: 6, x: 0, y: 3)
                                }
                            }
                        )
                    }
                    .buttonStyle(PillButtonStyle())
                    .scaleEffect(isSelected ? selectionScale : 1.0)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6) // Reduced from 8
        .background(GlassPillBackground())
    }
}

// MARK: - Pill Button Style (Handles intensified press animation)
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0) // Slightly more shrink
            .opacity(configuration.isPressed ? 0.6 : 1.0)     // Noticeable opacity change
            .brightness(configuration.isPressed ? 0.3 : 0)    // Intensified brightness (0.1 -> 0.3)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed) // Snappier spring
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
