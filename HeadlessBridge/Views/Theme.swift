import SwiftUI

struct Theme {
    static let musicRed = Color(red: 250/255, green: 36/255, blue: 60/255) // FA243C
    static let musicRedLight = musicRed.opacity(0.12)
    
    static let sidebarGray = Color(white: 0.98)
    static let detailGray = Color(white: 1.0)
    
    // Gradient levels for sidebar depth
    static let sidebarGradients: [Color] = [
        Color(white: 1.0),
        Color(white: 0.98),
        Color(white: 0.97)
    ]
}
