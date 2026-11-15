import UIKit

final class ModuleCell: UITableViewCell {

    static let reuseID = "ModuleCell"

    private let card = UIView()
    private let iconTile = UIView()
    private let iconView = UIImageView()
    private let categoryLabel = Theme.label(size: 11, weight: .semibold)
    private let titleLabel = Theme.label(size: 16, weight: .bold)
    private let summaryLabel = Theme.label(size: 13, color: .secondaryLabel)
    private let statusPill = PaddedLabel()
    private let statusDetailLabel = Theme.label(size: 12, weight: .medium, color: .secondaryLabel)
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("ModuleCell is created in code only.")
    }

    private func buildLayout() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        Theme.styleCard(card)
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        iconTile.layer.cornerRadius = 14
        iconTile.layer.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconTile.addSubview(iconView)

        summaryLabel.numberOfLines = 2

        statusPill.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
        statusPill.adjustsFontForContentSizeCategory = true
        statusPill.layer.cornerRadius = 10
        statusPill.clipsToBounds = true
        statusPill.setContentHuggingPriority(.required, for: .horizontal)
        statusPill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let statusRow = UIStackView(arrangedSubviews: [statusPill, statusDetailLabel])
        statusRow.spacing = 8
        statusRow.alignment = .center

        let texts = UIStackView(arrangedSubviews: [categoryLabel, titleLabel, summaryLabel, statusRow])
        texts.axis = .vertical
        texts.spacing = 4
        texts.setCustomSpacing(10, after: summaryLabel)

        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconTile, texts, chevron])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            iconTile.widthAnchor.constraint(equalToConstant: 50),
            iconTile.heightAnchor.constraint(equalToConstant: 50),
            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func configure(with module: StudyModule, status: ModuleStatus) {
        let accent = module.color
        iconTile.backgroundColor = accent.withAlphaComponent(0.12)
        iconView.image = UIImage(systemName: module.iconName) ?? UIImage(systemName: "book")
        iconView.tintColor = accent

        categoryLabel.text = module.category.uppercased()
        categoryLabel.textColor = accent
        titleLabel.text = module.title
        summaryLabel.text = module.summary

        let statusColor: UIColor = status.isCompleted ? .systemGreen : .secondaryLabel
        statusPill.text = status.isCompleted ? "✓ \(status.pillText)" : status.pillText
        statusPill.textColor = status.isCompleted
            ? UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)
            : .secondaryLabel
        statusPill.backgroundColor = statusColor.withAlphaComponent(0.12)
        statusDetailLabel.text = status.detailText

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(module.title). \(module.summary). \(status.pillText). \(status.detailText)"
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: animated ? 0.15 : 0) {
            self.card.alpha = highlighted ? 0.6 : 1
        }
    }
}

