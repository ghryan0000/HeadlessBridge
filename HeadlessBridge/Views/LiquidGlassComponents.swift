import SwiftUI

// MARK: - Liquid Glass Modifiers
struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var opacity: Double = 0.1
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, opacity: Double = 0.1) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, opacity: opacity))
    }
}

// MARK: - Premium UI Components
struct GlassSectionHeader: View {
    let title: String
    let icon: String
    var iconColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Color.primary.opacity(0.7))
            
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
}

struct GlassButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    var color: Color = .blue
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color)
                    .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Podcasts-style Components
struct GlassPillBackground: View {
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 8)
    }
}

struct SidebarItemStyle: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .foregroundStyle(isSelected ? .blue : .primary)
    }
}

extension View {
    func sidebarItemStyle(isSelected: Bool) -> some View {
        self.modifier(SidebarItemStyle(isSelected: isSelected))
    }
}

// MARK: - Podcasts Specific Styles
struct PodcastsSidebarItemStyle: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color(white: 0.9) : Color.clear)
            )
            .foregroundStyle(isSelected ? Color(red: 0.61, green: 0.35, blue: 0.82) : .primary) // Podcasts Purple
    }
}

extension View {
    func podcastsSidebarStyle(isSelected: Bool) -> some View {
        self.modifier(PodcastsSidebarItemStyle(isSelected: isSelected))
    }
}
