import UIKit
import Supabase

// Profile tab, built fully in code. Name is editable; email is shown but locked.
@MainActor
final class ProfileViewController: UIViewController, UITextFieldDelegate {

    private let header = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = Theme.label(size: 22, weight: .bold)
    private let levelPill = Theme.pill("", color: Theme.purple)

    private let pointsValue = Theme.label(size: 18, weight: .bold)
    private let modulesValue = Theme.label(size: 18, weight: .bold)
    private let streakValue = Theme.label(size: 18, weight: .bold)
    private let scoreValue = Theme.label(size: 18, weight: .bold)
    private let badgesValue = Theme.label(size: 18, weight: .bold)
    private let levelValue = Theme.label(size: 18, weight: .bold)

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let nameErrorLabel = Theme.label(size: 12, color: .systemRed)
    private let editButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    private let signOutButton = UIButton(type: .system)
    private let scrollView = UIScrollView()

    private var isEditingName = false
    private var isSaving = false
    private var savedName = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        buildLayout()
        setNameEditing(false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isEditingName && !isSaving {
            cancelEditing()
        }
    }

    // MARK: - Layout

    private func buildLayout() {
        header.backgroundColor = Theme.purple
        header.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(header)
        view.addSubview(scrollView)

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.backgroundColor = .white
        avatarImageView.layer.cornerRadius = 44
        avatarImageView.layer.borderWidth = 4
        avatarImageView.layer.borderColor = Theme.purple.withAlphaComponent(0.3).cgColor
        avatarImageView.clipsToBounds = true
        avatarImageView.isAccessibilityElement = true
        avatarImageView.widthAnchor.constraint(equalToConstant: 88).isActive = true
        avatarImageView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        nameLabel.textAlignment = .center

        let statsCard = wrapInCard(makeStatsGrid())
        let detailsCard = wrapInCard(makeDetailsStack())

        var config = UIButton.Configuration.filled()
        config.title = "Sign Out"
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .large
        signOutButton.configuration = config
        signOutButton.titleLabel?.adjustsFontForContentSizeCategory = true
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)

        let column = UIStackView(arrangedSubviews: [avatarImageView, nameLabel, levelPill,
                                                    statsCard, detailsCard, signOutButton])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 14
        column.setCustomSpacing(24, after: levelPill)
        column.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(column)

        for wide in [statsCard, detailsCard, signOutButton] {
            wide.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            header.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 84),
            column.topAnchor.constraint(equalTo: content.topAnchor, constant: 40),
            column.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            column.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -20)
        ])
    }

    private func makeStatsGrid() -> UIView {
        let top = UIStackView(arrangedSubviews: [
            statColumn(pointsValue, "Points"), statColumn(modulesValue, "Modules"), statColumn(streakValue, "Streak")
        ])
        let bottom = UIStackView(arrangedSubviews: [
            statColumn(scoreValue, "Avg score"), statColumn(badgesValue, "Badges"), statColumn(levelValue, "Level")
        ])
        for row in [top, bottom] {
            row.distribution = .fillEqually
        }
        let grid = UIStackView(arrangedSubviews: [top, bottom])
        grid.axis = .vertical
        grid.spacing = 14
        return grid
    }

    private func makeDetailsStack() -> UIView {
        let title = Theme.label("Account details", size: 16, weight: .bold)
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        editButton.setTitle("Edit", for: .normal)
        cancelButton.setTitle("Cancel", for: .normal)
        saveButton.setTitle("Save", for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        for button in [editButton, cancelButton, saveButton] {
            button.tintColor = Theme.purple
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        cancelButton.tintColor = .secondaryLabel
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        spinner.hidesWhenStopped = true
        spinner.color = Theme.purple

        let titleRow = UIStackView(arrangedSubviews: [title, cancelButton, spinner, editButton, saveButton])
        titleRow.spacing = 12
        titleRow.alignment = .center

        styleField(nameField)
        nameField.placeholder = "Your name"
        nameField.textContentType = .name
        nameField.autocapitalizationType = .words
        nameField.autocorrectionType = .no
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.accessibilityLabel = "Name"
        nameField.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        nameErrorLabel.isHidden = true

        styleField(emailField)
        emailField.isEnabled = false
        emailField.textColor = .secondaryLabel
        emailField.backgroundColor = UIColor.systemGray6
        emailField.accessibilityLabel = "Email, can't be changed"
        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
        lock.tintColor = .tertiaryLabel
        lock.contentMode = .center
        lock.frame = CGRect(x: 0, y: 0, width: 34, height: 20)
        emailField.rightView = lock
        emailField.rightViewMode = .always
        let emailNote = Theme.label("Email can't be changed in the app.", size: 12, color: .secondaryLabel)

        let stack = UIStackView(arrangedSubviews: [
            titleRow,
            fieldLabel("Name"), nameField, nameErrorLabel,
            fieldLabel("Email"), emailField, emailNote
        ])
        stack.axis = .vertical
        stack.spacing = 6
        stack.setCustomSpacing(14, after: titleRow)
        stack.setCustomSpacing(12, after: nameField)
        stack.setCustomSpacing(12, after: nameErrorLabel)
        return stack
    }

    private func styleField(_ field: UITextField) {
        field.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16))
        field.adjustsFontForContentSizeCategory = true
        field.textColor = Theme.text
        field.borderStyle = .none
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.purpleBorder.cgColor
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 20))
        field.leftView = padding
        field.leftViewMode = .always
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }

    private func fieldLabel(_ text: String) -> UILabel {
        return Theme.label(text, size: 13, color: .secondaryLabel)
    }

    private func statColumn(_ value: UILabel, _ caption: String) -> UIView {
        value.textAlignment = .center
        let captionLabel = Theme.label(caption, size: 12, color: .secondaryLabel)
        captionLabel.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [value, captionLabel])
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }

    private func wrapInCard(_ inner: UIView) -> UIView {
        let card = UIView()
        Theme.styleCard(card)
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

    // MARK: - Data

    private func refresh() {
        let progress = ProgressStore.shared
        let points = progress.totalPoints
        let level = points / 100 + 1
        levelPill.text = "Level \(level)"
        levelValue.text = "\(level)"
        pointsValue.text = "\(points)"
        modulesValue.text = "\(Theme.completedKnownModuleCount())/\(Theme.moduleTitles.count)"
        streakValue.text = "\(progress.currentStreak)"
        scoreValue.text = "\(progress.overallPercentage)%"
        badgesValue.text = "\(BadgeRules.earnedIDsNow().count)/\(BadgeRules.all.count)"

        emailField.text = AccountInfo.email()
        showName(AccountInfo.displayName())
    }

    private func showName(_ name: String) {
        savedName = name
        nameLabel.text = name
        avatarImageView.image = ProfileViewController.avatarImage(for: name)
        avatarImageView.accessibilityLabel = "Profile picture for \(name)"
        if !isEditingName {
            nameField.text = name == "Learner" ? "" : name
        }
    }

    static func avatarImage(for name: String) -> UIImage? {
        let initials = Theme.initials(for: name == "Learner" ? "" : name)
        guard initials != "?" else {
            let symbol = UIImage(systemName: "person.crop.circle.fill",
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 80))
            return symbol?.withTintColor(Theme.purple, renderingMode: .alwaysOriginal)
        }
        let size = CGSize(width: 88, height: 88)
        let purple = Theme.purple
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: purple
            ]
            let text = initials as NSString
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2,
                                  y: (size.height - textSize.height) / 2),
                      withAttributes: attributes)
        }
    }

    // MARK: - Editing

    private func setNameEditing(_ editing: Bool) {
        isEditingName = editing
        nameField.isEnabled = editing
        nameField.backgroundColor = .white
        nameField.layer.borderColor = (editing ? Theme.purple : Theme.purpleBorder).cgColor
        editButton.isHidden = editing
        cancelButton.isHidden = !editing
        saveButton.isHidden = !editing
        saveButton.isEnabled = editing && !isSaving
        cancelButton.isEnabled = !isSaving
        if !editing {
            nameErrorLabel.isHidden = true
            nameField.resignFirstResponder()
        }
    }

    @objc private func editTapped() {
        guard !isSaving else { return }
        nameField.text = savedName == "Learner" ? "" : savedName
        setNameEditing(true)
        nameField.becomeFirstResponder()
    }

    @objc private func cancelTapped() {
        cancelEditing()
    }

    private func cancelEditing() {
        guard !isSaving else { return }
        nameField.text = savedName == "Learner" ? "" : savedName
        setNameEditing(false)
    }

    @objc private func nameChanged() {
        nameErrorLabel.isHidden = true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            let rect = textField.convert(textField.bounds, to: self.scrollView).insetBy(dx: 0, dy: -60)
            self.scrollView.scrollRectToVisible(rect, animated: true)
        }
    }

    static func validationError(for name: String) -> String? {
        if name.count < 2 { return "Name must be at least 2 characters." }
        if name.count > 40 { return "Name must be 40 characters or fewer." }
        var allowed = CharacterSet.letters
        allowed.formUnion(CharacterSet(charactersIn: " .'-’"))
        if name.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Use letters, spaces, . ' and - only."
        }
        if !name.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) {
            return "Name must contain at least one letter."
        }
        return nil
    }

    @objc private func saveTapped() {
        guard isEditingName, !isSaving else { return }
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        nameField.text = name

        if let error = ProfileViewController.validationError(for: name) {
            nameErrorLabel.text = error
            nameErrorLabel.isHidden = false
            UIAccessibility.post(notification: .announcement, argument: error)
            return
        }
        if name == savedName {
            setNameEditing(false)
            return
        }
        guard let userID = SupabaseManager.shared.client.auth.currentSession?.user.id else {
            showAlert(title: "Not signed in", message: "Please sign in again to change your name.")
            cancelEditing()
            return
        }

        isSaving = true
        nameField.resignFirstResponder()
        nameField.isEnabled = false
        saveButton.isEnabled = false
        cancelButton.isEnabled = false
        spinner.startAnimating()

        Task { [weak self] in
            let auth = SupabaseManager.shared.client.auth
            var updatedUser: User?
            var failure: Error?
            do {
                updatedUser = try await auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            } catch {
                failure = error
            }
            guard let self = self else { return }
            self.isSaving = false
            self.spinner.stopAnimating()

            guard auth.currentSession?.user.id == userID else {
                self.setNameEditing(false)
                self.showAlert(title: "Account changed",
                               message: "The signed-in account changed, so this screen was not updated.")
                return
            }

            if let user = updatedUser, user.id == userID {
                self.setNameEditing(false)
                let newName = user.userMetadata["full_name"]?.stringValue ?? name
                self.refresh()
                self.showName(newName)
            } else {
                self.nameField.text = self.savedName == "Learner" ? "" : self.savedName
                self.setNameEditing(false)
                self.showAlert(title: "Name not saved", message: ProfileViewController.message(for: failure))
            }
        }
    }

    private static func message(for error: Error?) -> String {
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost]
               .contains(urlError.code) {
            return "You seem to be offline. Check your connection and try again."
        }
        return "Something went wrong while saving. Please try again."
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Sign out

    @objc private func signOutTapped() {
        guard let tabs = tabBarController as? AppTabBarController, !isSaving else { return }
        signOutButton.isEnabled = false
        tabs.signOutToLogin(from: self) { [weak self] in
            self?.signOutButton.isEnabled = true
        }
    }
}
