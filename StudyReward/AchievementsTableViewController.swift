import UIKit

// Achievements tab (Storyboard ID "AchievementsViewController", Class AchievementsViewController).
// Built fully in code: the old storyboard contents of this scene are no longer loaded.
@MainActor
class AchievementsViewController: UITableViewController {

    private let viewModel = AchievementsViewModel()

    // Uses a fresh table instead of the storyboard view, so old views/outlets can't interfere.
    override func loadView() {
        let table = UITableView(frame: .zero, style: .plain)
        table.dataSource = self
        table.delegate = self
        view = table
        tableView = table
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Achievements"
        navigationItem.largeTitleDisplayMode = .always

        tableView.backgroundColor = Theme.background
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 170
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 80
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset.bottom = 12
        tableView.register(BadgeCell.self, forCellReuseIdentifier: BadgeCell.reuseID)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = true
        // Re-check every badge from real progress each time the tab opens.
        // The selected filter is kept, so coming back to this tab stays on the same chip.
        viewModel.refresh()
        tableView.reloadData()
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BadgeCell.reuseID, for: indexPath)
        if let badgeCell = cell as? BadgeCell, indexPath.row < viewModel.rows.count {
            let row = viewModel.rows[indexPath.row]
            badgeCell.configure(with: row.badge, progress: row.progress)
        }
        return cell
    }

    // Summary card plus All / Earned / In progress / Locked chips.
    // Header counts and "Next:" always describe all 12 badges, not the filtered list.
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let gold = UIColor(red: 0.961, green: 0.647, blue: 0.141, alpha: 1)
        let card = UIView()
        card.backgroundColor = UIColor(red: 1.0, green: 0.957, blue: 0.863, alpha: 1)   // light gold
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false

        let trophyTile = UIView()
        trophyTile.backgroundColor = .white
        trophyTile.layer.cornerRadius = 14
        trophyTile.translatesAutoresizingMaskIntoConstraints = false
        let trophy = UIImageView(image: UIImage(systemName: "trophy.fill"))
        trophy.tintColor = gold
        trophy.contentMode = .scaleAspectFit
        trophy.translatesAutoresizingMaskIntoConstraints = false
        trophyTile.addSubview(trophy)

        let countLabel = Theme.label(viewModel.headerText, size: 18, weight: .bold)
        let bar = UIProgressView(progressViewStyle: .default)
        bar.progress = viewModel.fraction
        bar.progressTintColor = gold
        bar.trackTintColor = UIColor.white
        let nextLabel = Theme.label(viewModel.nextText, size: 13, weight: .semibold,
                                    color: UIColor(red: 0.6, green: 0.38, blue: 0.0, alpha: 1))
        let texts = UIStackView(arrangedSubviews: [countLabel, bar, nextLabel])
        texts.axis = .vertical
        texts.spacing = 6

        let row = UIStackView(arrangedSubviews: [trophyTile, texts])
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let filters = makeFilterRow()
        filters.translatesAutoresizingMaskIntoConstraints = false

        let header = UIView()
        header.backgroundColor = Theme.background
        header.addSubview(card)
        header.addSubview(filters)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: header.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),

            filters.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 14),
            filters.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            filters.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            filters.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            trophyTile.widthAnchor.constraint(equalToConstant: 52),
            trophyTile.heightAnchor.constraint(equalToConstant: 52),
            trophy.centerXAnchor.constraint(equalTo: trophyTile.centerXAnchor),
            trophy.centerYAnchor.constraint(equalTo: trophyTile.centerYAnchor),
            trophy.widthAnchor.constraint(equalToConstant: 28),
            trophy.heightAnchor.constraint(equalToConstant: 28),
            bar.heightAnchor.constraint(equalToConstant: 6)
        ])
        return header
    }

    // Shown only when the current filter has no badges.
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard viewModel.rows.isEmpty else { return nil }
        let footer = UIView()
        footer.backgroundColor = Theme.background
        let label = Theme.label(viewModel.emptyText, size: 15, color: .secondaryLabel)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footer.topAnchor, constant: 24),
            label.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -32)
        ])
        return footer
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return viewModel.rows.isEmpty ? UITableView.automaticDimension : .leastNormalMagnitude
    }

    // MARK: - Filter chips

    // Horizontal row of pills (scrolls if Dynamic Type makes them too wide).
    private func makeFilterRow() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        for filter in AchievementsViewModel.Filter.allCases {
            stack.addArrangedSubview(makeFilterButton(filter))
        }

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            // Pin vertically to the frame so the scroll view is as tall as the chips
            // (and can still scroll horizontally when the chips are wider than the screen).
            stack.topAnchor.constraint(equalTo: scroll.frameLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.frameLayoutGuide.bottomAnchor)
        ])
        return scroll
    }

    private func makeFilterButton(_ filter: AchievementsViewModel.Filter) -> UIButton {
        let selected = viewModel.selectedFilter == filter
        var config = UIButton.Configuration.filled()
        config.title = viewModel.title(for: filter)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics(forTextStyle: .subheadline)
                .scaledFont(for: .systemFont(ofSize: 14, weight: .semibold))
            return outgoing
        }
        if selected {
            config.baseBackgroundColor = Theme.purple
            config.baseForegroundColor = .white
            config.background.strokeWidth = 0
        } else {
            config.baseBackgroundColor = .white
            config.baseForegroundColor = .secondaryLabel
            config.background.strokeColor = Theme.purpleBorder
            config.background.strokeWidth = 1
        }

        let button = UIButton(configuration: config)
        button.tag = filter.rawValue
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(filterTapped(_:)), for: .touchUpInside)
        button.accessibilityLabel = filter.title
        button.accessibilityValue = viewModel.title(for: filter)
        if selected {
            button.accessibilityTraits.insert(.selected)
        }
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    @objc private func filterTapped(_ sender: UIButton) {
        guard let filter = AchievementsViewModel.Filter(rawValue: sender.tag),
              filter != viewModel.selectedFilter else { return }
        viewModel.setFilter(filter)
        tableView.reloadData()
    }
}
