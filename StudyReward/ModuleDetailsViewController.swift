import UIKit

// Module Details (Storyboard ID "ModuleDetailsViewController"). Pushed from the Modules list.
@MainActor
class ModuleDetailsViewController: UIViewController {

    @IBOutlet weak var moduleTitleLabel: UILabel!
    @IBOutlet weak var lessonTextView: UITextView!

    var module: StudyModule?

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let categoryPill = PaddedLabel()
    private let titleLabel = Theme.label(size: 26, weight: .heavy)
    private let summaryLabel = Theme.label(size: 15, color: .secondaryLabel)
    private let statusPill = PaddedLabel()
    private let statusDetailLabel = Theme.label(size: 13, weight: .medium, color: .secondaryLabel)
    private let textView = UITextView()
    private let startButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationItem.largeTitleDisplayMode = .never
        for old in view.subviews {
            old.isHidden = true
        }
        buildLayout()

        moduleTitleLabel = titleLabel
        lessonTextView = textView

        guard let module = module else {
            titleLabel.text = "No module selected"
            summaryLabel.text = "Go back and pick a module."
            textView.text = ""
            startButton.isEnabled = false
            return
        }
        let info = StudyModule.named(module.title) ?? module
        let accent = info.color
        iconTile.backgroundColor = accent.withAlphaComponent(0.12)
        iconView.image = UIImage(systemName: info.iconName) ?? UIImage(systemName: "book")
        iconView.tintColor = accent
        stylePill(categoryPill, text: info.category.uppercased(), color: accent)
        titleLabel.text = info.title
        summaryLabel.text = info.summary
        textView.text = info.lesson.isEmpty ? "Lesson content is coming soon." : info.lesson
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        refreshStatus()
    }

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        startButton.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 12
        view.addSubview(scrollView)
        view.addSubview(startButton)
        scrollView.addSubview(content)

        iconTile.layer.cornerRadius = 16
        iconTile.layer.cornerCurve = .continuous
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconView)
        categoryPill.setContentHuggingPriority(.required, for: .horizontal)
        let headerRow = UIStackView(arrangedSubviews: [iconTile, categoryPill, UIView()])
        headerRow.spacing = 12
        headerRow.alignment = .center

        let statusRow = UIStackView(arrangedSubviews: [statusPill, statusDetailLabel])
        statusRow.spacing = 8
        statusRow.alignment = .center
        statusPill.setContentHuggingPriority(.required, for: .horizontal)
        statusPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textColor = Theme.text
        textView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15))
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        let lessonHeading = Theme.label("Lesson", size: 17, weight: .bold)
        let lessonStack = UIStackView(arrangedSubviews: [lessonHeading, textView])
        lessonStack.axis = .vertical
        lessonStack.spacing = 8
        let lessonCard = wrapInCard(lessonStack)

        let quizHeading = Theme.label("Quiz", size: 17, weight: .bold)
        let quizText = Theme.label("Multiple-choice questions on this lesson. Earn 10 points for each correct answer.",
                                   size: 14, color: .secondaryLabel)
        let quizStack = UIStackView(arrangedSubviews: [quizHeading, quizText])
        quizStack.axis = .vertical
        quizStack.spacing = 6
        let quizCard = wrapInCard(quizStack)

        for item in [headerRow, titleLabel, summaryLabel, statusRow, lessonCard, quizCard] as [UIView] {
            content.addArrangedSubview(item)
        }
        content.setCustomSpacing(18, after: statusRow)

        var config = UIButton.Configuration.filled()
        config.title = "Start Quiz"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = Theme.purple
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        startButton.configuration = config
        startButton.titleLabel?.adjustsFontForContentSizeCategory = true
        startButton.addTarget(self, action: #selector(startQuizTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),

            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            iconTile.widthAnchor.constraint(equalToConstant: 58),
            iconTile.heightAnchor.constraint(equalToConstant: 58),
            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func wrapInCard(_ inner: UIView) -> UIView {
        let card = UIView()
        Theme.styleCard(card)
        card.layer.cornerCurve = .continuous
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16)
        ])
        return card
    }

    private func stylePill(_ pill: PaddedLabel, text: String, color: UIColor) {
        pill.text = text
        pill.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
        pill.adjustsFontForContentSizeCategory = true
        pill.textColor = color
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 10
        pill.clipsToBounds = true
    }

    private func refreshStatus() {
        guard let module = module else { return }
        let status = ModuleStatus(module: module)
        let green = UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)
        stylePill(statusPill,
                  text: status.isCompleted ? "✓ \(status.pillText)" : status.pillText,
                  color: status.isCompleted ? green : .secondaryLabel)
        statusDetailLabel.text = status.detailText
        var config = startButton.configuration
        config?.title = status.isCompleted ? "Retake Quiz" : "Start Quiz"
        startButton.configuration = config
    }

    @objc private func startQuizTapped() {
        guard module != nil, presentedViewController == nil,
              navigationController?.topViewController === self || navigationController == nil else { return }
        performSegue(withIdentifier: "showQuiz", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showQuiz" else { return }
        let destination = (segue.destination as? UINavigationController)?.topViewController ?? segue.destination
        if let quiz = destination as? QuizViewController {
            quiz.module = module
        }
    }
}
