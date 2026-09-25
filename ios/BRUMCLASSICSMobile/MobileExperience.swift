import Foundation

enum OfflineContentPreferences {
    static let covers = "offline_content_covers"
    static let activity = "offline_content_activity"
    static let notifications = "offline_content_notifications"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [covers: true, activity: true, notifications: true])
    }
}

struct RecentAchievement: Identifiable {
    let game: Game
    let achievement: Game.Achievement
    var id: String { game.id + ":" + achievement.id }
}

struct MobileSyncSummary {
    let title: String
    let detail: String
    let action: String
    let isHealthy: Bool

    static func make(connection: AppStore.ConnectionState, paired: Bool, cachedGames: Int, pending: Int, lastSuccess: Date?) -> Self {
        let age = lastSuccess.map(relativeTime) ?? "ainda não concluída"
        if !paired {
            return .init(title: cachedGames > 0 ? "Dados salvos no aparelho" : "Computador não pareado",
                         detail: cachedGames > 0 ? "(cachedGames) jogos disponíveis offline · última sincronização (age)" : "Leia o QR Code do launcher para trazer sua biblioteca.",
                         action: "Parear com o computador", isHealthy: cachedGames > 0)
        }
        switch connection {
        case .online:
            return .init(title: pending == 0 ? "Tudo sincronizado" : "(pending) alteração(pending == 1 ? "" : "ões") aguardando o computador",
                         detail: "(cachedGames) jogos salvos no aparelho · última sincronização (age)",
                         action: pending == 0 ? "Nenhuma ação necessária" : "O envio será automático", isHealthy: pending == 0)
        case .connecting:
            return .init(title: "Sincronizando com o computador", detail: "Seus (cachedGames) jogos continuam disponíveis enquanto isso.", action: "Aguarde o teste automático", isHealthy: true)
        case .offline:
            return .init(title: "Dados salvos no aparelho", detail: "(pending) alteração(pending == 1 ? "" : "ões") pendente(pending == 1 ? "" : "s") · última sincronização (age)", action: "Reconexão automática ativa", isHealthy: cachedGames > 0)
        case .error(let reason):
            return .init(title: "O computador não respondeu", detail: "Sua biblioteca offline foi preservada. (reason)", action: "Abra Diagnóstico para corrigir", isHealthy: false)
        }
    }
}

func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

extension LibrarySnapshot {
    var recentAchievements: [RecentAchievement] {
        games.flatMap { game in game.achievements.filter(\.unlocked).map { RecentAchievement(game: game, achievement: $0) } }
            .sorted { $0.achievement.unlockedAt > $1.achievement.unlockedAt }
    }
}
