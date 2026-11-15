//
//  StudyModule.swift
//  StudyReward
//
//  Created by jaya on 10/11/26.
//

import UIKit

// One learning module. The title is also the ID used by ProgressStore, QuestionBank and the AI quiz,
// so never rename a title.
struct StudyModule {
    let title: String
    let category: String
    let summary: String
    let iconName: String   // SF Symbol name
    let lesson: String

    var color: UIColor {
        switch category {
        case "Security": return UIColor(red: 0.898, green: 0.282, blue: 0.302, alpha: 1)
        case "Money": return UIColor(red: 0.086, green: 0.639, blue: 0.290, alpha: 1)
        case "Coding": return UIColor(red: 0.145, green: 0.388, blue: 0.922, alpha: 1)
        case "Planet": return UIColor(red: 0.055, green: 0.624, blue: 0.431, alpha: 1)
        case "Wellness": return UIColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)
        case "Productivity": return UIColor(red: 0.031, green: 0.569, blue: 0.698, alpha: 1)
        default: return UIColor(red: 0.427, green: 0.302, blue: 0.894, alpha: 1)
        }
    }

    static let all: [StudyModule] = [
        StudyModule(
            title: "Phishing Basics",
            category: "Security",
            summary: "Spot fake emails and messages before you click.",
            iconName: "checkmark.shield",
            lesson: """
            Phishing messages pretend to be from someone you trust so you'll click a link or share private details. They often create urgency, like "your account will be locked today."

            Before you click, check the sender's address and hover over or long-press links to see where they really go. If you're unsure, contact the company through its official app or website instead.
            """),
        StudyModule(
            title: "Budgeting 101",
            category: "Money",
            summary: "Plan your money with needs, wants and savings.",
            iconName: "creditcard",
            lesson: """
            A budget is a plan for your money. Start by listing your monthly income and your regular expenses.

            A simple approach is to split spending into needs, wants and savings. Write down what you spend for a few weeks so you can see where your money actually goes.
            """),
        StudyModule(
            title: "Swift Variables & Loops",
            category: "Coding",
            summary: "Learn let, var and for-in loops in Swift.",
            iconName: "chevron.left.forwardslash.chevron.right",
            lesson: """
            In Swift, use let for values that never change and var for values that do. For example: var points = 0, then points += 10.

            A for-in loop repeats code for each item: for module in modules { print(module.title) }. Loops let you work through lists without repeating the same code.
            """),
        StudyModule(
            title: "Recycling Basics",
            category: "Planet",
            summary: "What can be recycled and how to prepare it.",
            iconName: "leaf",
            lesson: """
            Recycling turns used materials into new products. Paper, cardboard, glass, and many metal and plastic containers are commonly accepted.

            Keep recyclables clean and dry. Rules vary by area, so follow your local guidelines for what is accepted and how to prepare it.
            """),
        StudyModule(
            title: "Sleep Hygiene",
            category: "Wellness",
            summary: "Simple habits for regular, restful sleep.",
            iconName: "moon.zzz",
            lesson: """
            Sleep hygiene means habits that support regular, restful sleep. Going to bed and waking up at similar times each day can help.

            Try dimming screens before bed and keeping your room cool, dark and quiet. If sleep problems continue, talk to a healthcare professional.
            """),
        StudyModule(
            title: "Time Management",
            category: "Productivity",
            summary: "Set priorities and work in focused blocks.",
            iconName: "clock",
            lesson: """
            Good time management starts with knowing your priorities. List your tasks and choose a few of the most important ones for the day.

            Break big tasks into small steps and work in focused blocks, for example 25 minutes followed by a short break.
            """)
    ]

    static func named(_ title: String) -> StudyModule? {
        return all.first { $0.title == title }
    }
}

// Completion status for one module, for the signed-in account (real data only).
@MainActor
struct ModuleStatus {
    let isCompleted: Bool
    let pillText: String
    let detailText: String

    init(module: StudyModule) {
        if let record = ProgressStore.shared.bestRecord(for: module.title), record.totalQuestions > 0 {
            let percent = record.bestCorrect * 100 / record.totalQuestions
            isCompleted = true
            pillText = "Completed"
            detailText = "Best score \(percent)% (\(record.bestCorrect) of \(record.totalQuestions))"
        } else {
            isCompleted = false
            pillText = "Not started"
            detailText = "Take the quiz to complete it"
        }
    }
}

@MainActor
final class ModulesViewModel {
    let modules: [StudyModule] = StudyModule.all
    private(set) var statuses: [ModuleStatus] = []

    func refresh() {
        statuses = modules.map { ModuleStatus(module: $0) }
    }

    var completedCount: Int {
        return statuses.filter { $0.isCompleted }.count
    }

    var headerText: String {
        return "\(completedCount) of \(modules.count) completed"
    }
}
