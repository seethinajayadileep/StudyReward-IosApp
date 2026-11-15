//
//  BadgeCell.swift
//  StudyReward
//
//  Created by jaya on 10/11/26.
//

import UIKit

final class BadgeCell: UITableViewCell {

    static let reuseID = "BadgeCell"

    private let card = UIView()
    private let badgeCircle = UIView()
    private let badgeImageView = UIImageView()
    private let nameLabel = Theme.label(size: 16, weight: .bold)
    private let requirementLabel = Theme.label(size: 13, color: .secondaryLabel)
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let statusLabel = PaddedLabel()
    private let lockView = UIImageView(image: UIImage(systemName: "lock.fill"))

    private let earnedGreen = UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("BadgeCell is created in code only.")
    }

    private func buildLayout() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        Theme.styleCard(card)
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        badgeCircle.layer.cornerRadius = 26
        badgeCircle.translatesAutoresizingMaskIntoConstraints = false
        badgeImageView.contentMode = .scaleAspectFit
        badgeImageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        badgeImageView.translatesAutoresizingMaskIntoConstraints = false
        badgeCircle.addSubview(badgeImageView)

        progressBar.trackTintColor = Theme.purpleBorder
        progressBar.progressTintColor = Theme.purple

        let texts = UIStackView(arrangedSubviews: [nameLabel, requirementLabel, progressBar])
        texts.axis = .vertical
        texts.spacing = 4
        texts.setCustomSpacing(8, after: requirementLabel)

        statusLabel.font = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: .systemFont(ofSize: 12, weight: .semibold))
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.layer.cornerRadius = 10
        statusLabel.clipsToBounds = true
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        lockView.tintColor = .tertiaryLabel
        lockView.contentMode = .scaleAspectFit
        lockView.setContentHuggingPriority(.required, for: .horizontal)

        let right = UIStackView(arrangedSubviews: [statusLabel, lockView])
        right.axis = .vertical
        right.alignment = .trailing
        right.spacing = 4

        let row = UIStackView(arrangedSubviews: [badgeCircle, texts, right])
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

            badgeCircle.widthAnchor.constraint(equalToConstant: 52),
            badgeCircle.heightAnchor.constraint(equalToConstant: 52),
            badgeImageView.centerXAnchor.constraint(equalTo: badgeCircle.centerXAnchor),
            badgeImageView.centerYAnchor.constraint(equalTo: badgeCircle.centerYAnchor),
            badgeImageView.widthAnchor.constraint(equalToConstant: 26),
            badgeImageView.heightAnchor.constraint(equalToConstant: 26),
            progressBar.heightAnchor.constraint(equalToConstant: 5)
        ])
    }

    func configure(with badge: Badge, progress: BadgeProgress) {
        nameLabel.text = badge.name
        requirementLabel.text = badge.requirement
        badgeImageView.image = UIImage(systemName: badge.iconName) ?? UIImage(systemName: "rosette")

        if progress.isEarned {
            badgeCircle.backgroundColor = badge.color
            badgeImageView.tintColor = .white
            nameLabel.textColor = Theme.text
            statusLabel.text = "✓ Earned"
            statusLabel.textColor = earnedGreen
            statusLabel.backgroundColor = earnedGreen.withAlphaComponent(0.12)
            statusLabel.isHidden = false
            lockView.isHidden = true
            progressBar.isHidden = true
        } else {
            badgeCircle.backgroundColor = UIColor.systemGray5
            badgeImageView.tintColor = .systemGray
            nameLabel.textColor = .secondaryLabel
            lockView.isHidden = false
            let started = progress.current > 0
            statusLabel.isHidden = !started
            statusLabel.text = progress.text
            statusLabel.textColor = Theme.purple
            statusLabel.backgroundColor = Theme.purple.withAlphaComponent(0.10)
            progressBar.isHidden = !started
            progressBar.progress = progress.fraction
        }

        isAccessibilityElement = true
        let state = progress.isEarned ? "Earned" : "Locked, progress \(progress.text)"
        accessibilityLabel = "\(badge.name). \(badge.requirement). \(state)"
    }
}
