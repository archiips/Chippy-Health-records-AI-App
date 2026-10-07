import Foundation

/// Small deterministic intents keep record lookup useful when language models are unavailable.
enum LocalChatIntent {
    static let stopWords: Set<String> = ["find", "what", "when", "where", "was", "were", "are", "is", "my", "the", "a", "an", "in", "on", "of", "for", "and", "about", "show", "me", "please", "records", "record", "results", "result", "can", "you", "have", "do", "did", "i", "to", "does", "this", "tell", "with", "recorded", "health", "last", "latest", "most", "recent", "lab", "labs", "work", "blood", "medication", "medications", "prescription", "prescriptions", "mentions", "mentioned", "summarize", "summary", "overview", "visits", "visit", "diagnosis", "level", "levels", "test", "tests", "explain", "mean", "means", "say", "says", "understand", "normal", "abnormal", "okay", "ok", "that", "those", "these", "it", "they", "them", "more"]

    static func words(_ question: String) -> [String] {
        question.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
    static func terms(_ question: String) -> [String] { words(question).filter { $0.count > 2 && !stopWords.contains($0) } }
    static func isFollowUp(_ question: String) -> Bool {
        let tokens = Set(words(question))
        return !tokens.isDisjoint(with: ["that", "it", "those", "they", "them", "more"]) && terms(question).isEmpty
    }
    static func help(_ question: String) -> String? {
        let query = words(question).joined(separator: " ")
        if ["hi", "hello", "hey", "hello chippy", "hi chippy"].contains(query) {
            return "Hi! I can help you find results and medication mentions in your records. Try ‘Show my test results’ or ‘Find glucose’. Add a photo or scan from Records if you haven't imported one yet."
        }
        if ["help", "what can you do", "how does this work"].contains(query) {
            return "I look up information in your imported records and link to the original pages. Try ‘Show my test results’, ‘Summarize my records’, or a test or medication name. Reviewed facts give clearer answers; unreviewed pages are shown as OCR excerpts. I cannot diagnose or recommend treatment."
        }
        if ["thanks", "thank you"].contains(query) { return "You're welcome. You can ask about another result or open a source page to check the original." }
        return nil
    }
    static func needsClinicalJudgment(_ question: String) -> Bool {
        let tokens = Set(words(question))
        return !tokens.isDisjoint(with: ["normal", "abnormal", "okay", "worried", "dangerous", "diagnose", "diagnosis", "treatment"]) || question.lowercased().contains("should i")
    }
}
