
import UIKit
import Supabase

// Login screen (Class ViewController). The old storyboard layout is hidden at runtime
// and replaced by a layout built in code. The 3 storyboard outlets and both IBActions
// stay connected; outlets are pointed at the new fields, and the new main button calls
// createAccountTapped(_:) or signInTapped(_:). Auth behaviour is unchanged.
@MainActor
class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    private var isAuthenticating = false
    private var hasShownDashboard = false
    private var didCheckInitialSession = false
    private let spinner = UIActivityIndicatorView(style: .large)

    private enum Mode {
        case signIn
        case createAccount
    }

    private var mode: Mode = .signIn

    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let heroTitleLabel = Theme.label(size: 27, weight: .heavy, color: .white)
    private let heroSubtitleLabel = Theme.label(size: 16, weight: .semibold, color: UIColor.white.withAlphaComponent(0.8))
    private let signInModeButton = UIButton(type: .system)
    private let createModeButton = UIButton(type: .system)
    private let nameRow = UIStackView()
    private let strengthRow = UIView()
    private let strengthBars = (0..<4).map { _ -> UIView in
        let bar = UIView()
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }
    private let strengthLabel = Theme.label(size: 12, weight: .semibold)
    private let passwordToggle = UIButton(type: .system)
    private let primaryButton = UIButton(type: .system)
    private var heroTopConstraint: NSLayoutConstraint?

    private let mutedIcon = UIColor(red: 0.639, green: 0.627, blue: 0.710, alpha: 1)
    private let fieldBorder = UIColor(red: 0.925, green: 0.918, blue: 0.953, alpha: 1)   // #ECEAF3
    private let errorRed = UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1)
    private let successGreen = UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)
    private let gold = UIColor(red: 0.961, green: 0.647, blue: 0.141, alpha: 1)

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        // Hide the old storyboard views. They still load, so nothing crashes.
        for old in view.subviews {
            old.isHidden = true
        }
        buildLayout()

        // The new fields are in the view hierarchy now (which keeps them alive),
        // so it is safe to point the weak storyboard outlets at them.
        configureField(nameTextField, placeholder: "Full name")
        configureField(emailTextField, placeholder: "Email")
        configureField(passwordTextField, placeholder: "Password")

        nameTextField.textContentType = .name
        nameTextField.autocapitalizationType = .words
        nameTextField.autocorrectionType = .no
        nameTextField.returnKeyType = .next

        emailTextField.keyboardType = .emailAddress
        emailTextField.textContentType = .emailAddress
        emailTextField.autocapitalizationType = .none
        emailTextField.autocorrectionType = .no
        emailTextField.spellCheckingType = .no
        emailTextField.smartQuotesType = .no
        emailTextField.smartDashesType = .no
        emailTextField.smartInsertDeleteType = .no
        emailTextField.returnKeyType = .next

        passwordTextField.isSecureTextEntry = true
        passwordTextField.autocapitalizationType = .none   // recommended
        passwordTextField.autocorrectionType = .no
        passwordTextField.spellCheckingType = .no
        passwordTextField.keyboardType = .asciiCapable     // optional but often helps keyboard behavior
        passwordTextField.textContentType = .password      // or .newPassword in create mode
        // keep the other smart* properties set to .no
        updatePasswordToggle()

        spinner.hidesWhenStopped = true
        spinner.color = Theme.purple
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        applyMode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasShownDashboard = false
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didCheckInitialSession else { return }
        didCheckInitialSession = true
        restoreSession()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        heroTopConstraint?.constant = view.safeAreaInsets.top + 12
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false
        content.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical
        content.spacing = 16
        content.alignment = .fill

        view.addSubview(scrollView)
        scrollView.addSubview(content)

        let hero = makeHero()
        let card = makeCard()
        let footer = makeFooter()
        // Full-width wrapper so the card can have 20 pt side margins without
        // fighting the stack view's fill alignment (the hero stays edge-to-edge).
        let cardWrap = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        cardWrap.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: cardWrap.topAnchor),
            card.bottomAnchor.constraint(equalTo: cardWrap.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: cardWrap.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: cardWrap.trailingAnchor, constant: -20)
        ])
        content.addArrangedSubview(hero)
        content.addArrangedSubview(cardWrap)
        content.addArrangedSubview(footer)
        content.setCustomSpacing(-36, after: hero)
        content.setCustomSpacing(14, after: cardWrap)

        let frame = scrollView.frameLayoutGuide
        let scrollContent = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            // Ends at the top of the keyboard when it is open.
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            content.topAnchor.constraint(equalTo: scrollContent.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollContent.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: frame.trailingAnchor)
        ])
    }

    private func makeHero() -> UIView {
        let hero = LoginHeroView()
        hero.clipsToBounds = true

        let logoTile = UIView()
        logoTile.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        logoTile.layer.cornerRadius = 16
        logoTile.layer.borderWidth = 1
        logoTile.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        logoTile.translatesAutoresizingMaskIntoConstraints = false
        let trophy = UIImageView(image: UIImage(systemName: "trophy.fill"))
        trophy.tintColor = UIColor(red: 1.0, green: 0.827, blue: 0.420, alpha: 1)   // #FFD36B
        trophy.contentMode = .scaleAspectFit
        trophy.translatesAutoresizingMaskIntoConstraints = false
        logoTile.addSubview(trophy)

        let brand = Theme.label("StudyReward", size: 24, weight: .heavy, color: .white)
        let tagline = Theme.label("Learn. Quiz. Earn badges.", size: 13.5, color: UIColor.white.withAlphaComponent(0.85))
        let brandStack = UIStackView(arrangedSubviews: [brand, tagline])
        brandStack.axis = .vertical
        brandStack.spacing = 2

        let brandRow = UIStackView(arrangedSubviews: [logoTile, brandStack])
        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 12

        heroTitleLabel.numberOfLines = 0
        heroSubtitleLabel.numberOfLines = 0
        let titleStack = UIStackView(arrangedSubviews: [heroTitleLabel, heroSubtitleLabel])
        titleStack.axis = .vertical
        titleStack.spacing = 6

        let column = UIStackView(arrangedSubviews: [brandRow, titleStack])
        column.axis = .vertical
        column.spacing = 18
        column.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(column)

        let topPad = column.topAnchor.constraint(equalTo: hero.topAnchor, constant: 56)
        heroTopConstraint = topPad
        NSLayoutConstraint.activate([
            logoTile.widthAnchor.constraint(equalToConstant: 52),
            logoTile.heightAnchor.constraint(equalToConstant: 52),
            trophy.centerXAnchor.constraint(equalTo: logoTile.centerXAnchor),
            trophy.centerYAnchor.constraint(equalTo: logoTile.centerYAnchor),
            trophy.widthAnchor.constraint(equalToConstant: 28),
            trophy.heightAnchor.constraint(equalToConstant: 28),
            topPad,
            column.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 20),
            column.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -20),
            // Extra space so the white card can sit on top of the gradient.
            column.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -52)
        ])
        return hero
    }

    private func makeCard() -> UIView {
        let card = UIView()
        Theme.styleCard(card)
        card.layer.cornerRadius = 20

        let modeControl = makeModeControl()

        let nameField = UITextField()
        let emailField = UITextField()
        let passwordField = UITextField()
        nameTextField = nameField
        emailTextField = emailField
        passwordTextField = passwordField

        let nameBlock = makeLabeledField(title: "Full name", field: nameField, iconName: "person")
        nameRow.axis = .vertical
        nameRow.addArrangedSubview(nameBlock)

        let emailBlock = makeLabeledField(title: "Email", field: emailField, iconName: "envelope")
        configurePasswordToggle()
        let passwordBlock = makeLabeledField(title: "Password", field: passwordField,
                                             iconName: "lock", accessory: passwordToggle)
        makeStrengthRow()

        var config = UIButton.Configuration.filled()
        config.title = "Sign In"
        config.baseBackgroundColor = Theme.purple
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return outgoing
        }
        primaryButton.configuration = config
        primaryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        // Calls the existing IBActions so storyboard connections stay valid.
        primaryButton.addTarget(self, action: #selector(primaryTapped(_:)), for: .touchUpInside)
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            modeControl, nameRow, emailBlock, passwordBlock, strengthRow, primaryButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(16, after: modeControl)
        stack.setCustomSpacing(8, after: passwordBlock)
        stack.setCustomSpacing(16, after: strengthRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18)
        ])
        return card
    }

    private func makeModeControl() -> UIView {
        let background = UIView()
        background.backgroundColor = Theme.background
        background.layer.cornerRadius = 13

        styleModeButton(signInModeButton, title: "Sign In")
        styleModeButton(createModeButton, title: "Create Account")
        signInModeButton.addTarget(self, action: #selector(selectSignInMode), for: .touchUpInside)
        createModeButton.addTarget(self, action: #selector(selectCreateMode), for: .touchUpInside)
        signInModeButton.accessibilityLabel = "Sign In"
        createModeButton.accessibilityLabel = "Create Account"

        let row = UIStackView(arrangedSubviews: [signInModeButton, createModeButton])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 0
        row.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: background.topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -4),
            signInModeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 38)
        ])
        return background
    }

    private func styleModeButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.layer.cornerRadius = 10
        button.layer.cornerCurve = .continuous
    }

    private func makeLabeledField(title: String, field: UITextField, iconName: String,
                                  accessory: UIView? = nil) -> UIView {
        let label = Theme.label(title, size: 13, weight: .semibold, color: .secondaryLabel)
        let box = UIView()
        box.backgroundColor = .white
        box.layer.cornerRadius = 14
        box.layer.borderWidth = 1.5
        box.layer.borderColor = fieldBorder.cgColor
        box.tag = 11   // used to update the border when the field is focused

        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = mutedIcon
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true

        field.delegate = self
        field.addTarget(self, action: #selector(fieldEditingChanged), for: .editingChanged)

        var items: [UIView] = [icon, field]
        if let accessory = accessory {
            items.append(accessory)
        }
        let row = UIStackView(arrangedSubviews: items)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: box.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -8),
            row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -14),
            box.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])

        let stack = UIStackView(arrangedSubviews: [label, box])
        stack.axis = .vertical
        stack.spacing = 7
        return stack
    }

    private func configurePasswordToggle() {
        passwordToggle.tintColor = mutedIcon
        passwordToggle.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        passwordToggle.setContentHuggingPriority(.required, for: .horizontal)
        passwordToggle.widthAnchor.constraint(equalToConstant: 28).isActive = true
        passwordToggle.heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    private func makeStrengthRow() {
        let bars = UIStackView(arrangedSubviews: strengthBars)
        bars.axis = .horizontal
        bars.spacing = 4
        bars.alignment = .center
        for bar in strengthBars {
            NSLayoutConstraint.activate([
                bar.widthAnchor.constraint(equalToConstant: 28),
                bar.heightAnchor.constraint(equalToConstant: 4)
            ])
        }
        strengthLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [bars, strengthLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        strengthRow.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: strengthRow.topAnchor),
            row.bottomAnchor.constraint(equalTo: strengthRow.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: strengthRow.leadingAnchor, constant: 2),
            row.trailingAnchor.constraint(lessThanOrEqualTo: strengthRow.trailingAnchor)
        ])
        strengthRow.accessibilityLabel = "Password strength"
    }

    private func makeFooter() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "checkmark.shield"))
        icon.tintColor = mutedIcon
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 13).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 13).isActive = true
        let label = Theme.label("Secured by Supabase Auth", size: 11.5, color: mutedIcon)
        label.textAlignment = .center
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 5
        row.distribution = .fill
        let wrap = UIStackView(arrangedSubviews: [row])
        wrap.axis = .horizontal
        wrap.alignment = .center
        wrap.distribution = .equalCentering
        return wrap
    }

    // MARK: - Mode

    @objc private func selectSignInMode() {
        setMode(.signIn)
    }

    @objc private func selectCreateMode() {
        setMode(.createAccount)
    }

    private func setMode(_ newMode: Mode) {
        guard newMode != mode, !isAuthenticating else { return }
        mode = newMode
        applyMode()
    }

    private func applyMode() {
        let isCreate = (mode == .createAccount)
        nameRow.isHidden = !isCreate
        strengthRow.isHidden = !isCreate
        heroTitleLabel.text = isCreate ? "Create your account" : "Welcome back"
        heroSubtitleLabel.text = isCreate ? "Start your learning streak today" : "Sign in to continue learning"
        passwordTextField?.textContentType = isCreate ? .newPassword : .password
        setButtonTitle(primaryButton, isCreate ? "Create Account" : "Sign In", loading: false)
        updateModeButtons()
        if isCreate {
            updateStrengthMeter()
        }
    }

    private func updateModeButtons() {
        let signInSelected = (mode == .signIn)
        styleSelectedModeButton(signInModeButton, selected: signInSelected)
        styleSelectedModeButton(createModeButton, selected: !signInSelected)
        if signInSelected {
            signInModeButton.accessibilityTraits.insert(.selected)
            createModeButton.accessibilityTraits.remove(.selected)
        } else {
            createModeButton.accessibilityTraits.insert(.selected)
            signInModeButton.accessibilityTraits.remove(.selected)
        }
    }

    private func styleSelectedModeButton(_ button: UIButton, selected: Bool) {
        button.backgroundColor = selected ? .white : .clear
        button.setTitleColor(selected ? Theme.purple : .secondaryLabel, for: .normal)
        button.titleLabel?.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: selected ? .bold : .semibold))
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = selected ? 0.08 : 0
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowRadius = 4
    }

    @objc private func primaryTapped(_ sender: UIButton) {
        switch mode {
        case .signIn:
            signInTapped(sender)
        case .createAccount:
            createAccountTapped(sender)
        }
    }

    // MARK: - Restore saved login

    private func restoreSession() {
        isAuthenticating = true
        setFieldsEnabled(false)
        spinner.startAnimating()

        Task { @MainActor in
            defer {
                isAuthenticating = false
                setFieldsEnabled(true)
                spinner.stopAnimating()
            }

            do {
                // Refreshes the saved session if it has expired.
                _ = try await SupabaseManager.shared.client.auth.session
                goToDashboard()
            } catch AuthError.sessionMissing {
                // No saved session: stay on the login screen.
            } catch {
                showAlert(
                    title: "Could not restore session",
                    message: "Check your connection. You can also try signing in again. \(error.localizedDescription)"
                )
            }
        }
    }

    private func setFieldsEnabled(_ enabled: Bool) {
        nameTextField.isEnabled = enabled
        emailTextField.isEnabled = enabled
        passwordTextField.isEnabled = enabled
        signInModeButton.isEnabled = enabled
        createModeButton.isEnabled = enabled
        primaryButton.isEnabled = enabled
        passwordToggle.isEnabled = enabled
    }

    private func configureField(
        _ field: UITextField,
        placeholder: String
    ) {
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = Theme.text
        field.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 16))
        field.adjustsFontForContentSizeCategory = true
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
    }

    // MARK: - Create account

    @IBAction func createAccountTapped(_ sender: UIButton) {
        guard !isAuthenticating else { return }
        view.endEditing(true)

        let name = (nameTextField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let email = trimmedEmail()
        let password = passwordTextField.text ?? ""

        guard !name.isEmpty else {
            showAlert(title: "Missing name",
                      message: "Please enter your full name.")
            return
        }

        guard isValidEmail(email) else {
            showAlert(title: "Check email",
                      message: "Please enter an email like name@example.com.")
            return
        }

        guard password.count >= 8 else {
            showAlert(title: "Check password",
                      message: "Use at least 8 characters.")
            return
        }

        authenticate(button: sender, loadingTitle: "Creating account…") {
            let response = try await SupabaseManager.shared.client.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(name)]
            )

            self.passwordTextField.text = ""
            self.updateStrengthMeter()

            if response.session != nil {
                self.goToDashboard()
            } else {
                self.showAlert(
                    title: "Check your email",
                    message: "If this email is eligible for sign-up, check your inbox for a confirmation link. Confirm your email, then tap Sign In."
                )
            }
        }
    }

    // MARK: - Sign in

    @IBAction func signInTapped(_ sender: UIButton) {
        guard !isAuthenticating else { return }
        view.endEditing(true)

        let email = trimmedEmail()
        let password = passwordTextField.text ?? ""

        guard isValidEmail(email) else {
            showAlert(title: "Check email",
                      message: "Please enter an email like name@example.com.")
            return
        }

        guard !password.isEmpty else {
            showAlert(title: "Missing password",
                      message: "Please enter your password.")
            return
        }

        authenticate(button: sender, loadingTitle: "Signing in…") {
            _ = try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )

            self.passwordTextField.text = ""
            self.goToDashboard()
        }
    }

    // MARK: - Helpers

    private func authenticate(
        button: UIButton,
        loadingTitle: String,
        work: @escaping @MainActor () async throws -> Void
    ) {
        isAuthenticating = true
        let originalTitle = buttonTitle(button)
        button.isEnabled = false
        signInModeButton.isEnabled = false
        createModeButton.isEnabled = false
        // Use configuration.title (not setTitle) so filled-configuration buttons update correctly.
        setButtonTitle(button, loadingTitle, loading: true)

        Task { @MainActor in
            defer {
                isAuthenticating = false
                button.isEnabled = true
                signInModeButton.isEnabled = true
                createModeButton.isEnabled = true
                setButtonTitle(button, originalTitle, loading: false)
            }

            do {
                try await work()
            } catch let error as AuthError
                where error.errorCode == .emailNotConfirmed {
                showAlert(
                    title: "Email not confirmed",
                    message: "Open the confirmation link in your email first, then sign in."
                )
            } catch {
                showAlert(
                    title: "Something went wrong",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func buttonTitle(_ button: UIButton) -> String {
        if let title = button.configuration?.title, !title.isEmpty {
            return title
        }
        return button.title(for: .normal) ?? ""
    }

    private func setButtonTitle(_ button: UIButton, _ title: String, loading: Bool) {
        if var config = button.configuration {
            config.title = title
            config.showsActivityIndicator = loading
            button.configuration = config
        } else {
            button.setTitle(title, for: .normal)
        }
    }

    private func trimmedEmail() -> String {
        return (emailTextField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(
            separator: "@",
            omittingEmptySubsequences: false
        )

        return parts.count == 2
            && !parts[0].isEmpty
            && parts[1].contains(".")
            && !parts[1].hasPrefix(".")
            && !parts[1].hasSuffix(".")
            && email.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    private func goToDashboard() {
        guard !hasShownDashboard else { return }
        hasShownDashboard = true
        performSegue(withIdentifier: "showDashboard", sender: self)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Field extras

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func togglePasswordVisibility() {
        passwordTextField.isSecureTextEntry.toggle()
        updatePasswordToggle()
    }

    private func updatePasswordToggle() {
        let hidden = passwordTextField?.isSecureTextEntry ?? true
        let icon = hidden ? "eye" : "eye.slash"
        passwordToggle.setImage(UIImage(systemName: icon), for: .normal)
        passwordToggle.accessibilityLabel = hidden ? "Show password" : "Hide password"
    }

    @objc private func fieldEditingChanged(_ sender: UITextField) {
        if sender === passwordTextField, mode == .createAccount {
            updateStrengthMeter()
        }
    }

    private func updateStrengthMeter() {
        let password = passwordTextField?.text ?? ""
        let hasLower = password.contains { $0.isLowercase }
        let hasUpper = password.contains { $0.isUppercase }
        let hasDigit = password.contains { $0.isNumber }
        let hasSymbol = password.contains { !$0.isLetter && !$0.isNumber }
        let variety = [hasLower, hasUpper, hasDigit, hasSymbol].filter { $0 }.count

        let filled: Int
        let caption: String
        let color: UIColor
        if password.isEmpty {
            filled = 0
            caption = ""
            color = fieldBorder
        } else if password.count < 8 {
            filled = 1
            caption = "Weak"
            color = errorRed
        } else if variety >= 3 {
            filled = 4
            caption = "Strong"
            color = successGreen
        } else if variety >= 2 {
            filled = 3
            caption = "Good"
            color = gold
        } else {
            filled = 2
            caption = "Fair"
            color = UIColor(red: 0.949, green: 0.376, blue: 0.169, alpha: 1)
        }

        for (index, bar) in strengthBars.enumerated() {
            bar.backgroundColor = index < filled ? color : fieldBorder
        }
        strengthLabel.text = caption
        strengthLabel.textColor = color
        strengthRow.accessibilityValue = caption.isEmpty ? "Enter a password" : caption
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        setFieldBorder(textField, color: Theme.purple)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        setFieldBorder(textField, color: fieldBorder)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === nameTextField {
            emailTextField.becomeFirstResponder()
        } else if textField === emailTextField {
            passwordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            primaryTapped(primaryButton)
        }
        return true
    }

    private func setFieldBorder(_ field: UITextField, color: UIColor) {
        var view: UIView? = field.superview
        while let current = view {
            if current.tag == 11 {
                current.layer.borderColor = color.cgColor
                return
            }
            view = current.superview
        }
    }
}

// Purple hero background behind the logo and title.
private final class LoginHeroView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    private let blobA = UIView()
    private let blobB = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let gradient = layer as! CAGradientLayer
        gradient.colors = [
            UIColor(red: 0.294, green: 0.239, blue: 0.890, alpha: 1).cgColor,   // #4B3DE3
            UIColor(red: 0.486, green: 0.361, blue: 0.980, alpha: 1).cgColor,   // #7C5CFA
            UIColor(red: 0.608, green: 0.420, blue: 0.980, alpha: 1).cgColor    // #9B6BFA
        ]
        gradient.locations = [0, 0.6, 1]
        gradient.startPoint = CGPoint(x: 0.05, y: 0)
        gradient.endPoint = CGPoint(x: 0.95, y: 1)

        for blob in [blobA, blobB] {
            blob.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            blob.translatesAutoresizingMaskIntoConstraints = false
            addSubview(blob)
        }
        NSLayoutConstraint.activate([
            blobA.widthAnchor.constraint(equalToConstant: 180),
            blobA.heightAnchor.constraint(equalToConstant: 180),
            blobA.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            blobA.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 40),
            blobB.widthAnchor.constraint(equalToConstant: 140),
            blobB.heightAnchor.constraint(equalToConstant: 140),
            blobB.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -50),
            blobB.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("LoginHeroView is created in code only.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blobA.layer.cornerRadius = blobA.bounds.width / 2
        blobB.layer.cornerRadius = blobB.bounds.width / 2
    }
}
