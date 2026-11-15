import UIKit
import Supabase

@MainActor
enum Theme {
    static let background = UIColor(red: 0.980, green: 0.973, blue: 1, alpha: 1)
    static let purple = UIColor(red: 0.427, green: 0.302, blue: 0.894, alpha: 1)
    static let purpleBorder = UIColor(red: 0.427, green: 0.302, blue: 0.894, alpha: 0.18)
    static let text = UIColor(red: 0.122, green: 0.106, blue: 0.200, alpha: 1)

    static func label(
        _ text: String = "",
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor = Theme.text
    ) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .systemFont(ofSize: size, weight: weight)
        )
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func styleCard(_ view: UIView) {
        view.backgroundColor = .white
        view.layer.cornerRadius = 18
        view.layer.borderWidth = 1
        view.layer.borderColor = purpleBorder.cgColor
    }

    static func pill(_ text: String, color: UIColor) -> UILabel {
        let pill = PaddedLabel()
        pill.text = text
        pill.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 12, weight: .semibold)
        )
        pill.adjustsFontForContentSizeCategory = true
        pill.textColor = color
        pill.backgroundColor = color.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 10
        pill.clipsToBounds = true
        return pill
    }

    static func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    static func styleTabBar(_ tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = purple
        tabBar.unselectedItemTintColor = .secondaryLabel
    }

    static func styleNavigationBar(_ bar: UINavigationBar) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.titleTextAttributes = [.foregroundColor: text]
        appearance.largeTitleTextAttributes = [.foregroundColor: text]
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.tintColor = purple
    }

    static let moduleTitles = [
        "Phishing Basics", "Budgeting 101", "Swift Variables & Loops",
        "Recycling Basics", "Sleep Hygiene", "Time Management"
    ]

    static func completedKnownModuleCount() -> Int {
        moduleTitles.filter {
            ProgressStore.shared.isCompleted(moduleID: $0)
        }.count
    }
}

@MainActor
enum AccountInfo {
    static func displayName() -> String {
        guard let user = SupabaseManager.shared.client.auth.currentSession?.user else {
            return "Learner"
        }
        for key in ["full_name", "name"] {
            if let name = user.userMetadata[key]?.stringValue?
                .trimmingCharacters(in: .whitespaces), !name.isEmpty {
                return name
            }
        }
        return "Learner"
    }

    static func email() -> String {
        SupabaseManager.shared.client.auth.currentSession?.user.email ?? "Not available"
    }
}

final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 9, bottom: 3, right: 9)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}

final class ProgressRingView: UIView {
    private let trackLayer = CAShapeLayer()
    private let ringLayer = CAShapeLayer()
    let centerLabel = UILabel()

    var progress: CGFloat = 0 {
        didSet { ringLayer.strokeEnd = min(max(progress, 0), 1) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        for layer in [trackLayer, ringLayer] {
            layer.fillColor = UIColor.clear.cgColor
            layer.lineWidth = 9
            layer.lineCap = .round
            self.layer.addSublayer(layer)
        }
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.25).cgColor
        ringLayer.strokeColor = UIColor.white.cgColor
        ringLayer.strokeEnd = 0

        centerLabel.font = .systemFont(ofSize: 20, weight: .bold)
        centerLabel.textColor = .white
        centerLabel.textAlignment = .center
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerLabel)
        NSLayoutConstraint.activate([
            centerLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("ProgressRingView is created in code only.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = max(0, (min(bounds.width, bounds.height) - 9) / 2)
        let path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 1.5 * .pi,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        ringLayer.path = path.cgPath
    }
}
