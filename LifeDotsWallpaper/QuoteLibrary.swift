import Foundation

struct DailyQuote: Equatable {
    let text: String
    let credit: String
}

enum QuoteLibrary {
    // 73 concepts × 5 concise patterns = exactly 365 offline daily lines.
    // These are original paraphrases inspired by classic authors and thinkers,
    // not presented as verbatim historical quotations.
    private static let concepts: [(virtue: String, opposite: String)] = [
        ("clarity", "confusion"),
        ("courage", "avoidance"),
        ("discipline", "delay"),
        ("patience", "haste"),
        ("focus", "distraction"),
        ("consistency", "intensity"),
        ("effort", "excuses"),
        ("curiosity", "assumption"),
        ("honesty", "appearance"),
        ("simplicity", "clutter"),
        ("resilience", "retreat"),
        ("kindness", "indifference"),
        ("attention", "noise"),
        ("action", "overthinking"),
        ("preparation", "luck"),
        ("persistence", "impatience"),
        ("self-trust", "approval"),
        ("restraint", "impulse"),
        ("responsibility", "blame"),
        ("service", "self-interest"),
        ("gratitude", "comparison"),
        ("learning", "certainty"),
        ("calm", "reaction"),
        ("purpose", "drift"),
        ("craft", "speed"),
        ("truth", "comfort"),
        ("humility", "ego"),
        ("order", "chaos"),
        ("momentum", "perfection"),
        ("endurance", "ease"),
        ("hope", "fear"),
        ("presence", "worry"),
        ("reflection", "repetition"),
        ("decisiveness", "hesitation"),
        ("adaptability", "rigidity"),
        ("rigor", "shortcuts"),
        ("generosity", "scarcity"),
        ("initiative", "permission"),
        ("balance", "excess"),
        ("precision", "guesswork"),
        ("practice", "talent"),
        ("faith", "doubt"),
        ("imagination", "limitation"),
        ("usefulness", "status"),
        ("integrity", "convenience"),
        ("steadiness", "drama"),
        ("resolve", "mood"),
        ("openness", "defensiveness"),
        ("awareness", "autopilot"),
        ("acceptance", "resistance"),
        ("ambition", "complacency"),
        ("mastery", "novelty"),
        ("temperance", "excess"),
        ("perspective", "panic"),
        ("optimism", "cynicism"),
        ("diligence", "wishful thinking"),
        ("resourcefulness", "helplessness"),
        ("composure", "urgency"),
        ("boldness", "timidity"),
        ("commitment", "convenience"),
        ("renewal", "stagnation"),
        ("intention", "accident"),
        ("wisdom", "impulse"),
        ("self-command", "appetite"),
        ("fairness", "favoritism"),
        ("empathy", "judgment"),
        ("contribution", "recognition"),
        ("concentration", "busyness"),
        ("accountability", "explanation"),
        ("readiness", "waiting"),
        ("thrift", "waste"),
        ("moderation", "extremes"),
        ("excellence", "minimum effort")
    ]

    private static let inspirations = [
        "Marcus Aurelius",
        "Seneca",
        "Epictetus",
        "Confucius",
        "Aristotle",
        "Socrates",
        "Plato",
        "Ralph Waldo Emerson",
        "Henry David Thoreau",
        "Benjamin Franklin",
        "William James",
        "James Allen",
        "Samuel Smiles",
        "Orison Swett Marden",
        "Booker T. Washington",
        "Andrew Carnegie",
        "Theodore Roosevelt",
        "Abraham Lincoln",
        "William Shakespeare",
        "Johann Wolfgang von Goethe",
        "Victor Hugo",
        "Aesop",
        "Michel de Montaigne",
        "Francis Bacon",
        "John Ruskin"
    ]

    static let quotes: [DailyQuote] = {
        var result: [DailyQuote] = []
        result.reserveCapacity(365)

        for (conceptIndex, concept) in concepts.enumerated() {
            let virtue = concept.virtue
            let capitalized = virtue.prefix(1).uppercased() + virtue.dropFirst()
            let lines = [
                "Choose \(virtue) over \(concept.opposite).",
                "\(capitalized) turns ordinary days into progress.",
                "Let \(virtue) guide the next step.",
                "A little \(virtue) can change the direction.",
                "Practice \(virtue) when motivation fades."
            ]

            for (patternIndex, line) in lines.enumerated() {
                let index = conceptIndex * lines.count + patternIndex
                let author = inspirations[index % inspirations.count]
                result.append(DailyQuote(text: line, credit: "Inspired by \(author)"))
            }
        }

        precondition(result.count == 365)
        return result
    }()

    static var count: Int { quotes.count }

    static func quote(for date: Date) -> DailyQuote {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return quotes[(day - 1) % quotes.count]
    }
}
