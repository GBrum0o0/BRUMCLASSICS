import SwiftUI
import UIKit

struct BrumAchievementOverlayPayload: Equatable, Sendable {
    let eventID: String
    let achievementID: String
    let title: String
    let description: String
    let points: Int
    let badgeURL: URL?

    init(eventID: String = "", achievementID: String = "", title: String, description: String = "", points: Int = 0, badgeURL: String? = nil) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAchID = achievementID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEvt = eventID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.achievementID = cleanAchID
        self.eventID = cleanEvt.isEmpty ? (cleanAchID.isEmpty ? "title:\(cleanTitle.lowercased())" : "id:\(cleanAchID)") : cleanEvt
        self.title = cleanTitle.isEmpty ? "Conquista desbloqueada" : cleanTitle
        self.description = cleanDesc
        self.points = max(0, points)
        self.badgeURL = Self.validatedBadgeURL(badgeURL)
    }

    static func validatedBadgeURL(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              host == "media.retroachievements.org" || host == "i.retroachievements.org",
              url.path.hasPrefix("/Badge/") else {
            return nil
        }
        return url
    }

    static func fromBridgeEvent(_ event: [String: Any]) -> BrumAchievementOverlayPayload? {
        guard (event["type"] as? String) == "achievement_unlocked" else { return nil }
        let ach = (event["achievement"] as? [String: Any]) ?? event
        let title = (ach["title"] as? String) ?? ""
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let id = (ach["id"] as? String) ?? (ach["achievementId"] as? String) ?? ""
        let gameID = (event["gameId"] as? String) ?? (ach["gameId"] as? String) ?? ""
        let eventID = (ach["eventId"] as? String) ?? (event["eventId"] as? String) ?? (id.isEmpty ? "" : "ra:\(gameID):\(id)")
        let desc = (ach["description"] as? String) ?? ""
        let pts = (ach["points"] as? NSNumber)?.intValue ?? 0
        let badge = (ach["badgeUrl"] as? String) ?? (ach["badge"] as? String)
        return BrumAchievementOverlayPayload(eventID: eventID, achievementID: id, title: title, description: desc, points: pts, badgeURL: badge)
    }
}

enum BrumCartridgeBrandMark {
    static func makeImage(size: CGSize, color: UIColor = UIColor(red: 0.616, green: 1.0, blue: 0.231, alpha: 1.0)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.scaleBy(x: size.width / 256.0, y: size.height / 256.0)
            cg.setFillColor(color.cgColor)

            // Exact paths from branding brand-mark.svg (256x256 viewBox).
            let outer = UIBezierPath()
            outer.move(to: CGPoint(x: 44, y: 38))
            outer.addLine(to: CGPoint(x: 212, y: 38))
            outer.addLine(to: CGPoint(x: 230, y: 56))
            outer.addLine(to: CGPoint(x: 230, y: 196))
            outer.addLine(to: CGPoint(x: 208, y: 218))
            outer.addLine(to: CGPoint(x: 48, y: 218))
            outer.addLine(to: CGPoint(x: 26, y: 196))
            outer.addLine(to: CGPoint(x: 26, y: 56))
            outer.close()

            let innerScreen = UIBezierPath()
            innerScreen.move(to: CGPoint(x: 52, y: 66))
            innerScreen.addLine(to: CGPoint(x: 204, y: 66))
            innerScreen.addLine(to: CGPoint(x: 216, y: 78))
            innerScreen.addLine(to: CGPoint(x: 216, y: 153))
            innerScreen.addLine(to: CGPoint(x: 204, y: 165))
            innerScreen.addLine(to: CGPoint(x: 52, y: 165))
            innerScreen.addLine(to: CGPoint(x: 40, y: 153))
            innerScreen.addLine(to: CGPoint(x: 40, y: 78))
            innerScreen.close()

            let pinSlot = UIBezierPath(rect: CGRect(x: 72, y: 182, width: 112, height: 36))

            outer.append(innerScreen)
            outer.append(pinSlot)
            outer.usesEvenOddFillRule = true
            outer.fill()

            for x in [83, 108, 133, 158] {
                UIBezierPath(rect: CGRect(x: x, y: 190, width: 16, height: 28)).fill()
            }
            cg.restoreGState()
        }
    }
}

final class BrumAchievementEventDeduper: @unchecked Sendable {
    static let shared = BrumAchievementEventDeduper()
    private let lock = NSLock()
    private var seenEventKeys: Set<String> = []
    private var seenOrder: [String] = []

    func markSeen(_ eventID: String) -> Bool {
        let key = eventID.lowercased()
        lock.lock()
        defer { lock.unlock() }
        guard !seenEventKeys.contains(key) else { return false }
        if seenOrder.count >= 512, let oldest = seenOrder.first {
            seenOrder.removeFirst()
            seenEventKeys.remove(oldest)
        }
        seenOrder.append(key)
        seenEventKeys.insert(key)
        return true
    }

    func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        seenEventKeys.removeAll()
        seenOrder.removeAll()
    }
}

@MainActor
final class BrumAchievementOverlayCoordinator: ObservableObject {
    static let shared = BrumAchievementOverlayCoordinator()

    @Published private(set) var current: BrumAchievementOverlayPayload?
    private var queue: [BrumAchievementOverlayPayload] = []
    private var activeTask: Task<Void, Never>?

    func markSeen(_ eventID: String) -> Bool {
        BrumAchievementEventDeduper.shared.markSeen(eventID)
    }

    func enqueue(_ payload: BrumAchievementOverlayPayload) {
        guard markSeen(payload.eventID) else { return }
        queue.append(payload)
        pumpNext()
    }

    func resetForTesting() {
        activeTask?.cancel()
        activeTask = nil
        queue.removeAll()
        BrumAchievementEventDeduper.shared.resetForTesting()
        current = nil
    }

    private func pumpNext() {
        guard activeTask == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        current = next
        activeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled, let self else { return }
            self.current = nil
            self.activeTask = nil
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            self.pumpNext()
        }
    }
}

/// Pure UIKit overlay host safe to attach over Objective-C++ OpenGL/CALayer surfaces without stealing focus or touch.
final class BrumAchievementCardView: UIView {
    private let accentBar = UIView()
    private let badgeContainer = UIView()
    private let badgeImageView = UIImageView()
    private let eyebrowLabel = UILabel()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let pointsPill = UIView()
    private let pointsLabel = UILabel()
    private let brandIcon = UIImageView()
    private let brandLabel = UILabel()
    private var badgeLoadTask: URLSessionDataTask?

    private static let charcoal = UIColor(red: 9 / 255.0, green: 13 / 255.0, blue: 14 / 255.0, alpha: 0.96)
    private static let border = UIColor(red: 53 / 255.0, green: 65 / 255.0, blue: 63 / 255.0, alpha: 1.0)
    private static let neonGreen = UIColor(red: 157 / 255.0, green: 255 / 255.0, blue: 59 / 255.0, alpha: 1.0)
    private static let mutedText = UIColor(red: 173 / 255.0, green: 182 / 255.0, blue: 178 / 255.0, alpha: 1.0)
    private static let pillBg = UIColor(red: 26 / 255.0, green: 36 / 255.0, blue: 34 / 255.0, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false

        backgroundColor = Self.charcoal
        layer.cornerRadius = 14
        layer.borderWidth = 1.2
        layer.borderColor = Self.border.cgColor
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 6)

        let clip = UIView()
        clip.translatesAutoresizingMaskIntoConstraints = false
        clip.layer.cornerRadius = 14
        clip.clipsToBounds = true
        clip.isUserInteractionEnabled = false
        addSubview(clip)

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = Self.neonGreen
        clip.addSubview(accentBar)

        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.backgroundColor = UIColor(red: 16 / 255.0, green: 23 / 255.0, blue: 24 / 255.0, alpha: 1.0)
        badgeContainer.layer.cornerRadius = 10
        badgeContainer.layer.borderWidth = 1
        badgeContainer.layer.borderColor = Self.border.cgColor
        badgeContainer.clipsToBounds = true
        clip.addSubview(badgeContainer)

        badgeImageView.translatesAutoresizingMaskIntoConstraints = false
        badgeImageView.contentMode = .scaleAspectFit
        badgeImageView.image = BrumCartridgeBrandMark.makeImage(size: CGSize(width: 44, height: 44))
        badgeContainer.addSubview(badgeImageView)

        eyebrowLabel.translatesAutoresizingMaskIntoConstraints = false
        eyebrowLabel.text = "CONQUISTA DESBLOQUEADA"
        eyebrowLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        eyebrowLabel.textColor = Self.neonGreen
        eyebrowLabel.adjustsFontSizeToFitWidth = true
        eyebrowLabel.minimumScaleFactor = 0.85

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descriptionLabel.textColor = Self.mutedText
        descriptionLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [eyebrowLabel, titleLabel, descriptionLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.alignment = .leading
        clip.addSubview(textStack)

        pointsPill.translatesAutoresizingMaskIntoConstraints = false
        pointsPill.backgroundColor = Self.pillBg
        pointsPill.layer.cornerRadius = 11
        pointsLabel.translatesAutoresizingMaskIntoConstraints = false
        pointsLabel.font = .systemFont(ofSize: 12, weight: .heavy)
        pointsLabel.textColor = Self.neonGreen
        pointsPill.addSubview(pointsLabel)

        brandIcon.translatesAutoresizingMaskIntoConstraints = false
        brandIcon.image = BrumCartridgeBrandMark.makeImage(size: CGSize(width: 16, height: 16))
        brandIcon.contentMode = .scaleAspectFit

        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        brandLabel.text = "BRUM CLASSICS"
        brandLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        brandLabel.textColor = UIColor(white: 0.94, alpha: 1.0)

        let brandRow = UIStackView(arrangedSubviews: [brandIcon, brandLabel])
        brandRow.translatesAutoresizingMaskIntoConstraints = false
        brandRow.axis = .horizontal
        brandRow.spacing = 5
        brandRow.alignment = .center

        let rightStack = UIStackView(arrangedSubviews: [pointsPill, UIView(), brandRow])
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.axis = .vertical
        rightStack.alignment = .trailing
        rightStack.distribution = .fill
        clip.addSubview(rightStack)

        NSLayoutConstraint.activate([
            clip.topAnchor.constraint(equalTo: topAnchor),
            clip.bottomAnchor.constraint(equalTo: bottomAnchor),
            clip.leadingAnchor.constraint(equalTo: leadingAnchor),
            clip.trailingAnchor.constraint(equalTo: trailingAnchor),

            accentBar.topAnchor.constraint(equalTo: clip.topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: clip.bottomAnchor),
            accentBar.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),

            badgeContainer.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            badgeContainer.centerYAnchor.constraint(equalTo: clip.centerYAnchor),
            badgeContainer.widthAnchor.constraint(equalToConstant: 56),
            badgeContainer.heightAnchor.constraint(equalToConstant: 56),

            badgeImageView.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeImageView.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
            badgeImageView.widthAnchor.constraint(equalToConstant: 48),
            badgeImageView.heightAnchor.constraint(equalToConstant: 48),

            textStack.leadingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: clip.topAnchor, constant: 11),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: clip.bottomAnchor, constant: -11),

            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: textStack.trailingAnchor, constant: 10),
            rightStack.trailingAnchor.constraint(equalTo: clip.trailingAnchor, constant: -12),
            rightStack.topAnchor.constraint(equalTo: clip.topAnchor, constant: 10),
            rightStack.bottomAnchor.constraint(equalTo: clip.bottomAnchor, constant: -10),
            rightStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 108),

            pointsLabel.topAnchor.constraint(equalTo: pointsPill.topAnchor, constant: 4),
            pointsLabel.bottomAnchor.constraint(equalTo: pointsPill.bottomAnchor, constant: -4),
            pointsLabel.leadingAnchor.constraint(equalTo: pointsPill.leadingAnchor, constant: 9),
            pointsLabel.trailingAnchor.constraint(equalTo: pointsPill.trailingAnchor, constant: -9),

            brandIcon.widthAnchor.constraint(equalToConstant: 15),
            brandIcon.heightAnchor.constraint(equalToConstant: 15),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with payload: BrumAchievementOverlayPayload) {
        titleLabel.text = payload.title
        descriptionLabel.text = payload.description
        descriptionLabel.isHidden = payload.description.isEmpty
        if payload.points > 0 {
            pointsLabel.text = "+\(payload.points) PTS"
            pointsPill.isHidden = false
        } else {
            pointsPill.isHidden = true
        }
        badgeLoadTask?.cancel()
        badgeLoadTask = nil
        badgeImageView.image = BrumCartridgeBrandMark.makeImage(size: CGSize(width: 44, height: 44))

        if let url = payload.badgeURL {
            var request = URLRequest(url: url, timeoutInterval: 8)
            request.setValue("BRUMCLASSICSMobile/0.24.0", forHTTPHeaderField: "User-Agent")
            let currentEvent = payload.eventID
            badgeLoadTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                      let data, data.count <= 2 * 1024 * 1024, let image = UIImage(data: data) else {
                    return
                }
                DispatchQueue.main.async {
                    guard let self, self.accessibilityIdentifier == currentEvent else { return }
                    self.badgeImageView.image = image
                }
            }
            accessibilityIdentifier = payload.eventID
            badgeLoadTask?.resume()
        } else {
            accessibilityIdentifier = payload.eventID
        }
    }
}

/// Objective-C++ callable host presenter attached directly on BrumLibretroViewController or any UIViewController.
@objc public final class BrumAchievementOverlayPresenter: NSObject {
    private weak var hostView: UIView?
    private var card: BrumAchievementCardView?
    private var queue: [BrumAchievementOverlayPayload] = []
    private var dismissTimer: Timer?
    private var showing = false

    @objc public init(hostView: UIView) {
        self.hostView = hostView
        super.init()
    }

    @objc public func enqueueUnlock(eventID: String,
                             achievementID: String,
                             title: String,
                             detail: String,
                             points: NSInteger,
                             badgeURL: String?) {
        let payload = BrumAchievementOverlayPayload(
            eventID: eventID,
            achievementID: achievementID,
            title: title,
            description: detail,
            points: points,
            badgeURL: badgeURL
        )
        DispatchQueue.main.async { [weak self] in
            self?.enqueueOnMain(payload)
        }
    }

    @objc public func invalidate() {
        DispatchQueue.main.async { [weak self] in
            self?.dismissTimer?.invalidate()
            self?.dismissTimer = nil
            self?.queue.removeAll()
            self?.card?.removeFromSuperview()
            self?.card = nil
            self?.showing = false
        }
    }

    private func enqueueOnMain(_ payload: BrumAchievementOverlayPayload) {
        guard BrumAchievementEventDeduper.shared.markSeen(payload.eventID) else { return }
        queue.append(payload)
        if !showing {
            showNext()
        }
    }

    private func showNext() {
        guard !showing, !queue.isEmpty, let container = hostView else { return }
        showing = true
        let next = queue.removeFirst()

        let cardView = self.card ?? {
            let v = BrumAchievementCardView()
            v.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(v)
            let maxWidth = v.widthAnchor.constraint(lessThanOrEqualToConstant: 440)
            let preferredWidth = v.widthAnchor.constraint(equalTo: container.safeAreaLayoutGuide.widthAnchor, constant: -24)
            preferredWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 12),
                v.trailingAnchor.constraint(lessThanOrEqualTo: container.safeAreaLayoutGuide.trailingAnchor, constant: -12),
                v.leadingAnchor.constraint(greaterThanOrEqualTo: container.safeAreaLayoutGuide.leadingAnchor, constant: 12),
                v.centerXAnchor.constraint(equalTo: container.safeAreaLayoutGuide.centerXAnchor),
                maxWidth,
                preferredWidth,
            ])
            self.card = v
            return v
        }()

        container.bringSubviewToFront(cardView)
        cardView.configure(with: next)
        cardView.isHidden = false
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        cardView.alpha = 0
        cardView.transform = reduceMotion ? .identity : CGAffineTransform(translationX: 0, y: -12)

        UIView.animate(withDuration: reduceMotion ? 0.12 : 0.24, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            cardView.alpha = 1
            cardView.transform = .identity
        }

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.hideCurrent()
        }
    }

    private func hideCurrent() {
        guard let cardView = card else {
            showing = false
            return
        }
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: reduceMotion ? 0.12 : 0.20, animations: {
            cardView.alpha = 0
            if !reduceMotion {
                cardView.transform = CGAffineTransform(translationX: 0, y: -8)
            }
        }) { [weak self] _ in
            cardView.isHidden = true
            cardView.transform = .identity
            guard let self else { return }
            self.showing = false
            self.showNext()
        }
    }
}

struct BrumAchievementOverlayContainer: View {
    @ObservedObject var coordinator = BrumAchievementOverlayCoordinator.shared

    var body: some View {
        VStack {
            if let payload = coordinator.current {
                BrumAchievementSwiftCard(payload: payload)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .transition(UIAccessibility.isReduceMotionEnabled ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeOut(duration: UIAccessibility.isReduceMotionEnabled ? 0.12 : 0.22), value: coordinator.current?.eventID)
        .allowsHitTesting(false)
    }
}

private struct BrumAchievementSwiftCard: View {
    let payload: BrumAchievementOverlayPayload
    @State private var badgeImage: UIImage?

    private static let charcoal = Color(red: 9 / 255.0, green: 13 / 255.0, blue: 14 / 255.0)
    private static let border = Color(red: 53 / 255.0, green: 65 / 255.0, blue: 63 / 255.0)
    private static let neonGreen = Color(red: 157 / 255.0, green: 255 / 255.0, blue: 59 / 255.0)
    private static let muted = Color(red: 173 / 255.0, green: 182 / 255.0, blue: 178 / 255.0)
    private static let pillBg = Color(red: 26 / 255.0, green: 36 / 255.0, blue: 34 / 255.0)

    var body: some View {
        HStack(spacing: 0) {
            Self.neonGreen.frame(width: 4)

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 16 / 255.0, green: 23 / 255.0, blue: 24 / 255.0))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Self.border, lineWidth: 1))
                    if let badgeImage {
                        Image(uiImage: badgeImage)
                            .resizable()
                            .scaledToFit()
                            .padding(3)
                    } else {
                        Image(uiImage: BrumCartridgeBrandMark.makeImage(size: CGSize(width: 42, height: 42)))
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CONQUISTA DESBLOQUEADA")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Self.neonGreen)
                        .lineLimit(1)
                    Text(payload.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !payload.description.isEmpty {
                        Text(payload.description)
                            .font(.system(size: 12))
                            .foregroundStyle(Self.muted)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing) {
                    if payload.points > 0 {
                        Text("+\(payload.points) PTS")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Self.neonGreen)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Self.pillBg, in: Capsule())
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        Image(uiImage: BrumCartridgeBrandMark.makeImage(size: CGSize(width: 15, height: 15)))
                            .resizable()
                            .frame(width: 15, height: 15)
                        Text("BRUM CLASSICS")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: 440, minHeight: 84)
        .background(Self.charcoal.opacity(0.96), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Self.border, lineWidth: 1.2))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
        .task(id: payload.eventID) {
            badgeImage = nil
            guard let url = payload.badgeURL else { return }
            var req = URLRequest(url: url, timeoutInterval: 8)
            req.setValue("BRUMCLASSICSMobile/0.24.0", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse,
               (200..<300).contains(http.statusCode),
               data.count <= 2 * 1024 * 1024,
               let loaded = UIImage(data: data) {
                badgeImage = loaded
            }
        }
    }
}
