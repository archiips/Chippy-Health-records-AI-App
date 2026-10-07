import Foundation

struct FactCandidate: Codable, Sendable {
    var kind: String
    var name: String
    var value: String
    var unit: String?
    var referenceRange: String?
    var dateText: String?
    var quote: String
}

enum FactEvidence {
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func validate(_ candidate: FactCandidate, in page: DocumentPage) -> Bool {
        let quote = normalized(candidate.quote)
        guard !quote.isEmpty, !normalized(candidate.name).isEmpty, !normalized(candidate.value).isEmpty,
              ["lab", "medication", "diagnosis", "finding", "visit"].contains(candidate.kind),
              normalized(page.text).contains(quote) else { return false }
        let fields = [candidate.name, candidate.value] + [candidate.unit, candidate.referenceRange, candidate.dateText].compactMap { $0 }.filter { !$0.isEmpty }
        return fields.allSatisfy { field in
            let escaped = NSRegularExpression.escapedPattern(for: normalized(field))
            let pattern = "(?<![\\p{L}\\p{N}.+−\\-<>≤≥])" + escaped + "(?![\\p{L}\\p{N}.+−\\-<>≤≥])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return false }
            return regex.matches(in: quote, range: NSRange(quote.startIndex..., in: quote)).contains { match in
                guard let range = Range(match.range, in: quote) else { return false }
                guard normalized(field).first?.isNumber == true || normalized(field).first == "." else { return true }
                let prefix = quote[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                let suffix = quote[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                let operators = "+−-<>≤≥×^*"
                if let previous = prefix.last, operators.contains(previous) { return false }
                if let next = suffix.first, operators.contains(next) { return false }
                if prefix.last == ",", prefix.dropLast().last?.isNumber == true { return false }
                if suffix.first == ",", suffix.dropFirst().first?.isNumber == true { return false }
                return true
            }
        }
    }
}
