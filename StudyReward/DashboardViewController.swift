import UIKit
import Supabase

// Home tab. The old storyboard layout is hidden at runtime and replaced by a layout built in code.
@MainActor
class DashboardViewController: UIViewController {

    @IBOutlet weak var completedModulesLabel: UILabel!
    @IBOutlet weak var totalPointsLabel: UILabel!
    @IBOutlet weak var streakLabel: UILabel!

    private let allModules: [StudyModule] = StudyModule.all

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let avatarLabel = UILabel()
    private let greetingLabel = Theme.label(size: 22, weight: .bold)
    private let ring = ProgressRingView()
    private let heroDetailLabel = Theme.label(size: 14, color: UIColor.white.withAlphaComponent(0.9))
    private let syncStatusLabel = Theme.label(size: 12, color: .secondaryLabel)
    private let moduleCardsStack = UIStackView()
    private var syncTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        for old in view.subviews {
            old.isHidden = true
        }
        buildLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
        refreshProgress()
        startCloudSync()
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 18
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20)
        ])

        content.addArrangedSubview(makeGreetingRow())
        content.addArrangedSubview(makeHeroCard())
        content.addArrangedSubview(makeStatsRow())
        content.addArrangedSubview(syncStatusLabel)
        content.addArrangedSubview(makeRewardsButton())
        content.addArrangedSubview(makeSectionHeader())
        moduleCardsStack.axis = .vertical
        moduleCardsStack.spacing = 12
        content.addArrangedSubview(moduleCardsStack)
    }

    private func makeGreetingRow() -> UIView {
        avatarLabel.font = .systemFont(ofSize: 17, weight: .bold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = Theme.purple
        avatarLabel.layer.cornerRadius = 22
        avatarLabel.clipsToBounds = true
        avatarLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        avatarLabel.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let row = UIStackView(arrangedSubviews: [avatarLabel, greetingLabel])
        row.spacing = 12
        row.alignment = .center
        return row
    }

    private func makeHeroCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.purple
        card.layer.cornerRadius = 22

        let title = Theme.label("Your progress", size: 18, weight: .bold, color: .white)
        let subtitle = Theme.label("Learn a module, take its quiz, earn points and badges.",
                                   size: 13, color: UIColor.white.withAlphaComponent(0.85))
        let titleStack = UIStackView(arrangedSubviews: [title, subtitle])
        titleStack.axis = .vertical
        titleStack.spacing = 4
        let topRow = UIStackView(arrangedSubviews: [titleStack, makeIllustration()])
        topRow.spacing = 12
        topRow.alignment = .center

        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.widthAnchor.constraint(equalToConstant: 92).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 92).isActive = true
        let bottomRow = UIStackView(arrangedSubviews: [ring, heroDetailLabel])
        bottomRow.spacing = 18
        bottomRow.alignment = .center

        let column = UIStackView(arrangedSubviews: [topRow, bottomRow])
        column.axis = .vertical
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20)
        ])
        return card
    }

    // Study illustration made from SF Symbols in UIImageViews (no asset catalog needed).
    private func makeIllustration() -> UIView {
        let gold = UIColor(red: 1.0, green: 0.827, blue: 0.420, alpha: 1)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        container.layer.cornerRadius = 36

        let books = UIImageView(image: UIImage(systemName: "books.vertical.fill"))
        books.tintColor = .white
        books.contentMode = .scaleAspectFit
        books.translatesAutoresizingMaskIntoConstraints = false

        let cap = UIImageView(image: UIImage(systemName: "graduationcap.fill"))
        cap.tintColor = gold
        cap.contentMode = .scaleAspectFit
        cap.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(books)
        container.addSubview(cap)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 72),
            container.heightAnchor.constraint(equalToConstant: 72),
            books.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            books.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
            books.widthAnchor.constraint(equalToConstant: 38),
            books.heightAnchor.constraint(equalToConstant: 34),
            cap.centerXAnchor.constraint(equalTo: container.centerXAnchor, constant: 10),
            cap.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            cap.widthAnchor.constraint(equalToConstant: 30),
            cap.heightAnchor.constraint(equalToConstant: 24)
        ])

        container.isAccessibilityElement = true
        container.accessibilityTraits = .image
        container.accessibilityLabel = "Illustration of books and a graduation cap"
        container.setContentHuggingPriority(.required, for: .horizontal)
        container.setContentCompressionResistancePriority(.required, for: .horizontal)
        return container
    }

    private func makeStatsRow() -> UIView {
        let modulesValue = Theme.label(size: 20, weight: .bold)
        let pointsValue = Theme.label(size: 20, weight: .bold)
        let streakValue = Theme.label(size: 20, weight: .bold)

        let row = UIStackView(arrangedSubviews: [
            makeStatTile(icon: "book.closed", caption: "Modules", value: modulesValue),
            makeStatTile(icon: "star", caption: "Total points", value: pointsValue),
            makeStatTile(icon: "flame", caption: "Day streak", value: streakValue)
        ])
        row.distribution = .fillEqually
        row.spacing = 10

        completedModulesLabel = modulesValue
        totalPointsLabel = pointsValue
        streakLabel = streakValue
        return row
    }

    private func makeStatTile(icon: String, caption: String, value: UILabel) -> UIView {
        let tile = UIView()
        Theme.styleCard(tile)
        let image = UIImageView(image: UIImage(systemName: icon))
        image.tintColor = Theme.purple
        value.textAlignment = .center
        let captionLabel = Theme.label(caption, size: 12, color: .secondaryLabel)
        captionLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [image, value, captionLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tile.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: tile.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: tile.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: tile.trailingAnchor, constant: -6)
        ])
        return tile
    }

    private func makeRewardsButton() -> UIView {
        var config = UIButton.Configuration.tinted()
        config.title = "View rewards"
        config.image = UIImage(systemName: "gift")
        config.imagePadding = 8
        config.baseForegroundColor = Theme.purple
        config.baseBackgroundColor = Theme.purple
        config.cornerStyle = .large
        let button = UIButton(configuration: config)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(rewardsTapped), for: .touchUpInside)
        return button
    }

    private func makeSectionHeader() -> UIView {
        let title = Theme.label("Continue learning", size: 18, weight: .bold)
        let seeAll = UIButton(type: .system)
        seeAll.setTitle("See all", for: .normal)
        seeAll.tintColor = Theme.purple
        seeAll.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        seeAll.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [title, seeAll])
        row.alignment = .center
        return row
    }

    private func makeModuleCard(_ module: StudyModule) -> UIView {
        let card = UIView()
        Theme.styleCard(card)

        let iconTile = UIView()
        iconTile.backgroundColor = module.color.withAlphaComponent(0.12)
        iconTile.layer.cornerRadius = 14
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        let iconImage = UIImageView(image: UIImage(systemName: module.iconName) ?? UIImage(systemName: "book"))
        iconImage.tintColor = module.color
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconImage)
        NSLayoutConstraint.activate([
            iconTile.widthAnchor.constraint(equalToConstant: 48),
            iconTile.heightAnchor.constraint(equalToConstant: 48),
            iconImage.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 26),
            iconImage.heightAnchor.constraint(equalToConstant: 26)
        ])

        let pill = Theme.pill(module.category, color: module.color)
        let pillRow = UIStackView(arrangedSubviews: [pill, UIView()])
        let title = Theme.label(module.title, size: 16, weight: .semibold)
        let detail = Theme.label(statusText(for: module.title), size: 13, color: .secondaryLabel)
        let texts = UIStackView(arrangedSubviews: [pillRow, title, detail])
        texts.axis = .vertical
        texts.spacing = 4

        let play = UIButton(type: .system)
        play.setImage(UIImage(systemName: "play.circle.fill",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
        play.tintColor = Theme.purple
        play.accessibilityLabel = "Browse learning modules"
        play.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        play.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconTile, texts, play])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
        return card
    }

    private func statusText(for title: String) -> String {
        guard let record = ProgressStore.shared.bestRecord(for: title) else { return "Not started" }
        return "Best score: \(record.bestCorrect) of \(record.totalQuestions)"
    }

    // MARK: - Data (real account progress only)

    private func refreshProgress() {
        let progress = ProgressStore.shared
        let name = AccountInfo.displayName()
        avatarLabel.text = Theme.initials(for: name)
        greetingLabel.text = "Welcome back, \(name.split(separator: " ").first.map(String.init) ?? name)"

        let completed = Theme.completedKnownModuleCount()
        let streak = progress.currentStreak
        completedModulesLabel.text = "\(completed)/\(allModules.count)"
        totalPointsLabel.text = "\(progress.totalPoints)"
        streakLabel.text = "\(streak)"

        ring.progress = CGFloat(completed) / CGFloat(allModules.count)
        ring.centerLabel.text = "\(completed * 100 / allModules.count)%"
        let badges = BadgeRules.earnedIDsNow().count
        heroDetailLabel.text = "\(completed) of \(allModules.count) modules completed\n"
            + "Average score: \(progress.overallPercentage)%\n"
            + "Badges earned: \(badges) of \(BadgeRules.all.count)"

        let notDone = allModules.filter { !progress.isCompleted(moduleID: $0.title) }
        let shown = Array((notDone.isEmpty ? allModules : notDone).prefix(2))
        for old in moduleCardsStack.arrangedSubviews {
            old.removeFromSuperview()
        }
        for module in shown {
            moduleCardsStack.addArrangedSubview(makeModuleCard(module))
        }
    }

    private func startCloudSync() {
        guard syncTask == nil else { return }
        let userID = SupabaseManager.shared.client.auth.currentSession?.user.id
        syncStatusLabel.text = "Syncing progress…"

        syncTask = Task { [weak self] in
            let report = await ProgressStore.shared.syncCloudProgress()
            guard let self = self else { return }
            self.syncTask = nil
            guard SupabaseManager.shared.client.auth.currentSession?.user.id == userID else { return }

            self.refreshProgress()
            switch report.status {
            case .complete:
                self.syncStatusLabel.text = "Cloud sync complete."
            case .busy:
                self.syncStatusLabel.text = "Sync already running. Reopen Home to refresh."
            case .notSignedIn:
                self.syncStatusLabel.text = "Not signed in. Progress isn't syncing."
            case .incomplete:
                let waiting = report.pendingCount > 0 ? " \(report.pendingCount) result(s) waiting to upload." : ""
                self.syncStatusLabel.text = "Saved on this device. Sync incomplete; reopen Home to retry.\(waiting)"
            }
        }
    }

    // MARK: - Actions

    @objc private func rewardsTapped() {
        (tabBarController as? AppTabBarController)?.showRewards(from: self)
    }

    @objc private func seeAllTapped() {
        (tabBarController as? AppTabBarController)?.showModulesTab()
    }

    @IBAction func logOutTapped(_ sender: UIButton) {
        sender.isEnabled = false
        (tabBarController as? AppTabBarController)?.signOutToLogin(from: self) {
            sender.isEnabled = true
        }
    }
}
