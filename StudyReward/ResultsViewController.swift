import UIKit

struct QuizResult {
    let correctCount: Int
    let totalQuestions: Int
}

struct ResultsViewModel {
    let scoreText: String
    let correctText: String
    let pointsText: String
    let feedbackText: String
    let percent: Int
    let correct: Int
    let total: Int
    let points: Int
    let unlockedBadges: [Badge]   // badges this quiz unlocked (empty = none)

    // badgesBefore: badges earned just before this quiz was saved (nil = unknown, so show none).
    // badgesNow: badges earned now, after saving.
    init(result: QuizResult, badgesBefore: Set<String>? = nil, badgesNow: Set<String> = []) {
        let total = max(result.totalQuestions, 0)
        let correct = min(max(result.correctCount, 0), total)
        let percent = total > 0 ? (correct * 100) / total : 0
        let points = correct * 10

        self.percent = percent
        self.correct = correct
        self.total = total
        self.points = points

        scoreText = "Score: \(percent)%"
        correctText = "Correct answers: \(correct) of \(total)"
        pointsText = "Points earned: \(points)"

        if total == 0 {
            feedbackText = "No questions were answered."
        } else if percent == 100 {
            feedbackText = "Perfect score! Great work."
        } else if percent >= 80 {
            feedbackText = "Great job! You know this topic well."
        } else if percent >= 50 {
            feedbackText = "Good effort! Review the lesson and try again."
        } else {
            feedbackText = "Keep going! Re-read the lesson, then retry the quiz."
        }

        // A badge counts as "unlocked by this quiz" only if it is earned now and was not earned before.
        if let before = badgesBefore {
            unlockedBadges = BadgeRules.all.filter { badgesNow.contains($0.id) && !before.contains($0.id) }
        } else {
            unlockedBadges = []
        }
    }
}

// Results screen (opened by the "showResults" segue from Quiz).
// The old storyboard views are hidden and a purple/cream layout is built in code.
// The 4 storyboard outlets stay connected; they are pointed at the new labels below.
// Retry and Back to Modules still use retryTapped(_:) and backToModulesTapped(_:).
@MainActor
class ResultsViewController: UIViewController {

    @IBOutlet weak var scoreLabel: UILabel!
    @IBOutlet weak var correctAnswersLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var feedbackLabel: UILabel!

    var result: QuizResult?
    var onRetry: (() -> Void)?
    var badgesBeforeQuiz: Set<String>?   // set by QuizViewController just before it saves the result
    var elapsedSeconds: TimeInterval?    // set by QuizViewController when the quiz finishes (nil = unknown)

    private var isClosing = false

    private let scrollView = UIScrollView()
    private let ring = ProgressRingView()
    private let greetingLabel = Theme.label(size: 24, weight: .heavy, color: .white)
    private let feedbackTextLabel = Theme.label(size: 15, color: UIColor.white.withAlphaComponent(0.88))
    private let percentLabel = Theme.label(size: 40, weight: .heavy, color: .white)
    private let correctValue = Theme.label(size: 22, weight: .heavy)
    private let pointsValue = Theme.label(size: 22, weight: .heavy)
    private let timeValue = Theme.label(size: 22, weight: .heavy)
    private let badgesStack = UIStackView()
    private let retryButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)

    private let gold = UIColor(red: 0.961, green: 0.647, blue: 0.141, alpha: 1)
    private let green = UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)   // #16A34A

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        // Hide the old storyboard views. They still load, so nothing crashes.
        for old in view.subviews {
            old.isHidden = true
        }
        buildLayout()

        // The new views are in the view hierarchy now (which keeps them alive),
        // so it is safe to point the weak storyboard outlets at them.
        scoreLabel = percentLabel
        correctAnswersLabel = correctValue
        pointsLabel = pointsValue
        feedbackLabel = feedbackTextLabel

        let viewModel = ResultsViewModel(
            result: result ?? QuizResult(correctCount: 0, totalQuestions: 0),
            badgesBefore: badgesBeforeQuiz,
            badgesNow: badgesBeforeQuiz == nil ? [] : BadgeRules.earnedIDsNow())

        // Ring and tiles show the same real numbers the old labels used to show.
        percentLabel.text = "\(viewModel.percent)%"
        ring.progress = CGFloat(viewModel.percent) / 100
        ring.isAccessibilityElement = true
        ring.accessibilityLabel = viewModel.scoreText
        greetingLabel.text = greeting(for: viewModel.percent)
        feedbackLabel.text = viewModel.feedbackText
        feedbackLabel.numberOfLines = 0
        correctAnswersLabel.text = "\(viewModel.correct)/\(viewModel.total)"
        correctAnswersLabel.accessibilityLabel = viewModel.correctText
        pointsLabel.text = "+\(viewModel.points)"
        pointsLabel.accessibilityLabel = viewModel.pointsText
        if let elapsed = elapsedSeconds {
            timeValue.text = formatTime(elapsed)
            timeValue.accessibilityLabel = "Time taken: \(timeValue.text ?? "")"
        }

        showUnlockedBadges(viewModel.unlockedBadges)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    // "Great job, Ada!" when the account has a name; otherwise just "Great job!"
    private func greeting(for percent: Int) -> String {
        let name = AccountInfo.displayName()
        let who = name == "Learner" ? "!" : ", \(name)!"
        if percent == 100 { return "Perfect score\(who) 🎉" }
        if percent >= 80 { return "Great job\(who) 🎉" }
        if percent >= 50 { return "Good effort\(who)" }
        return "Keep going\(who)"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Layout

    private func buildLayout() {
        let header = makeHeader()
        let body = makeBody()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        // Let the purple header run up under the status bar (its content still respects the safe area).
        scrollView.contentInsetAdjustmentBehavior = .never
        header.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(header)
        scrollView.addSubview(body)
        view.addSubview(backButton)
        view.addSubview(retryButton)

        stylePrimaryButton(backButton, title: "Back to Modules", image: "square.grid.2x2")
        backButton.addTarget(self, action: #selector(backToModulesTapped(_:)), for: .touchUpInside)

        styleSecondaryButton(retryButton, title: "Retry Quiz", image: "arrow.counterclockwise")
        retryButton.addTarget(self, action: #selector(retryTapped(_:)), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: backButton.topAnchor, constant: -12),

            header.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),

            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: -18),   // slight overlap
            body.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            body.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),

            retryButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            retryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            retryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            backButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backButton.bottomAnchor.constraint(equalTo: retryButton.topAnchor, constant: -10)
        ])
    }

    private func makeHeader() -> UIView {
        let header = UIView()
        header.backgroundColor = Theme.purple
        header.layer.cornerRadius = 28
        header.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        header.layer.cornerCurve = .continuous

        // Hide the ring's own small label; a larger percent label sits in the same spot.
        ring.centerLabel.isHidden = true
        ring.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.textAlignment = .center
        percentLabel.adjustsFontForContentSizeCategory = true
        percentLabel.adjustsFontSizeToFitWidth = true
        percentLabel.minimumScaleFactor = 0.5
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        let scoreCaption = Theme.label("Score", size: 13, weight: .semibold, color: UIColor.white.withAlphaComponent(0.85))
        scoreCaption.textAlignment = .center
        let scoreStack = UIStackView(arrangedSubviews: [percentLabel, scoreCaption])
        scoreStack.axis = .vertical
        scoreStack.alignment = .center
        scoreStack.spacing = 0
        scoreStack.translatesAutoresizingMaskIntoConstraints = false
        ring.addSubview(scoreStack)

        let titleLabel = Theme.label("Quiz Complete", size: 16, weight: .bold, color: .white)
        titleLabel.textAlignment = .center
        greetingLabel.textAlignment = .center
        feedbackTextLabel.textAlignment = .center

        let column = UIStackView(arrangedSubviews: [titleLabel, ring, greetingLabel, feedbackTextLabel])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(column)

        NSLayoutConstraint.activate([
            ring.widthAnchor.constraint(equalToConstant: 160),
            ring.heightAnchor.constraint(equalToConstant: 160),
            scoreStack.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            scoreStack.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            scoreStack.widthAnchor.constraint(lessThanOrEqualTo: ring.widthAnchor, constant: -36),

            column.topAnchor.constraint(equalTo: header.safeAreaLayoutGuide.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            column.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            column.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -36)
        ])
        return header
    }

    private func makeBody() -> UIStackView {
        let correctTile = makeStatTile(caption: "Correct", value: correctValue, valueColor: green)
        let pointsTile = makeStatTile(caption: "Points", value: pointsValue, valueColor: gold)

        let tiles = UIStackView(arrangedSubviews: [correctTile, pointsTile])
        // Only add the Time tile when the quiz passed a duration (no placeholder number).
        if elapsedSeconds != nil {
            let timeTile = makeStatTile(caption: "Time", value: timeValue, valueColor: Theme.text)
            tiles.addArrangedSubview(timeTile)
        }
        tiles.distribution = .fillEqually
        tiles.spacing = 10

        badgesStack.axis = .vertical
        badgesStack.spacing = 10

        let body = UIStackView(arrangedSubviews: [tiles, badgesStack])
        body.axis = .vertical
        body.spacing = 16
        return body
    }

    private func makeStatTile(caption: String, value: UILabel, valueColor: UIColor) -> UIView {
        let tile = UIView()
        Theme.styleCard(tile)
        tile.layer.cornerCurve = .continuous
        value.textAlignment = .center
        value.textColor = valueColor
        let captionLabel = Theme.label(caption, size: 12, weight: .semibold, color: .secondaryLabel)
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [captionLabel, value])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
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

    private func stylePrimaryButton(_ button: UIButton, title: String, image: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: image)
        config.imagePadding = 8
        config.baseBackgroundColor = Theme.purple
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return out
        }
        button.configuration = config
        button.titleLabel?.adjustsFontForContentSizeCategory = true
    }

    private func styleSecondaryButton(_ button: UIButton, title: String, image: String) {
        var config = UIButton.Configuration.tinted()
        config.title = title
        config.image = UIImage(systemName: image)
        config.imagePadding = 8
        config.baseBackgroundColor = Theme.purple
        config.baseForegroundColor = Theme.purple
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return out
        }
        button.configuration = config
        button.titleLabel?.adjustsFontForContentSizeCategory = true
    }

    // MARK: - Badge unlocked card (added in code)

    private func showUnlockedBadges(_ badges: [Badge]) {
        guard !badges.isEmpty else { return }

        let headingText = badges.count == 1 ? "BADGE UNLOCKED" : "BADGES UNLOCKED"
        let heading = Theme.label(headingText, size: 12, weight: .bold, color: .secondaryLabel)
        badgesStack.addArrangedSubview(heading)
        for badge in badges {
            badgesStack.addArrangedSubview(makeBadgeCard(badge))
        }
    }

    private func makeBadgeCard(_ badge: Badge) -> UIView {
        let gold = UIColor(red: 0.961, green: 0.647, blue: 0.141, alpha: 1)
        let card = UIView()
        card.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.863, alpha: 1)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = gold.withAlphaComponent(0.5).cgColor

        let circle = UIView()
        circle.backgroundColor = badge.color
        circle.layer.cornerRadius = 24
        circle.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImageView(image: UIImage(systemName: badge.iconName) ?? UIImage(systemName: "rosette"))
        image.tintColor = .white
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(image)

        let caption = Theme.label("BADGE UNLOCKED", size: 11, weight: .semibold, color: .secondaryLabel)
        let name = Theme.label(badge.name, size: 17, weight: .bold)
        let requirement = Theme.label(badge.requirement, size: 13, color: .secondaryLabel)
        let texts = UIStackView(arrangedSubviews: [caption, name, requirement])
        texts.axis = .vertical
        texts.spacing = 2

        let row = UIStackView(arrangedSubviews: [circle, texts])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            circle.widthAnchor.constraint(equalToConstant: 48),
            circle.heightAnchor.constraint(equalToConstant: 48),
            image.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 24),
            image.heightAnchor.constraint(equalToConstant: 24)
        ])
        card.isAccessibilityElement = true
        card.accessibilityLabel = "Badge unlocked: \(badge.name). \(badge.requirement)"
        return card
    }

    @IBAction func retryTapped(_ sender: UIButton) {
        guard !isClosing else { return }
        isClosing = true
        let retry = onRetry          // keep the callback before closing
        onRetry = nil
        dismiss(animated: true) {
            retry?()                 // resets the quiz underneath
        }
    }

    @IBAction func backToModulesTapped(_ sender: UIButton) {
        guard !isClosing else { return }
        guard let target = findModulesScreen() else {
            let alert = UIAlertController(title: "Can't go back",
                                          message: "The Modules screen wasn't found.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        isClosing = true
        onRetry = nil
        let modulesNav = target.modulesNav
        // Closes Quiz and Results, then removes Module Details so the Modules list shows.
        // Popping to the list also refreshes its completion status (viewWillAppear).
        target.closer.dismiss(animated: true) {
            modulesNav?.popToRootViewController(animated: false)
        }
    }

    private static func isModules(_ vc: UIViewController) -> Bool {
        return vc is ModulesViewControllerTableViewController
    }

    private static func holdsModules(_ nav: UINavigationController) -> Bool {
        return nav.viewControllers.contains(where: { isModules($0) })
    }

    // Walks back from Results to find:
    // - closer: the screen to call dismiss on (it closes everything above it)
    // - modulesNav: the Modules tab's navigation controller (to pop Details off)
    private func findModulesScreen() -> (closer: UIViewController, modulesNav: UINavigationController?)? {
        var current = presentingViewController
        while let vc = current {
            // Usual case: the tab bar presented the Quiz. Switch to the Modules tab.
            if let tabs = vc as? UITabBarController,
               let index = tabs.viewControllers?.firstIndex(where: { child in
                   ResultsViewController.isModules(child) ||
                   ((child as? UINavigationController).map { ResultsViewController.holdsModules($0) } ?? false)
               }) {
                tabs.selectedIndex = index
                return (tabs, tabs.viewControllers?[index] as? UINavigationController)
            }
            if let nav = vc as? UINavigationController, ResultsViewController.holdsModules(nav) {
                return (nav, nav)
            }
            if let nav = vc.navigationController, ResultsViewController.holdsModules(nav) {
                return (vc, nav)
            }
            if ResultsViewController.isModules(vc) {
                return (vc, vc.navigationController)
            }
            current = vc.presentingViewController
        }
        return nil
    }
}
