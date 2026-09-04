import SwiftUI
import UIKit

struct GameCoverView: View {
    @EnvironmentObject private var store: AppStore
    let game: Game
    var cornerRadius: CGFloat = 12
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(colors: [BrumTheme.elevated, BrumTheme.deepBackground], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity.animation(.easeOut(duration: 0.18)))
            } else {
                VStack(spacing: 10) {
                    BrumLogo(compact: true).opacity(0.55)
                    Text(game.platform.uppercased()).font(.caption2.bold()).tracking(1.5).foregroundStyle(BrumTheme.muted)
                }
            }
            VStack { HStack { Text(game.isClassic ? game.platform.uppercased() : game.store.uppercased()).font(.caption2.bold()).tracking(1.4).padding(8).foregroundStyle(.white); Spacer() }; Spacer() }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(BrumTheme.line))
        .task(id: game.artworkPath) { image = await store.image(for: game) }
    }
}

struct GameTile: View {
    let game: Game
    var body: some View {
        Button { AppHaptics.select(); NotificationCenter.default.post(name: .openGame, object: game) } label: {
            VStack(alignment: .leading, spacing: 8) {
                GameCoverView(game: game).aspectRatio(0.72, contentMode: .fit)
                Text(game.title).font(.system(size: 15, weight: .bold)).foregroundStyle(BrumTheme.text).lineLimit(2).multilineTextAlignment(.leading)
                Text(game.statusLabel).font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(game.wantToPlay ? BrumTheme.primary : BrumTheme.muted)
            }
        }.buttonStyle(.plain)
    }
}

enum AppHaptics {
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

extension Notification.Name { static let openGame = Notification.Name("brum.open-game") }
