
import UIKit
import Supabase

// Quiz screen (opened by the "showQuiz" segue from Module Details).
// The old storyboard views are hidden and a purple/cream layout is built in code.
// All 8 storyboard outlets stay connected; they are pointed at the new views below.
// Answer buttons still call answerTapped(_:) and Next still calls nextTapped(_:).
@MainActor
class QuizViewController: UIViewController {

    @IBOutlet weak var questionCountLabel: UILabel!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var feedbackLabel: UILabel!
    @IBOutlet weak var answerAButton: UIButton!
    @IBOutlet weak var answerBButton: UIButton!
    @IBOutlet weak var answerCButton: UIButton!
    @IBOutlet weak var answerDButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!

    var module: StudyModule?

    private var questions: [StudyQuestion] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var hasAnswered = false
    private var isFinished = false

    private var isAIQuiz = false
    private var loadTask: Task<Void, Never>?
    private var startUserID: UUID?   // account that opened this quiz (nil = signed out)
    private var badgesBeforeQuiz: Set<String>?   // badges earned just before saving this result

    // Time: set when the first question appears, read when the quiz finishes.
    private var quizStartDate: Date?
    private var elapsedSeconds: TimeInterval?

    // MARK: New views (built in code)

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let moduleTitleLabel = Theme.label(size: 15, weight: .bold)
    private let pointsChip = Theme.pill("", color: UIColor(red: 0.718, green: 0.475, blue: 0.122, alpha: 1))
    private let countLabel = Theme.label(size: 14, weight: .semibold)
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let sourceTag = Theme.pill("", color: Theme.purple)
    private let questionTextLabel = Theme.label(size: 18, weight: .bold)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let answersStack = UIStackView()
    private let newAnswerButtons = [UIButton(type: .system), UIButton(type: .system),
                                    UIButton(type: .system), UIButton(type: .system)]
    private let feedbackBox = PaddedLabel()
    private let newNextButton = UIButton(type: .system)

    // Colours from the mockup.
    private let green = UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)      // #22C55E
    private let greenLight = UIColor(red: 0.906, green: 0.973, blue: 0.933, alpha: 1) // #E7F8EE
    private let greenText = UIColor(red: 0.078, green: 0.325, blue: 0.176, alpha: 1)  // #14532D
    private let red = UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1)        // #E5484D
    private let redLight = UIColor(red: 0.992, green: 0.925, blue: 0.925, alpha: 1)   // #FDECEC
    private let separator = UIColor(red: 0.925, green: 0.918, blue: 0.953, alpha: 1)  // #ECEAF3

    private enum AnswerState { case normal, correct, wrong, dimmed }

    private var answerButtons: [UIButton] {
        return [answerAButton, answerBButton, answerCButton, answerDButton]
    }

    // True if the signed-in account is still the one that opened the quiz.
    private var isSameAccount: Bool {
        return SupabaseManager.shared.client.auth.currentSession?.user.id == startUserID
    }

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
        questionCountLabel = countLabel
        questionLabel = questionTextLabel
        feedbackLabel = feedbackBox
        answerAButton = newAnswerButtons[0]
        answerBButton = newAnswerButtons[1]
        answerCButton = newAnswerButtons[2]
        answerDButton = newAnswerButtons[3]
        nextButton = newNextButton

        moduleTitleLabel.text = module?.title ?? "Quiz"
        updatePointsChip()

        guard let module = module else {
            showError("No module was selected.")
            return
        }
        startUserID = SupabaseManager.shared.client.auth.currentSession?.user.id
        loadQuestions(for: module.title)   // runs once per quiz screen
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Our close button replaces the nav bar only when this screen is a modal.
        // If the quiz was pushed, the Back button on the nav bar stays visible.
        if isModallyPresented() {
            navigationController?.setNavigationBarHidden(true, animated: false)
            closeButton.isHidden = false
        } else {
            closeButton.isHidden = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // If this quiz was pushed, put the nav bar back when the user leaves it.
        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Stop loading only when the quiz screen itself was closed (not when Results covers it).
        if isBeingDismissed || presentingViewController == nil {
            loadTask?.cancel()
        }
    }

    // Presented as a modal (or as the root of a presented navigation controller).
    private func isModallyPresented() -> Bool {
        if presentingViewController != nil { return true }
        if let nav = navigationController,
           nav.presentingViewController != nil,
           nav.viewControllers.first == self {
            return true
        }
        return false
    }

    // MARK: - Layout

    private func buildLayout() {
        // Top bar: close (X), module title, points earned so far.
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = Theme.text
        closeButton.backgroundColor = .white
        closeButton.layer.cornerRadius = 20
        closeButton.accessibilityLabel = "Close quiz"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true   // shown in viewWillAppear only when this screen is a modal
        moduleTitleLabel.textAlignment = .center
        pointsChip.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.863, alpha: 1)   // gold light
        pointsChip.setContentHuggingPriority(.required, for: .horizontal)
        pointsChip.setContentCompressionResistancePriority(.required, for: .horizontal)
        let topBar = UIStackView(arrangedSubviews: [closeButton, moduleTitleLabel, pointsChip])
        topBar.alignment = .center
        topBar.spacing = 10

        // "Question x of n" + purple progress bar.
        progressBar.progressTintColor = Theme.purple
        progressBar.trackTintColor = separator
        progressBar.layer.cornerRadius = 4
        progressBar.clipsToBounds = true
        progressBar.progress = 0
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        // Question card: AI / Practice tag + question text + loading spinner.
        spinner.color = Theme.purple
        spinner.hidesWhenStopped = true
        let tagRow = UIStackView(arrangedSubviews: [sourceTag, UIView()])
        let questionStack = UIStackView(arrangedSubviews: [tagRow, questionTextLabel, spinner])
        questionStack.axis = .vertical
        questionStack.spacing = 12
        let questionCard = wrapInCard(questionStack)

        // 4 answer buttons (rounded white cards).
        answersStack.axis = .vertical
        answersStack.spacing = 10
        for button in newAnswerButtons {
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.contentHorizontalAlignment = .leading
            button.addTarget(self, action: #selector(answerTapped(_:)), for: .touchUpInside)
            button.isHidden = true
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
            answersStack.addArrangedSubview(button)
        }

        // Feedback box (hidden until an answer is picked).
        feedbackBox.insets = UIEdgeInsets(top: 12, left: 14, bottom: 12, right: 14)
        feedbackBox.numberOfLines = 0
        feedbackBox.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 14, weight: .medium))
        feedbackBox.adjustsFontForContentSizeCategory = true
        feedbackBox.textColor = Theme.text
        feedbackBox.layer.cornerRadius = 16
        feedbackBox.clipsToBounds = true
        feedbackBox.isHidden = true

        content.axis = .vertical
        content.spacing = 14
        for item in [topBar, countLabel, progressBar, questionCard, answersStack, feedbackBox] as [UIView] {
            content.addArrangedSubview(item)
        }
        content.setCustomSpacing(8, after: countLabel)
        content.setCustomSpacing(18, after: progressBar)

        // Next / Finish button (fixed at the bottom).
        var config = UIButton.Configuration.filled()
        config.title = "Next Question"
        config.baseBackgroundColor = Theme.purple
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return out
        }
        newNextButton.configuration = config
        newNextButton.titleLabel?.adjustsFontForContentSizeCategory = true
        newNextButton.addTarget(self, action: #selector(nextTapped(_:)), for: .touchUpInside)
        newNextButton.isEnabled = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        newNextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        view.addSubview(newNextButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: newNextButton.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),

            newNextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            newNextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            newNextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            progressBar.heightAnchor.constraint(equalToConstant: 8)
        ])
    }

    private func wrapInCard(_ inner: UIView) -> UIView {
        let card = UIView()
        Theme.styleCard(card)
        card.layer.cornerCurve = .continuous
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])
        return card
    }

    // Draws one answer card in its state (normal / correct / wrong / dimmed).
    private func styleAnswer(at index: Int, state: AnswerState) {
        guard index < answerButtons.count else { return }
        let button = answerButtons[index]
        let options = currentIndex < questions.count ? questions[currentIndex].options : []
        let title = index < options.count ? options[index] : ""
        let letters = ["A", "B", "C", "D"]
        let letter = index < letters.count ? letters[index] : ""

        var fill = UIColor.white
        var border = separator
        var textColor = Theme.text
        var symbol = "\(letter.lowercased()).circle"
        var symbolColor = UIColor.secondaryLabel
        var weight = UIFont.Weight.medium
        switch state {
        case .normal, .dimmed:
            break
        case .correct:
            fill = greenLight
            border = green
            textColor = greenText
            symbol = "checkmark.circle.fill"
            symbolColor = green
            weight = .semibold
        case .wrong:
            fill = redLight
            border = red
            textColor = red
            symbol = "xmark.circle.fill"
            symbolColor = red
            weight = .semibold
        }

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = fill
        config.baseForegroundColor = textColor
        config.cornerStyle = .fixed
        var background = config.background
        background.cornerRadius = 16
        background.strokeColor = border
        background.strokeWidth = 2
        config.background = background
        config.image = UIImage(systemName: symbol)?.withTintColor(symbolColor, renderingMode: .alwaysOriginal)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title3)
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.titleAlignment = .leading
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        var text = AttributedString(title)
        text.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 15, weight: weight))
        text.foregroundColor = textColor
        config.attributedTitle = text
        button.configuration = config
        button.titleLabel?.numberOfLines = 0
        button.alpha = state == .dimmed ? 0.6 : 1
        button.accessibilityLabel = "Answer \(letter): \(title)"
    }

    private func setNextTitle(_ title: String) {
        var config = nextButton.configuration ?? UIButton.Configuration.filled()
        config.title = title
        nextButton.configuration = config
    }

    private func updatePointsChip() {
        pointsChip.text = "★ \(correctCount * 10)"
        pointsChip.accessibilityLabel = "\(correctCount * 10) points so far"
    }

    // Closes the quiz without saving a result.
    @objc private func closeTapped() {
        loadTask?.cancel()
        if let nav = navigationController,
           nav.presentingViewController != nil,
           nav.viewControllers.first == self {
            nav.dismiss(animated: true)
        } else if presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Loading (one AI request; falls back to built-in practice questions)

    private func loadQuestions(for title: String) {
        questionCountLabel.text = "AI Quiz • Loading…"
        questionLabel.text = "Creating your questions…"
        sourceTag.isHidden = false
        sourceTag.text = "✨ AI-generated"
        spinner.startAnimating()
        feedbackLabel.isHidden = true
        for button in answerButtons {
            button.isHidden = true
        }
        nextButton.isEnabled = false

        let expectedUserID = startUserID   // copy, so the task needs no self while waiting

        loadTask = Task { [weak self] in
            var aiQuestions: [StudyQuestion] = []
            var failure: Error?
            do {
                aiQuestions = try await AIQuizService.shared.generateQuestions(
                    for: title, expectedUserID: expectedUserID)
            } catch {
                failure = error
            }

            guard !Task.isCancelled, !(failure is CancellationError), let self = self else { return }

            // Account guard for BOTH success and failure.
            guard self.isSameAccount else {
                self.showError("The signed-in account changed. Close this quiz and start again.")
                return
            }

            if let failure = failure {
                self.isAIQuiz = false
                self.questions = QuestionBank.questions(for: title)
                guard !self.questions.isEmpty else {
                    self.showError("No quiz is available for this module yet.")
                    return
                }
                self.startQuiz()
                let alert = UIAlertController(
                    title: "AI quiz unavailable",
                    message: "\(failure.localizedDescription)\n\nShowing the built-in practice quiz instead.",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else {
                self.isAIQuiz = true
                self.questions = aiQuestions
                self.startQuiz()
            }
        }
    }

    private func startQuiz() {
        spinner.stopAnimating()
        sourceTag.isHidden = false
        sourceTag.text = isAIQuiz ? "✨ AI-generated" : "Practice"
        for button in answerButtons {
            button.isHidden = false
        }
        quizStartDate = Date()   // the clock starts when the first question appears
        elapsedSeconds = nil
        showQuestion()
    }

    private func showError(_ message: String) {
        spinner.stopAnimating()
        questionCountLabel.text = "Quiz unavailable"
        questionLabel.text = message
        sourceTag.isHidden = true
        progressBar.progress = 0
        feedbackLabel.isHidden = true
        for button in answerButtons {
            button.isHidden = true
        }
        nextButton.isEnabled = false
    }

    // MARK: - Questions

    private func showQuestion() {
        guard currentIndex < questions.count else { return }
        let question = questions[currentIndex]
        hasAnswered = false

        let prefix = isAIQuiz ? "AI Quiz" : "Practice"
        questionCountLabel.text = "\(prefix) • Question \(currentIndex + 1) of \(questions.count)"
        progressBar.setProgress(Float(currentIndex + 1) / Float(max(questions.count, 1)), animated: true)
        questionLabel.text = question.text
        feedbackLabel.text = ""
        feedbackLabel.isHidden = true

        for (index, button) in answerButtons.enumerated() {
            styleAnswer(at: index, state: .normal)
            button.isUserInteractionEnabled = true
        }

        nextButton.isEnabled = false
        let isLast = currentIndex == questions.count - 1
        setNextTitle(isLast ? "Finish Quiz" : "Next Question")
        scrollView.setContentOffset(.zero, animated: false)
    }

    @IBAction func answerTapped(_ sender: UIButton) {
        guard !hasAnswered, !isFinished, currentIndex < questions.count,
              let selected = answerButtons.firstIndex(of: sender) else { return }
        hasAnswered = true
        let question = questions[currentIndex]

        for button in answerButtons {
            button.isUserInteractionEnabled = false
        }
        // Dim every option first, then colour the picked one and the right one.
        for index in answerButtons.indices {
            styleAnswer(at: index, state: .dimmed)
        }

        if selected == question.correctIndex {
            correctCount += 1
            styleAnswer(at: selected, state: .correct)
            feedbackLabel.text = "✅ Correct! +10 pts\n\(question.explanation)"
            feedbackBox.backgroundColor = greenLight
        } else {
            styleAnswer(at: selected, state: .wrong)
            if question.correctIndex < answerButtons.count {
                styleAnswer(at: question.correctIndex, state: .correct)
            }
            feedbackLabel.text = "❌ Not quite.\n\(question.explanation)"
            feedbackBox.backgroundColor = redLight
        }
        updatePointsChip()
        feedbackLabel.isHidden = false
        nextButton.isEnabled = true

        // Make sure the feedback is visible on small screens.
        view.layoutIfNeeded()
        scrollView.scrollRectToVisible(feedbackBox.convert(feedbackBox.bounds, to: scrollView), animated: true)
    }

    @IBAction func nextTapped(_ sender: UIButton) {
        guard hasAnswered, !isFinished else { return }
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            showQuestion()
        } else {
            isFinished = true          // blocks a second Finish tap
            nextButton.isEnabled = false
            finishQuiz()
        }
    }

    private func finishQuiz() {
        // Stop the clock (seconds from the first question to Finish).
        if let start = quizStartDate {
            elapsedSeconds = Date().timeIntervalSince(start)
        }
        guard isSameAccount else {
            // Never save one account's result into another account.
            showAlert(title: "Result not saved",
                      message: "The signed-in account changed during this quiz.",
                      then: nil)
            return
        }
        badgesBeforeQuiz = nil
        if let module = module, startUserID != nil {
            badgesBeforeQuiz = BadgeRules.earnedIDsNow()   // snapshot before saving
            let saved = ProgressStore.shared.recordQuiz(moduleID: module.title,
                                                        correctCount: correctCount,
                                                        totalQuestions: questions.count)
            if !saved {
                showAlert(title: "Result could not be saved",
                          message: "Your score is shown, but it wasn't added to your progress.") { [weak self] in
                    self?.performSegue(withIdentifier: "showResults", sender: nil)
                }
                return
            }
        }
        performSegue(withIdentifier: "showResults", sender: nil)
    }

    private func showAlert(title: String, message: String, then action: (() -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in action?() })
        present(alert, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResults",
           let results = segue.destination as? ResultsViewController {
            results.result = QuizResult(correctCount: correctCount,
                                        totalQuestions: questions.count)
            results.badgesBeforeQuiz = badgesBeforeQuiz
            results.elapsedSeconds = elapsedSeconds   // shown as the Time tile, if present
            results.onRetry = { [weak self] in
                self?.resetQuiz()
            }
        }
    }

    // Retry reuses the same questions: no new AI request.
    private func resetQuiz() {
        guard !questions.isEmpty else { return }
        currentIndex = 0
        correctCount = 0
        isFinished = false
        updatePointsChip()
        quizStartDate = Date()   // restart the clock
        elapsedSeconds = nil
        showQuestion()
    }
}
