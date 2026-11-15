import UIKit

// Modules tab (Storyboard ID "ModulesViewController"). The list is built in code.
// Tapping a module PUSHES Module Details onto the Modules tab's navigation controller.
@MainActor
class ModulesViewControllerTableViewController: UITableViewController {

    private let viewModel = ModulesViewModel()

    override func loadView() {
        let table = UITableView(frame: .zero, style: .plain)
        table.dataSource = self
        table.delegate = self
        view = table
        tableView = table
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Modules"
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.backButtonTitle = "Modules"

        tableView.backgroundColor = Theme.background
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 130
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 60
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset.bottom = 12
        tableView.register(ModuleCell.self, forCellReuseIdentifier: ModuleCell.reuseID)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.prefersLargeTitles = true
        viewModel.refresh()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.statuses.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ModuleCell.reuseID, for: indexPath)
        if let moduleCell = cell as? ModuleCell, indexPath.row < viewModel.statuses.count {
            moduleCell.configure(with: viewModel.modules[indexPath.row],
                                 status: viewModel.statuses[indexPath.row])
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = Theme.label(viewModel.headerText, size: 15, weight: .semibold)
        let subtitle = Theme.label("Pick a module to read the lesson and take its quiz.",
                                   size: 13, color: .secondaryLabel)
        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        let header = UIView()
        header.backgroundColor = Theme.background
        header.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: header.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20)
        ])
        return header
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < viewModel.modules.count,
              let nav = navigationController,
              nav.topViewController === self else { return }

        let storyboard = self.storyboard ?? UIStoryboard(name: "Main", bundle: nil)
        guard let details = storyboard.instantiateViewController(
            withIdentifier: "ModuleDetailsViewController") as? ModuleDetailsViewController else {
            let alert = UIAlertController(title: "Can't open module",
                                          message: "The Module Details screen has the wrong Class.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        details.module = viewModel.modules[indexPath.row]
        nav.pushViewController(details, animated: true)
    }
}
