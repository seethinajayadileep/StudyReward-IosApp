import Foundation

struct StudyQuestion {
    let text: String
    let options: [String]   // always 4
    let correctIndex: Int   // 0 = A, 1 = B, 2 = C, 3 = D
    let explanation: String
}

enum QuestionBank {
    static func questions(for moduleTitle: String) -> [StudyQuestion] {
        switch moduleTitle {
        case "Phishing Basics":
            return [
                StudyQuestion(text: "An email says your account locks today unless you click a link. This is…",
                              options: ["Normal", "A phishing warning sign", "A security upgrade", "A receipt"],
                              correctIndex: 1, explanation: "Urgent pressure is a common phishing trick."),
                StudyQuestion(text: "What should you check before clicking a link?",
                              options: ["Where it really goes", "Its colour", "Its font", "Nothing"],
                              correctIndex: 0, explanation: "Hover or long-press to see the real address."),
                StudyQuestion(text: "Unsure if a bank message is real? You should…",
                              options: ["Reply with your PIN", "Click the link", "Use the bank's official app", "Forward it to friends"],
                              correctIndex: 2, explanation: "Contact the company through a channel you trust."),
                StudyQuestion(text: "Which detail is most suspicious?",
                              options: ["Your name", "A sender like paypa1-support.xyz", "A company logo", "A short message"],
                              correctIndex: 1, explanation: "Look-alike sender addresses are a red flag."),
                StudyQuestion(text: "A real company will usually NOT ask you to…",
                              options: ["Read a newsletter", "Update the app", "Check an order", "Send your password by email"],
                              correctIndex: 3, explanation: "Never share passwords through email or chat.")
            ]
        case "Budgeting 101":
            return [
                StudyQuestion(text: "What is a budget?",
                              options: ["A loan", "A plan for your money", "A bank account", "A tax"],
                              correctIndex: 1, explanation: "A budget plans how income is used."),
                StudyQuestion(text: "What is the first step in budgeting?",
                              options: ["List income and expenses", "Buy shares", "Get a credit card", "Stop all spending"],
                              correctIndex: 0, explanation: "You need to know what comes in and goes out."),
                StudyQuestion(text: "Which is usually a NEED?",
                              options: ["Concert tickets", "New game", "Rent", "Takeaway coffee"],
                              correctIndex: 2, explanation: "Housing is an essential need."),
                StudyQuestion(text: "Why track spending for a few weeks?",
                              options: ["To spend more", "It's required by law", "To skip saving", "To see where money goes"],
                              correctIndex: 3, explanation: "Tracking shows your real spending habits."),
                StudyQuestion(text: "A simple budget splits money into…",
                              options: ["Needs, wants, savings", "Cash and cards", "Mornings and nights", "Bills only"],
                              correctIndex: 0, explanation: "Needs, wants and savings is an easy starting split.")
            ]
        case "Swift Variables & Loops":
            return [
                StudyQuestion(text: "Which keyword makes a value that can't change?",
                              options: ["var", "let", "func", "loop"],
                              correctIndex: 1, explanation: "let creates a constant."),
                StudyQuestion(text: "Which keyword makes a value that can change?",
                              options: ["let", "static", "var", "case"],
                              correctIndex: 2, explanation: "var creates a variable."),
                StudyQuestion(text: "var points = 0, then points += 10. What is points?",
                              options: ["0", "1", "100", "10"],
                              correctIndex: 3, explanation: "0 + 10 = 10."),
                StudyQuestion(text: "Which loop runs once for each item in an array?",
                              options: ["for-in", "if-else", "switch", "guard"],
                              correctIndex: 0, explanation: "for item in array { … } visits every item."),
                StudyQuestion(text: "How many times does for i in 1...3 run?",
                              options: ["2", "3", "4", "1"],
                              correctIndex: 1, explanation: "1...3 includes 1, 2 and 3.")
            ]
        case "Recycling Basics":
            return [
                StudyQuestion(text: "What does recycling do?",
                              options: ["Burns waste", "Buries waste", "Turns used materials into new products", "Hides waste"],
                              correctIndex: 2, explanation: "Materials are processed and reused."),
                StudyQuestion(text: "Which item is commonly recyclable?",
                              options: ["Cardboard box", "Greasy tissue", "Used nappy", "Food scraps"],
                              correctIndex: 0, explanation: "Clean cardboard is widely accepted."),
                StudyQuestion(text: "Before recycling a jar, a good habit is to…",
                              options: ["Fill it with soil", "Rinse it", "Break it", "Paint it"],
                              correctIndex: 1, explanation: "Rinsing usually helps, but follow your local recycling instructions."),
                StudyQuestion(text: "Recyclables should be kept…",
                              options: ["Wet", "Mixed with food", "In plastic bags always", "Clean and dry"],
                              correctIndex: 3, explanation: "Dirty or wet items can spoil a batch."),
                StudyQuestion(text: "Why check local guidelines?",
                              options: ["Rules are the same everywhere", "Rules vary by area", "It's not needed", "To pay a fee"],
                              correctIndex: 1, explanation: "Accepted items differ between areas.")
            ]
        case "Sleep Hygiene":
            return [
                StudyQuestion(text: "Sleep hygiene means…",
                              options: ["Washing bedsheets", "Sleeping all day", "Habits that support good sleep", "Using sleep apps only"],
                              correctIndex: 2, explanation: "It's about routines and environment."),
                StudyQuestion(text: "Which habit can help sleep?",
                              options: ["Similar bedtime each day", "Random bedtimes", "Bright screens late", "Loud music in bed"],
                              correctIndex: 0, explanation: "A regular schedule can help your body clock."),
                StudyQuestion(text: "A bedroom for sleep is ideally…",
                              options: ["Hot and bright", "Noisy", "Full of screens", "Cool, dark and quiet"],
                              correctIndex: 3, explanation: "These conditions make rest easier for many people."),
                StudyQuestion(text: "Before bed, it may help to…",
                              options: ["Play intense games", "Dim screens", "Drink lots of coffee", "Work late"],
                              correctIndex: 1, explanation: "Less bright light can help you wind down."),
                StudyQuestion(text: "If sleep problems continue, you should…",
                              options: ["Ignore them", "Stay up later", "Talk to a healthcare professional", "Skip meals"],
                              correctIndex: 2, explanation: "Ongoing problems are worth professional advice.")
            ]
        case "Time Management":
            return [
                StudyQuestion(text: "Good time management starts with…",
                              options: ["Knowing your priorities", "Doing everything at once", "Avoiding plans", "Working all night"],
                              correctIndex: 0, explanation: "Priorities guide where your time goes."),
                StudyQuestion(text: "Which plan is more manageable?",
                              options: ["Do every task today", "Plan nothing", "Choose a few priorities", "Switch tasks constantly"],
                              correctIndex: 2, explanation: "Focusing on a few priorities keeps the day realistic."),
                StudyQuestion(text: "What helps with a big task?",
                              options: ["Delay it", "Break it into small steps", "Do it last minute", "Ignore deadlines"],
                              correctIndex: 1, explanation: "Small steps make progress easier."),
                StudyQuestion(text: "A focused block example is…",
                              options: ["5 hours, no break", "2 minutes", "Multitasking", "25 minutes, then a short break"],
                              correctIndex: 3, explanation: "Short focused blocks with breaks help concentration."),
                StudyQuestion(text: "A to-do list helps you…",
                              options: ["See and order your tasks", "Forget tasks", "Add stress", "Skip planning"],
                              correctIndex: 0, explanation: "Writing tasks down makes them easier to plan.")
            ]
        default:
            return []
        }
    }
}
