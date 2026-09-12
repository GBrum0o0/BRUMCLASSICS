import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var store: AppStore

    private var center: MobileNotificationSnapshot { store.snapshot.notifications ?? .empty }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 7) {
                        BrumSectionLabel(text: "CENTRAL BRUM")
                        Text("Notificações").font(.system(size: 34, weight: .black)).foregroundStyle(BrumTheme.text)
                        Text("Conquistas, sessões, saves, instalações e avisos do launcher.")
                            .font(.subheadline).foregroundStyle(BrumTheme.muted)
                    }
                    Spacer(minLength: 12)
                    if center.unread > 0 {
                        Text("\(center.unread)").font(.headline.bold()).foregroundStyle(Color.black)
                            .frame(minWidth: 34, minHeight: 34).background(BrumTheme.primary).clipShape(Circle())
                    }
                }

                if center.unread > 0 {
                    Button { Task { await store.markAllNotificationsRead() } } label: {
                        Text("MARCAR TODAS COMO LIDAS").font(.caption.bold()).tracking(1.1)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent).tint(BrumTheme.primary).foregroundStyle(Color.black)
                    .disabled(store.connection != .online)
                }

                if center.entries.isEmpty {
                    BrumCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "bell.slash").font(.title).foregroundStyle(BrumTheme.primary)
                            Text("NENHUMA NOTIFICAÇÃO").font(.caption.bold()).tracking(1.2).foregroundStyle(BrumTheme.text)
                            Text(store.connection == .online ? "Quando algo importante acontecer no launcher, aparecerá aqui." : "Conecte-se ao launcher atualizado para sincronizar sua central.")
                                .font(.subheadline).foregroundStyle(BrumTheme.muted)
                        }
                    }
                } else {
                    ForEach(center.entries) { item in NotificationCard(item: item) }
                }
            }.padding(20)
        }
        .background(BrumTheme.background.ignoresSafeArea())
        .navigationTitle("NOTIFICAÇÕES")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.refresh() }
    }
}

private struct NotificationCard: View {
    @EnvironmentObject private var store: AppStore
    let item: MobileNotification

    var body: some View {
        Button {
            Task {
                await store.markNotificationRead(item)
                if !item.gameId.isEmpty, let game = store.snapshot.games.first(where: { $0.id == item.gameId }) { store.selectedGame = game }
            }
        } label: {
            BrumCard {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: icon).font(.system(size: 17, weight: .bold)).foregroundStyle(color)
                        .frame(width: 38, height: 38).background(color.opacity(0.12)).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.category.uppercased()).font(.caption2.bold()).tracking(1.2).foregroundStyle(color)
                            Spacer()
                            if !item.isRead { Circle().fill(BrumTheme.primary).frame(width: 8, height: 8) }
                        }
                        Text(item.title).font(.headline).foregroundStyle(BrumTheme.text).multilineTextAlignment(.leading)
                        if !item.message.isEmpty { Text(item.message).font(.subheadline).foregroundStyle(BrumTheme.muted).multilineTextAlignment(.leading) }
                        Text(dateLabel).font(.caption2).foregroundStyle(BrumTheme.muted)
                    }
                }.opacity(item.isRead ? 0.68 : 1)
            }
        }.buttonStyle(.plain)
    }

    private var color: Color {
        switch item.severity.lowercased() {
        case "error", "critical": return .red
        case "warning", "warn": return .orange
        case "success": return BrumTheme.primary
        default: return .cyan
        }
    }

    private var icon: String {
        switch item.category.lowercased() {
        case "achievement", "conquista": return "trophy.fill"
        case "session", "sessão": return "gamecontroller.fill"
        case "save": return "externaldrive.fill"
        case "install", "update", "atualização": return "arrow.down.circle.fill"
        case "system", "sistema": return "exclamationmark.triangle.fill"
        default: return "bell.fill"
        }
    }

    private var dateLabel: String {
        let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fractional.date(from: item.createdAt) ?? ISO8601DateFormatter().date(from: item.createdAt) else { return item.gameTitle }
        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        return item.gameTitle.isEmpty ? formatted : "\(item.gameTitle) · \(formatted)"
    }
}
