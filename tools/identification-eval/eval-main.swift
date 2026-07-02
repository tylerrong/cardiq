import Foundation

// Offline identification eval: runs real card images through the app's actual
// OCR (CardTextRecognizer) + heuristics (CardTextHeuristics), matching against
// the shipped catalog seeds, mirroring identify()'s dispatch:
//   1. number+total match (string-compare, like the live API path)
//   2. name-token fallback
//   3. CardTextHeuristics.rank for confidence ordering
// Reports top-1 accuracy and per-card failures.

struct SeedFile: Codable { var cards: [CardIdentity] }

struct ManifestEntry: Codable {
    let id: String
    let lang: String
    let name: String
    let cardNumber: String
    let url: String
}

func loadSeed(_ path: String) -> [CardIdentity] {
    let data = FileManager.default.contents(atPath: path)!
    return try! JSONDecoder().decode(SeedFile.self, from: data).cards
}

// Mirrors CardCatalogStore.searchByNumber (normalized compare).
func matchByNumberNumeric(_ number: String, _ total: String, pool: [CardIdentity]) -> [CardIdentity] {
    pool.filter { CardTextHeuristics.numberMatches(cardNumber: $0.cardNumber, numerator: number, total: total) }
}

// Mirrors CardCatalogStore.matchByName (squashed/fuzzy compare).
func matchByName(_ rawName: String, pool: [CardIdentity], limit: Int = 60) -> [CardIdentity] {
    let guess = CardTextHeuristics.squash(rawName)
    guard guess.count >= 4 else { return [] }
    var hits: [CardIdentity] = []
    for card in pool {
        let name = CardTextHeuristics.squash(card.name)
        guard name.count >= 3, CardTextHeuristics.namesSimilar(name, guess) else { continue }
        hits.append(card)
        if hits.count >= limit { break }
    }
    return hits
}

// Mirrors CardCatalogStore.searchByNumerator (promo prints, no /total).
func matchByNumerator(_ numerator: String, pool: [CardIdentity]) -> [CardIdentity] {
    let norm = CardTextHeuristics.normalizedNumerator(numerator)
    guard norm.contains(where: \.isLetter) else { return [] }
    return pool.filter { card in
        let cardNumerator = card.cardNumber.split(separator: "/").first.map(String.init) ?? card.cardNumber
        return CardTextHeuristics.normalizedNumerator(cardNumerator) == norm
    }
}

// Mirrors identifyJapanese's kana/name agreement scoring.
func rankJapanese(_ cards: [CardIdentity], guess: CardTextHeuristics.Guess) -> [CardIdentity] {
    cards.map { card in
        var copy = card
        let kana = card.variant ?? ""
        let nameAgrees = !guess.name.isEmpty && (
            card.name.contains(guess.name) || guess.name.contains(card.name) ||
            (!kana.isEmpty && (kana.contains(guess.name) || guess.name.contains(kana)))
        )
        copy.identificationConfidence = nameAgrees ? 0.95 : 0.85
        return copy
    }
    .sorted { $0.identificationConfidence > $1.identificationConfidence }
}

@main
struct Eval {
static func main() async {
let repo = ProcessInfo.processInfo.environment["CARDIQ_REPO"] ?? "/Users/andrewxue/Developer/cardiq"
let enPool = loadSeed("\(repo)/CardIQ/Resources/card-catalog-seed.json")
let jaPool = loadSeed("\(repo)/CardIQ/Resources/card-catalog-seed-ja.json")
let manifest = try! JSONDecoder().decode(
    [ManifestEntry].self,
    from: FileManager.default.contents(atPath: "\(ProcessInfo.processInfo.environment["EVAL_IMAGES"] ?? "/tmp/cardiq-eval")/manifest.json")!
)

var passed = 0, failed = 0
var failures: [String] = []

for entry in manifest {
    let imagesDir = ProcessInfo.processInfo.environment["EVAL_IMAGES"] ?? "/tmp/cardiq-eval"
    let imagePath = "\(imagesDir)/\(entry.id.replacingOccurrences(of: "/", with: "_")).png"
    guard let data = FileManager.default.contents(atPath: imagePath) else {
        print("MISSING image \(entry.id)"); continue
    }

    var lines: [RecognizedLine]
    do {
        lines = try await CardTextRecognizer.recognize(in: data)
    } catch {
        failed += 1
        failures.append("\(entry.id): OCR failed: \(error)")
        continue
    }

    var maybeGuess = CardTextHeuristics.bestGuess(from: lines)
    if maybeGuess?.number == nil,
       let bottomLines = try? await CardTextRecognizer.recognize(
           in: data,
           regionOfInterest: CGRect(x: 0, y: 0, width: 1, height: 0.16)
       ),
       !bottomLines.isEmpty {
        lines.append(contentsOf: bottomLines)
        maybeGuess = CardTextHeuristics.bestGuess(from: lines)
    }

    if maybeGuess?.number == nil {
        let stripFraction: CGFloat = 0.18
        for variant in CardImagePreprocessor.bottomStripVariants(from: data, stripFraction: stripFraction) {
            guard let stripLines = try? await CardTextRecognizer.recognize(in: variant),
                  !stripLines.isEmpty else { continue }
            let remapped = stripLines.map {
                RecognizedLine(text: $0.text, midY: $0.midY * stripFraction, height: $0.height * stripFraction)
            }
            let merged = lines + remapped
            let candidate = CardTextHeuristics.bestGuess(from: merged)
            if candidate?.number != nil {
                lines = merged
                maybeGuess = candidate
                break
            }
        }
    }

    guard let guess = maybeGuess else {
        failed += 1
        failures.append("\(entry.id): no guess from OCR (lines: \(lines.count))")
        continue
    }

    let japaneseLineCount = lines.count(where: { CardTextHeuristics.containsJapanese($0.text) })
    let isJapanese = CardTextHeuristics.containsJapanese(guess.name) || japaneseLineCount >= 2

    var ranked: [CardIdentity] = []
    if isJapanese {
        var matches: [CardIdentity] = []
        if let n = guess.number, let t = guess.setTotal {
            matches = matchByNumberNumeric(n, t, pool: jaPool)
        }
        if matches.isEmpty, !guess.name.isEmpty {
            matches = jaPool.filter { ($0.variant ?? "").contains(guess.name) || $0.name.lowercased().contains(guess.name.lowercased()) }
        }
        ranked = rankJapanese(matches, guess: guess)
    }
    if ranked.isEmpty {
        var matches: [CardIdentity] = []
        if let n = guess.number, let t = guess.setTotal {
            matches = matchByNumberNumeric(n, t, pool: enPool)
        } else if let n = guess.number {
            matches = matchByNumerator(n, pool: enPool)
        }
        if matches.isEmpty {
            matches = matchByName(guess.name, pool: enPool)
        }
        ranked = CardTextHeuristics.rank(matches, against: guess)
    }

    let top = ranked.first
    let hit = top?.id.caseInsensitiveCompare(entry.id) == .orderedSame
    if hit {
        passed += 1
        let conf = top.map { String(format: "%.2f", $0.identificationConfidence) } ?? "-"
        print("PASS \(entry.id)  conf=\(conf)  guess=(\(guess.name) | \(guess.number ?? "-")/\(guess.setTotal ?? "-"))")
    } else {
        failed += 1
        let got = top.map { "\($0.id) (\(String(format: "%.2f", $0.identificationConfidence)))" } ?? "nothing"
        failures.append("\(entry.id) [\(entry.name) \(entry.cardNumber)]: got \(got), guess=(\(guess.name) | \(guess.number ?? "-")/\(guess.setTotal ?? "-")), candidates=\(ranked.count)")
        print("FAIL \(entry.id)  got=\(got)  guess=(\(guess.name) | \(guess.number ?? "-")/\(guess.setTotal ?? "-"))")
    }
}

print("\n===== RESULT: \(passed)/\(passed + failed) top-1 =====")
if !failures.isEmpty {
    print("\nFailures:")
    failures.forEach { print("  - \($0)") }
}
}
}
