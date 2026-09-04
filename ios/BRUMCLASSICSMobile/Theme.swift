import SwiftUI

enum BrumTheme {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.047)
    static let deepBackground = Color(red: 0.012, green: 0.016, blue: 0.020)
    static let surface = Color(red: 0.067, green: 0.075, blue: 0.090)
    static let elevated = Color(red: 0.090, green: 0.102, blue: 0.122)
    static let primary = Color(red: 0.616, green: 1.000, blue: 0.231)
    static let text = Color(red: 0.961, green: 0.965, blue: 0.973)
    static let muted = Color(red: 0.459, green: 0.482, blue: 0.525)
    static let line = Color.white.opacity(0.11)
}

struct BrumLogo: View {
    var compact = false
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).stroke(BrumTheme.primary, lineWidth: 3)
                Rectangle().fill(BrumTheme.primary).frame(height: 4).offset(y: 13)
                HStack(spacing: 3) { ForEach(0..<4, id: \.self) { _ in Rectangle().fill(BrumTheme.primary).frame(width: 3, height: 6) } }.offset(y: 18)
            }.frame(width: 38, height: 32)
            if !compact { Text("BRUMCLASSICS").font(.system(size: 18, weight: .black, design: .rounded)).tracking(1.4).foregroundStyle(BrumTheme.text) }
        }.accessibilityElement(children: .ignore).accessibilityLabel("BRUMCLASSICS")
    }
}

struct BrumSectionLabel: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 11, weight: .bold)).tracking(1.8).foregroundStyle(BrumTheme.muted) }
}

struct BrumCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(16).background(BrumTheme.surface).overlay(RoundedRectangle(cornerRadius: 14).stroke(BrumTheme.line)).clipShape(RoundedRectangle(cornerRadius: 14)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .black)).tracking(1).foregroundStyle(Color.black).frame(maxWidth: .infinity).padding(.vertical, 14).background(BrumTheme.primary.opacity(configuration.isPressed ? 0.72 : 1)).clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
