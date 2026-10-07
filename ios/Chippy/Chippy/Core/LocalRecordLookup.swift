import Foundation

/// Record lookup assembles answers from stored fields and source text, never generated medical claims.
enum LocalRecordLookup {
    static func answer(question: String, documents: [HealthDocument], selectedDocumentID: String? = nil,
                       expandedTerms: [String] = []) -> LocalRecordAnswer {
        let scoped = documents.filter { selectedDocumentID == nil || $0.id == selectedDocumentID }
        guard !scoped.isEmpty else { return LocalRecordAnswer(text: "Add a photo or scan of a medical record first. I can then find recorded results, medication mentions, and source pages on this device.", sources: []) }
        let query = question.lowercased()
        let kind: String? = query.contains("medicat") || query.contains("prescription") ? "medication" :
            query.contains("lab") || query.contains("blood work") ? "lab" :
            query.contains("visit") ? "visit" : nil
        let overview = query.contains("summar") || query.contains("overview")
        let stopWords: Set<String> = ["find", "what", "when", "where", "was", "were", "are", "is", "my", "the", "a", "an", "in", "on", "of", "for", "and", "about", "show", "me", "please", "records", "record", "results", "result", "can", "you", "have", "do", "did", "i", "to", "does", "this", "tell", "with", "recorded", "health", "last", "latest", "most", "recent", "lab", "labs", "work", "blood", "medication", "medications", "prescription", "prescriptions", "mentions", "mentioned", "summarize", "summary", "overview", "visits", "visit", "diagnosis", "level", "levels"]
        let specificTerms = query.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 2 && !stopWords.contains($0) }
        let latestQuestion = query.contains("last") || query.contains("latest") || query.contains("most recent")
        var facts = scoped.flatMap(\.recordFacts).filter { $0.isConfirmed && (kind == nil || $0.kind == kind) }
        if !specificTerms.isEmpty {
            facts = facts.filter { fact in specificTerms.contains { fact.name.localizedCaseInsensitiveContains($0) || fact.value.localizedCaseInsensitiveContains($0) } }
        }
        if latestQuestion {
            if let latest = facts.compactMap(\.eventDate).max() { facts = facts.filter { $0.eventDate == latest } }
        }
        if kind != nil || overview || !specificTerms.isEmpty {
            let ordered = facts.sorted { ($0.eventDate ?? .distantPast) > ($1.eventDate ?? .distantPast) }
            if !ordered.isEmpty {
                let selected = Array(ordered.prefix(12))
                let rows = selected.map { fact in
                    let range = fact.referenceRange.map { " · Recorded range: \($0)" } ?? (fact.kind == "lab" ? " · Reference range not recorded" : "")
                    return "\(fact.name): \(fact.value)\(fact.unit.map { " \($0)" } ?? "")\(range)\nDate: \(fact.dateText ?? "not recorded")"
                }
                let warning = (kind == "medication" ? "Historical medication mentions do not establish current use.\n\n" : "From the facts you reviewed:\n\n") + (latestQuestion ? (selected.contains { $0.eventDate != nil } ? "Latest among matching reviewed facts with a recorded date; undated records may also exist.\n\n" : "These matching facts have no unambiguous recorded date, so I cannot establish which is latest.\n\n") : "")
                var seen = Set<String>()
                let citations = selected.map {
                    LocalRecordSource(documentID: $0.documentID, pageNumber: $0.pageNumber, excerpt: $0.quote, reviewed: true)
                }.filter { seen.insert($0.id).inserted }
                return LocalRecordAnswer(text: warning + rows.joined(separator: "\n\n") + (ordered.count > 12 ? "\n\nShowing 12 matches. Narrow your question or choose a record for more." : ""), sources: citations)
            }
        }
        var terms = specificTerms
        terms += expandedTerms.prefix(6).filter { $0.count >= 3 && $0.count <= 40 }.map { $0.lowercased() }
        if kind == "medication" { terms += ["prescription", "medication", "tablet", "capsule"] }
        if kind == "lab" { terms += ["glucose", "hemoglobin", "creatinine", "laboratory"] }
        struct Match { let source: LocalRecordSource; let score: Int }
        var matches: [Match] = []
        for document in scoped {
            for page in document.pages {
                let lines = page.text.components(separatedBy: .newlines)
                let score = terms.reduce(0) { $0 + (page.text.localizedCaseInsensitiveContains($1) ? 1 : 0) }
                guard score > 0 || overview else { continue }
                let start = lines.firstIndex { line in terms.contains { line.localizedCaseInsensitiveContains($0) } } ?? 0
                let excerpt = String(lines[max(0, start - 1)..<min(lines.count, start + 9)].joined(separator: "\n").prefix(900))
                matches.append(Match(source: LocalRecordSource(documentID: document.id, pageNumber: page.number, excerpt: excerpt, reviewed: false), score: score))
            }
        }
        let sources = matches.sorted { $0.score == $1.score ? $0.source.id < $1.source.id : $0.score > $1.score }.prefix(4).map(\.source)
        guard !sources.isEmpty else { return LocalRecordAnswer(text: "I couldn't find that in the selected records. Try a test name, medication name, or wording from the document. Missing matches don't mean the event never happened.", sources: []) }
        let warning = kind == "medication" ? "Historical medication mentions do not establish current use. " : ""
        return LocalRecordAnswer(text: warning + (latestQuestion ? "I can't establish which record is latest from unreviewed text. These are matching passages, not a date-ordered answer. " : "I found these passages in your records. ") + "This is unreviewed OCR text; check numbers, dates, and units against each original page.\n\n" + sources.enumerated().map { "[\($0.offset + 1)] \($0.element.excerpt)" }.joined(separator: "\n\n"), sources: sources)
    }
}
