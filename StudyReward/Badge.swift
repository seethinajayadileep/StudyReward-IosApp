import UIKit

// MARK: - Progress snapshot (real data only, read from ProgressStore)

// What the badge rules look at. Only the 6 real modules count.
struct ProgressSnapshot {
    let bestPercent: [String: Int]   // module title -> best score %, only modules with a saved result
    let completedCount: Int
    let totalPoints: Int
    let streak: Int

    @MainActor
    static func current() -> ProgressSnapshot {
        let store = ProgressStore.shared
        var best: [String: Int] = [:]
        for title in Theme.moduleTitles {
            if let record = store.bestRecord(for: title), record.totalQuestions > 0 {
                best[title] = record.bestCorrect * 100 / record.totalQuestions
            }
        }
        return ProgressSnapshot(bestPercent: best,
                                completedCount: best.count,
                                totalPoints: store.totalPoints,
                                streak: store.currentStreak)
    }
}

// MARK: - Badge model

enum BadgeRule {
    case modulesCompleted(Int)          // finish this many of the 6 modules
    case moduleScore(String, Int)       // best score on one module >= percent
    case anyModuleScore(Int)            // best score on any module >= percent
    case points(Int)                    // total points >= value
    case streakDays(Int)                // current quiz streak >= days
}

// How far the user is towards one badge.
struct BadgeProgress {
    let current: Int
    let target: Int
    let isPercent: Bool

    var isEarned: Bool { return current >= target }
    // Not earned, but some progress has been made (current > 0).
    var isInProgress: Bool { return !isEarned && current > 0 }
    // Not earned and no progress yet.
    var isLocked: Bool { return !isEarned && current == 0 }
    var fraction: Float { return target > 0 ? min(Float(current) / Float(target), 1) : 0 }
    var text: String {
        let shown = min(current, target)
        return isPercent ? "Best \(current)%" : "\(shown)/\(target)"
    }
}

struct Badge {
    let id: String
    let name: String
    let requirement: String
    let iconName: String   // SF Symbol name
    let rule: BadgeRule

    var color: UIColor {
        switch rule {
        case .moduleScore(let title, _):
            return StudyModule.named(title)?.color ?? UIColor(red: 0.427, green: 0.302, blue: 0.894, alpha: 1)
        case .streakDays:
            return UIColor(red: 0.949, green: 0.376, blue: 0.169, alpha: 1)   // streak orange
        default:
            return UIColor(red: 0.961, green: 0.647, blue: 0.141, alpha: 1)   // gold
        }
    }

    func progress(in snapshot: ProgressSnapshot) -> BadgeProgress {
        switch rule {
        case .modulesCompleted(let count):
            return BadgeProgress(current: snapshot.completedCount, target: count, isPercent: false)
        case .moduleScore(let title, let percent):
            return BadgeProgress(current: snapshot.bestPercent[title] ?? 0, target: percent, isPercent: true)
        case .anyModuleScore(let percent):
            return BadgeProgress(current: snapshot.bestPercent.values.max() ?? 0, target: percent, isPercent: true)
        case .points(let value):
            return BadgeProgress(current: snapshot.totalPoints, target: value, isPercent: false)
        case .streakDays(let days):
            return BadgeProgress(current: snapshot.streak, target: days, isPercent: false)
        }
    }
}

// MARK: - Shared rules (used by Achievements AND Results)

enum BadgeRules {
    static let all: [Badge] = [
        Badge(id: "first-quiz", name: "First Steps", requirement: "Complete your first module quiz",
              iconName: "flag.checkered", rule: .modulesCompleted(1)),
        Badge(id: "phishing-detective", name: "Phishing Detective", requirement: "Score 80% or more on Phishing Basics",
              iconName: "magnifyingglass", rule: .moduleScore("Phishing Basics", 80)),
        Badge(id: "smart-saver", name: "Smart Saver", requirement: "Score 80% or more on Budgeting 101",
              iconName: "creditcard", rule: .moduleScore("Budgeting 101", 80)),
        Badge(id: "logic-breaker", name: "Logic Breaker", requirement: "Score 100% on Swift Variables & Loops",
              iconName: "chevron.left.forwardslash.chevron.right", rule: .moduleScore("Swift Variables & Loops", 100)),
        Badge(id: "eco-champion", name: "Eco Champion", requirement: "Score 80% or more on Recycling Basics",
              iconName: "leaf", rule: .moduleScore("Recycling Basics", 80)),
        Badge(id: "well-rested", name: "Well Rested", requirement: "Score 80% or more on Sleep Hygiene",
              iconName: "moon.zzz", rule: .moduleScore("Sleep Hygiene", 80)),
        Badge(id: "time-master", name: "Time Master", requirement: "Score 80% or more on Time Management",
              iconName: "clock", rule: .moduleScore("Time Management", 80)),
        Badge(id: "perfect-score", name: "Perfect Score", requirement: "Score 100% on any module",
              iconName: "star.fill", rule: .anyModuleScore(100)),
        Badge(id: "halfway", name: "Halfway There", requirement: "Complete 3 modules",
              iconName: "book", rule: .modulesCompleted(3)),
        Badge(id: "module-master", name: "Module Master", requirement: "Complete all 6 modules",
              iconName: "trophy", rule: .modulesCompleted(6)),
        Badge(id: "points-100", name: "Point Collector", requirement: "Earn 100 points",
              iconName: "sparkles", rule: .points(100)),
        Badge(id: "streak-3", name: "On a Roll", requirement: "Keep a 3-day quiz streak",
              iconName: "flame", rule: .streakDays(3))
    ]

    static func earnedIDs(in snapshot: ProgressSnapshot) -> Set<String> {
        return Set(all.filter { $0.progress(in: snapshot).isEarned }.map { $0.id })
    }

    // Badges earned right now by the signed-in account.
    @MainActor
    static func earnedIDsNow() -> Set<String> {
        return earnedIDs(in: ProgressSnapshot.current())
    }
}

// MARK: - Achievements view model

@MainActor
final class AchievementsViewModel {
    struct Row {
        let badge: Badge
        let progress: BadgeProgress
    }

    enum Filter: Int, CaseIterable {
        case all
        case earned
        case inProgress
        case locked

        var title: String {
            switch self {
            case .all: return "All"
            case .earned: return "Earned"
            case .inProgress: return "In progress"
            case .locked: return "Locked"
            }
        }
    }

    // Every badge, in list order. Header counts and "Next:" always use this, not the filtered list.
    private var allRows: [Row] = []
    private(set) var selectedFilter: Filter = .all

    // Call before reloading the table (e.g. in viewWillAppear). Keeps the current filter.
    func refresh() {
        let snapshot = ProgressSnapshot.current()
        allRows = BadgeRules.all.map { Row(badge: $0, progress: $0.progress(in: snapshot)) }
    }

    func setFilter(_ filter: Filter) {
        selectedFilter = filter
    }

    var rows: [Row] {
        switch selectedFilter {
        case .all: return allRows
        case .earned: return allRows.filter { $0.progress.isEarned }
        case .inProgress: return allRows.filter { $0.progress.isInProgress }
        case .locked: return allRows.filter { $0.progress.isLocked }
        }
    }

    var earnedCount: Int { return allRows.filter { $0.progress.isEarned }.count }
    var inProgressCount: Int { return allRows.filter { $0.progress.isInProgress }.count }
    var lockedCount: Int { return allRows.filter { $0.progress.isLocked }.count }
    var totalCount: Int { return allRows.count }
    var fraction: Float { return totalCount > 0 ? Float(earnedCount) / Float(totalCount) : 0 }
    var headerText: String { return "\(earnedCount) of \(totalCount) badges" }

    // Chip titles. Earned and In progress include a count, matching the mockup.
    func title(for filter: Filter) -> String {
        switch filter {
        case .all: return filter.title
        case .earned: return "\(filter.title) · \(earnedCount)"
        case .inProgress: return "\(filter.title) · \(inProgressCount)"
        case .locked: return filter.title
        }
    }

    var emptyText: String {
        switch selectedFilter {
        case .all:
            return "No badges to show."
        case .earned:
            return "No badges earned yet. Complete a quiz to unlock your first one."
        case .inProgress:
            return "No badges in progress. Take a quiz to start working toward one."
        case .locked:
            return "No locked badges — you've started or earned them all."
        }
    }

    // The locked badge the user is closest to (from all badges, not the filtered list).
    var nextText: String {
        let remaining = allRows.filter { !$0.progress.isEarned }
        guard let first = remaining.first else { return "All badges earned!" }
        let closest = remaining.max(by: { $0.progress.fraction < $1.progress.fraction }) ?? first
        return "Next: \(closest.badge.name)"
    }
}
