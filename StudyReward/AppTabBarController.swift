import UIKit
import Supabase

@MainActor
final class AppTabBarController: UITabBarController {

    static let modulesTabIndex = 1
    private var isSigningOut = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        Theme.styleTabBar(tabBar)

        guard let storyboard = storyboard else { return }
        let home = storyboard.instantiateViewController(
            withIdentifier: "DashboardViewController"
        )
        let modules = storyboard.instantiateViewController(
            withIdentifier: "ModulesViewController"
        )
        let achievements = storyboard.instantiateViewController(
            withIdentifier: "AchievementsViewController"
        )
        let profile = ProfileViewController()

        modules.title = "Modules"
        achievements.title = "Achievements"
        let modulesNav = UINavigationController(rootViewController: modules)
        let achievementsNav = UINavigationController(rootViewController: achievements)
        Theme.styleNavigationBar(modulesNav.navigationBar)
        Theme.styleNavigationBar(achievementsNav.navigationBar)

        home.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        modulesNav.tabBarItem = UITabBarItem(
            title: "Modules",
            image: UIImage(systemName: "book"),
            selectedImage: UIImage(systemName: "book.fill")
        )
        achievementsNav.tabBarItem = UITabBarItem(
            title: "Achievements",
            image: UIImage(systemName: "trophy"),
            selectedImage: UIImage(systemName: "trophy.fill")
        )
        profile.tabBarItem = UITabBarItem(
            title: "Profile",
            image: UIImage(systemName: "person"),
            selectedImage: UIImage(systemName: "person.fill")
        )

        setViewControllers([home, modulesNav, achievementsNav, profile], animated: false)
    }

    func showModulesTab() {
        selectedIndex = AppTabBarController.modulesTabIndex
    }

    func showRewards(from screen: UIViewController) {
        guard presentedViewController == nil,
              let storyboard = storyboard else { return }

        let rewards = storyboard.instantiateViewController(
            withIdentifier: "RewardsViewController"
        )
        rewards.title = "Rewards"
        rewards.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeRewards)
        )
        let nav = UINavigationController(rootViewController: rewards)
        Theme.styleNavigationBar(nav.navigationBar)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func closeRewards() {
        presentedViewController?.dismiss(animated: true)
    }

    func signOutToLogin(
        from screen: UIViewController,
        finished: @escaping () -> Void
    ) {
        guard !isSigningOut else { return }
        isSigningOut = true

        Task { [weak self] in
            let auth = SupabaseManager.shared.client.auth
            var requestFailed = false
            do {
                try await auth.signOut(scope: .local)
            } catch {
                requestFailed = true
            }

            guard let self = self else { return }
            self.isSigningOut = false

            if auth.currentSession == nil {
                if requestFailed {
                    self.alert(
                        on: screen,
                        title: "Logged out on this device",
                        message: "Your session was removed from this device, but the server sign-out request did not complete."
                    ) {
                        self.closeToLogin()
                    }
                } else {
                    self.closeToLogin()
                }
            } else {
                self.alert(
                    on: screen,
                    title: "Log out failed",
                    message: "Please check your connection and try again.",
                    onOK: nil
                )
                finished()
            }
        }
    }

    private func closeToLogin() {
        presentingViewController?.dismiss(animated: true)
    }

    private func alert(
        on screen: UIViewController,
        title: String,
        message: String,
        onOK: (() -> Void)?
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onOK?()
        })
        screen.present(alert, animated: true)
    }
}
