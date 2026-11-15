import Foundation
import Supabase

@MainActor
final class AIQuizService {

    static let shared = AIQuizService()
    private init() {}

    enum AIQuizError: LocalizedError {
        case notSignedIn
        case accountChanged
        case limitReached
        case authRejected
        case offline
        case serviceUnavailable
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You're not signed in."
            case .accountChanged:
                return "The signed-in account changed."
            case .limitReached:
                return "The daily AI quiz limit is used up. It resets at 5:30 AM IST."
            case .authRejected:
                return "The server couldn't verify your sign-in. Try logging out and in again."
            case .offline:
                return "Couldn't reach the server. Check your internet connection."
            case .serviceUnavailable:
                return "The AI quiz service is unavailable right now."
            case .invalidResponse:
                return "The AI quiz came back in an unexpected format."
            }
        }
    }

    private struct RequestBody: Encodable {
        let moduleTitle: String
    }

    private struct QuestionDTO: Decodable {
        let text: String
        let options: [String]
        let correctIndex: Int
        let explanation: String
    }

    private struct ResponseBody: Decodable {
        let questions: [QuestionDTO]
    }

    func generateQuestions(
        for moduleTitle: String,
        expectedUserID: UUID?
    ) async throws -> [StudyQuestion] {
        guard let expectedUserID = expectedUserID else {
            throw AIQuizError.notSignedIn
        }
        let client = SupabaseManager.shared.client

        guard client.auth.currentSession?.user.id == expectedUserID else {
            throw AIQuizError.accountChanged
        }

        let session: Session
        do {
            session = try await client.auth.session
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw AIQuizError.offline
        } catch {
            throw AIQuizError.notSignedIn
        }
        try Task.checkCancellation()

        guard session.user.id == expectedUserID,
              client.auth.currentSession?.user.id == expectedUserID else {
            throw AIQuizError.accountChanged
        }

        let options = FunctionInvokeOptions(
            headers: ["Authorization": "Bearer \(session.accessToken)"],
            body: RequestBody(moduleTitle: moduleTitle),
            timeoutInterval: 35
        )

        let response: ResponseBody
        do {
            response = try await client.functions.invoke(
                "generate-quiz",
                options: options
            )
        } catch FunctionsError.httpError(let code, _) {
            switch code {
            case 401:
                throw AIQuizError.authRejected
            case 429:
                throw AIQuizError.limitReached
            default:
                throw AIQuizError.serviceUnavailable
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw AIQuizError.offline
        } catch is DecodingError {
            throw AIQuizError.invalidResponse
        } catch {
            throw AIQuizError.serviceUnavailable
        }

        guard client.auth.currentSession?.user.id == expectedUserID else {
            throw AIQuizError.accountChanged
        }

        guard response.questions.count == 5 else {
            throw AIQuizError.invalidResponse
        }

        var questions: [StudyQuestion] = []
        for question in response.questions {
            let text = question.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let explanation = question.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
            let options = question.options.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            guard !text.isEmpty, !explanation.isEmpty,
                  options.count == 4,
                  !options.contains(where: { $0.isEmpty }),
                  Set(options.map { $0.lowercased() }).count == 4,
                  (0...3).contains(question.correctIndex) else {
                throw AIQuizError.invalidResponse
            }

            questions.append(StudyQuestion(
                text: text,
                options: options,
                correctIndex: question.correctIndex,
                explanation: explanation
            ))
        }
        return questions
    }
}
