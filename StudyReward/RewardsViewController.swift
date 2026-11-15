import UIKit

class RewardsViewController: UIViewController {

    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var bronzeButton: UIButton!
    @IBOutlet weak var silverButton: UIButton!
    @IBOutlet weak var goldButton: UIButton!

    private struct RewardTier {
        let tag: Int
        let name: String
        let requiredPoints: Int
    }

    private let tiers = [
        RewardTier(tag: 1, name: "Bronze Badge", requiredPoints: 50),
        RewardTier(tag: 2, name: "Silver Badge", requiredPoints: 150),
        RewardTier(tag: 3, name: "Gold Badge", requiredPoints: 300)
    ]

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    private func button(for tag: Int) -> UIButton? {
        switch tag {
        case 1: return bronzeButton
        case 2: return silverButton
        case 3: return goldButton
        default: return nil
        }
    }

    private func refresh() {
        let points = ProgressStore.shared.totalPoints
        pointsLabel.text = "Your points: \(points)"

        for tier in tiers {
            guard let button = button(for: tier.tag) else { continue }

            let title: String
            if points >= tier.requiredPoints {
                title = "\(tier.name) — Unlocked"
            } else {
                title = "\(tier.name) — \(tier.requiredPoints) points"
            }

            button.setTitle(title, for: .normal)
            button.titleLabel?.numberOfLines = 0
            button.titleLabel?.textAlignment = .center
        }
    }

    @IBAction func rewardTapped(_ sender: UIButton) {
        guard let tier = tiers.first(where: { $0.tag == sender.tag }) else {
            showAlert(
                title: "Setup problem",
                message: "This button's tag should be 1, 2 or 3."
            )
            return
        }

        let points = ProgressStore.shared.totalPoints

        if points >= tier.requiredPoints {
            showAlert(
                title: "\(tier.name) unlocked!",
                message: "You have \(points) points. This is a demo badge. Your points stay the same and nothing is purchased."
            )
        } else {
            let needed = tier.requiredPoints - points
            showAlert(
                title: "\(tier.name) locked",
                message: "Earn \(needed) more points by improving your quiz scores or completing other modules."
            )
        }
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
}

