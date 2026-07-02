import Foundation
import Vision
import ImageIO
import CoreGraphics

// MARK: - Live Card Identification (pokemontcg.io)

/// Real implementation of `CardIdentificationService` backed by the public
/// pokemontcg.io catalog. Drop-in replacement for `MockCardIdentificationService`.
///
/// - `search(query:)` / `allCards()` query the catalog API directly.
/// - `identify(frontImage:backImage:)` runs on-device OCR (Vision) to read the
///   card name + collector number, then resolves it against the catalog.
///
/// Works with no API key (rate-limited). Pass an `apiKey` to raise the limits.
final class PokemonTCGCardIdentificationService: CardIdentificationService {
    private let client: PokemonTCGClient

    init(client: PokemonTCGClient = PokemonTCGClient()) {
        self.client = client
    }

    func identify(frontImage: Data, backImage: Data?) async throws -> [CardIdentity] {
        // Decode + OCR the photo. If the bytes aren't a real image — e.g. the
        // Simulator's placeholder data, since there's no camera — fall back to a
        // live browse list so the scan flow still surfaces real candidate cards
        // instead of hard-failing. On a real device a genuine photo is read here.
        let lines: [RecognizedLine]
        do {
            lines = try await CardTextRecognizer.recognize(in: frontImage)
        } catch {
            return await allCards()
        }

        guard let guess = CardTextHeuristics.bestGuess(from: lines) else {
            throw CIQError.identificationFailed
        }

        // Japanese card: the OCR'd name is kana/kanji. Route to the local
        // Japanese catalog — the English catalog would otherwise "match" the
        // collector number against an unrelated English set.
        if CardTextHeuristics.containsJapanese(guess.name) || lines.contains(where: { CardTextHeuristics.containsJapanese($0.text) }) {
            let jpMatches = await identifyJapanese(guess: guess)
            if !jpMatches.isEmpty { return jpMatches }
            // Fall through: script detection can misfire on holo glare.
        }

        // The collector number "NNN/NNN" is the most reliable id — number + set total
        // pin the exact card. Fall back to the name only when the number isn't read.
        let matches: [CardIdentity]
        if let number = guess.number, let total = guess.setTotal {
            matches = try await client.searchByNumber(number: number, setTotal: total, name: guess.name)
        } else {
            matches = try await client.searchCards(name: guess.name, number: guess.number)
        }

        guard !matches.isEmpty else { throw CIQError.identificationFailed }
        return CardTextHeuristics.rank(matches, against: guess)
    }

    /// Japanese identification against the local TCGdex catalog: collector
    /// number + printed total first (numeric compare handles zero-padding),
    /// then a name search. Confidence mirrors the English heuristics — a
    /// number match whose name also agrees is near-certain.
    private func identifyJapanese(guess: CardTextHeuristics.Guess) async -> [CardIdentity] {
        var matches: [CardIdentity] = []
        if let number = guess.number, let total = guess.setTotal {
            matches = await CardCatalogStore.shared.searchByNumber(number, total: total, language: "ja")
        }
        if matches.isEmpty, !guess.name.isEmpty {
            matches = await CardCatalogStore.shared.search(guess.name).filter { $0.language == "ja" }
        }
        return matches.map { card in
            var copy = card
            // The OCR read is kana; catalog names are English with the original
            // Japanese name in `variant` — compare against both.
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

    func search(query: String) async throws -> [CardIdentity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Local catalog first: instant, no rate limits. While the download is
        // still in progress (newest sets land first), a local miss falls back to
        // the live API so older cards remain findable.
        let local = await CardCatalogStore.shared.search(trimmed)
        if !local.isEmpty { return local }
        if await CardCatalogStore.shared.hasFullCatalog { return [] }
        return try await client.searchCards(name: trimmed, number: nil)
    }

    func allCards() async -> [CardIdentity] {
        // Browse feed: newest cards from the local catalog; live fallback while
        // the catalog is still downloading.
        let local = await CardCatalogStore.shared.browse()
        if !local.isEmpty { return local }
        return (try? await client.searchRaw(query: "(set.id:sv6 OR set.id:sv7 OR set.id:sv8) rarity:\"Special Illustration Rare\"", pageSize: 30)) ?? []
    }
}

// MARK: - Catalog API Client

final class PokemonTCGClient {
    private let baseURL = URL(string: "https://api.pokemontcg.io/v2")!
    private let apiKey: String?
    private let session: URLSession

    init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Forgiving name (+ optional collector number) search.
    func searchCards(name: String, number: String?) async throws -> [CardIdentity] {
        try await searchRaw(query: Self.buildQuery(name: name, number: number), pageSize: 20)
    }

    /// Strongest lookup: collector number + set printed total (the "NNN/NNN" on the
    /// card) pin the exact set and card. Falls back to a name search if it misses.
    func searchByNumber(number: String, setTotal: String, name: String) async throws -> [CardIdentity] {
        let exact = try await searchRaw(
            query: "number:\(number) set.printedTotal:\(setTotal)",
            pageSize: 10
        )
        if !exact.isEmpty { return exact }
        return try await searchCards(name: name, number: number)
    }

    /// Raw Lucene-style query against `/cards`.
    func searchRaw(query: String, pageSize: Int) async throws -> [CardIdentity] {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("cards"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "-set.releaseDate")
        ]

        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 15
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key") }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw CIQError.unknown("No HTTP response from catalog")
            }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 429 {
                    throw CIQError.unknown("Catalog rate limit reached. Add an API key to raise it.")
                }
                throw CIQError.unknown("Catalog API error (\(http.statusCode))")
            }
            let decoded = try JSONDecoder().decode(PokemonTCGSearchResponse.self, from: data)
            return decoded.data.map(PokemonTCGMapper.cardIdentity(from:))
        } catch let error as CIQError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw CIQError.networkTimeout
        } catch is DecodingError {
            throw CIQError.identificationFailed
        } catch {
            throw CIQError.networkTimeout
        }
    }

    /// Fetches one page of the full catalog (newest sets first), trimmed to the
    /// fields the app needs. Returns the page plus the API's total card count so
    /// the caller knows when the download is complete.
    func fetchCatalogPage(page: Int, pageSize: Int) async throws -> ([CardIdentity], Int) {
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("cards"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
            URLQueryItem(name: "orderBy", value: "-set.releaseDate"),
            URLQueryItem(name: "select", value: "id,name,number,rarity,images,set")
        ]

        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 30
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key") }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CIQError.networkTimeout
        }
        let decoded = try JSONDecoder().decode(PokemonTCGSearchResponse.self, from: data)
        return (decoded.data.map(PokemonTCGMapper.cardIdentity(from:)), decoded.totalCount ?? decoded.data.count)
    }

    /// Fetches a single card (with embedded price data) by its catalog id.
    func card(id: String) async throws -> PokemonTCGCard {
        let url = baseURL.appendingPathComponent("cards").appendingPathComponent(id)
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        if let apiKey { request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key") }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw CIQError.marketDataUnavailable
            }
            return try JSONDecoder().decode(PokemonTCGCardResponse.self, from: data).data
        } catch let error as CIQError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw CIQError.networkTimeout
        } catch {
            throw CIQError.marketDataUnavailable
        }
    }

    /// Builds `name:*token* name:*token* number:NN` from free text.
    private static func buildQuery(name: String, number: String?) -> String {
        let tokens = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 2 }
        var parts = tokens.map { "name:*\($0)*" }
        if let number, !number.isEmpty {
            parts.append("number:\(number)")
        }
        if parts.isEmpty {
            return "name:*\(name.lowercased())*"
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - API DTOs

struct PokemonTCGSearchResponse: Decodable {
    let data: [PokemonTCGCard]
    let totalCount: Int?
}

struct PokemonTCGCardResponse: Decodable {
    let data: PokemonTCGCard
}

struct PokemonTCGCard: Decodable {
    let id: String
    let name: String
    let number: String?
    let rarity: String?
    let images: Images?
    let set: SetInfo?
    let tcgplayer: TCGPlayer?
    let cardmarket: Cardmarket?

    struct Images: Decodable {
        let small: String?
        let large: String?
    }

    struct TCGPlayer: Decodable {
        let updatedAt: String?
        let prices: [String: PriceTier]?
    }

    struct PriceTier: Decodable {
        let low: Double?
        let mid: Double?
        let high: Double?
        let market: Double?
        let directLow: Double?
    }

    struct Cardmarket: Decodable {
        let updatedAt: String?
        let prices: CMPrices?
    }

    struct CMPrices: Decodable {
        let averageSellPrice: Double?
        let trendPrice: Double?
        let avg1: Double?
        let avg7: Double?
        let avg30: Double?
    }

    struct SetInfo: Decodable {
        let id: String?
        let name: String?
        let series: String?
        let printedTotal: Int?
        let ptcgoCode: String?
        let releaseDate: String?
    }
}

// MARK: - DTO -> Domain Mapping

enum PokemonTCGMapper {
    static func cardIdentity(from dto: PokemonTCGCard) -> CardIdentity {
        let rarity = mapRarity(dto.rarity)
        let number = dto.number ?? ""
        let cardNumber = dto.set?.printedTotal.map { "\(number)/\($0)" } ?? number
        let setCode = (dto.set?.ptcgoCode ?? dto.set?.id ?? "").uppercased()

        return CardIdentity(
            id: dto.id,
            category: .pokemon,
            name: dto.name,
            setName: dto.set?.name ?? "Unknown Set",
            setCode: setCode,
            cardNumber: cardNumber,
            year: parseYear(dto.set?.releaseDate) ?? 0,
            variant: dto.rarity,
            rarity: rarity,
            language: "en",
            isFirstEdition: false,
            isHolo: isHoloRarity(rarity),
            isReverseHolo: false,
            imageURL: dto.images?.large ?? dto.images?.small ?? constructImageURL(setID: dto.set?.id, number: dto.number),
            identificationConfidence: 0.9
        )
    }

    /// pokemontcg.io serves card art at a deterministic path, so we can always
    /// produce an image URL even if the API payload omits the `images` object.
    static func constructImageURL(setID: String?, number: String?) -> String? {
        guard let setID, let number, !setID.isEmpty, !number.isEmpty else { return nil }
        return "https://images.pokemontcg.io/\(setID)/\(number)_hires.png"
    }

    static func mapRarity(_ raw: String?) -> CardRarity {
        guard let r = raw?.lowercased() else { return .rare }
        if r.contains("special illustration") { return .specialIllustrationRare }
        if r.contains("illustration") { return .illustrationRare }
        if r.contains("hyper") || r.contains("rainbow") { return .hyperRare }
        if r.contains("secret") { return .secretRare }
        if r.contains("full art") { return .fullArt }
        if r.contains("double rare") || r.contains("ultra") { return .ultraRare }
        if r.contains("trainer gallery") { return .trainerGallery }
        if r.contains("reverse") { return .reverseHolo }
        if r.contains("holo") { return .holo }
        if r == "uncommon" { return .uncommon }
        if r == "common" { return .common }
        return .rare
    }

    static func isHoloRarity(_ rarity: CardRarity) -> Bool {
        switch rarity {
        case .common, .uncommon, .rare, .reverseHolo: return false
        default: return true
        }
    }

    static func parseYear(_ releaseDate: String?) -> Int? {
        guard let s = releaseDate, s.count >= 4 else { return nil }
        return Int(s.prefix(4))
    }
}

// MARK: - On-device OCR (Vision)

struct RecognizedLine: Sendable {
    let text: String
    let midY: CGFloat   // Vision space: 0 = bottom, 1 = top
    let height: CGFloat // relative glyph height ≈ font size
}

enum CardTextRecognizer {
    /// Recognizes text from card image data, preserving each line's position so the
    /// heuristics can use it (name = top + biggest font; number = NNN/NNN near bottom).
    static func recognize(in imageData: Data) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            // Read Japanese prints too — kana/kanji names route identification
            // to the Japanese catalog.
            request.automaticallyDetectsLanguage = true
            request.recognitionLanguages = ["ja-JP", "en-US"]

            // Data-based handler applies the image's EXIF orientation. Photos from
            // the picker/camera are often rotated; a CGImage handler ignores that and
            // OCR comes back sideways/unreadable. Throws on non-image bytes (e.g. the
            // Simulator placeholder) → caught upstream as the browse fallback.
            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try handler.perform([request])

            return (request.results ?? []).compactMap { observation in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                return RecognizedLine(
                    text: text,
                    midY: observation.boundingBox.midY,
                    height: observation.boundingBox.height
                )
            }
        }.value
    }
}

// MARK: - Name / Number Heuristics

enum CardTextHeuristics {
    struct Guess {
        let name: String
        let number: String?
        let setTotal: String?
    }

    private static let nonNamePrefixes = ["basic", "stage", "evolves", "ability", "hp", "weakness", "resistance", "retreat", "no."]

    static func bestGuess(from lines: [RecognizedLine]) -> Guess? {
        guard !lines.isEmpty else { return nil }

        // Collector number "NNN/NNN" near the bottom — the most reliable id (the
        // total pins the set, the numerator the card).
        let collector = lines
            .sorted { $0.midY < $1.midY }
            .compactMap { collectorNumber(in: $0.text) }
            .first

        // Card name: top of the card (high midY in Vision space), biggest font,
        // skipping structural labels (HP, Stage, Ability, attack text, etc.).
        let topName = lines
            .filter { $0.midY > 0.55 && isNameLike($0.text) }
            .max(by: { $0.height < $1.height })?.text
        let fallbackName = lines
            .filter { isNameLike($0.text) }
            .max(by: { $0.height < $1.height })?.text
        let rawName = topName ?? fallbackName

        // Identify off a number or a name (number alone is enough and most accurate).
        guard collector != nil || rawName != nil else { return nil }

        return Guess(
            name: rawName.map(cleanName) ?? "",
            number: collector?.numerator,
            setTotal: collector?.total
        )
    }

    /// True when the text contains hiragana, katakana, or kanji — the signal
    /// that a scanned card is a Japanese print.
    static func containsJapanese(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3040...0x30FF).contains(scalar.value) ||   // hiragana + katakana
            (0x4E00...0x9FFF).contains(scalar.value)      // CJK unified ideographs
        }
    }

    private static func isNameLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        if nonNamePrefixes.contains(where: { lower.hasPrefix($0) }) { return false }
        return text.filter { $0.isLetter }.count >= 3
    }

    /// Cleans OCR noise from a name: "Charizard@X" -> "Charizard ex", strips symbols.
    private static func cleanName(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "@X", with: " ex")
                   .replacingOccurrences(of: "@x", with: " ex")
        s = String(s.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" })
        return s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Returns the numerator and set-total of a "NNN/NNN" collector number.
    private static func collectorNumber(in text: String) -> (numerator: String, total: String)? {
        guard let regex = try? NSRegularExpression(pattern: "\\b(\\d{1,3})/(\\d{1,3})\\b") else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let numeratorRange = Range(match.range(at: 1), in: text),
              let totalRange = Range(match.range(at: 2), in: text) else { return nil }
        return (String(text[numeratorRange]), String(text[totalRange]))
    }

    static func rank(_ cards: [CardIdentity], against guess: Guess) -> [CardIdentity] {
        cards
            .map { card -> CardIdentity in
                var copy = card
                copy.identificationConfidence = confidence(card, guess)
                return copy
            }
            .sorted { $0.identificationConfidence > $1.identificationConfidence }
    }

    private static func confidence(_ card: CardIdentity, _ guess: Guess) -> Double {
        let cardName = card.name.lowercased()
        let guessName = guess.name.lowercased()
        let nameAgrees = !guessName.isEmpty &&
            (cardName.contains(guessName) || guessName.contains(cardName))

        // Exact collector number + set total is a strong, usually-unique match —
        // but require the OCR'd name not to contradict it. This breaks ties when
        // several cards share a number and de-rates a likely OCR misread, so the
        // confirm screen flags it for the user instead of asserting 97%.
        if let number = guess.number, let total = guess.setTotal,
           card.cardNumber == "\(number)/\(total)" {
            if guessName.isEmpty { return 0.9 }   // no name read — trust the number
            if nameAgrees { return 0.97 }         // number + name agree — near-certain
            return 0.72                           // number matched but name disagrees
        }

        var score = 0.5
        if nameAgrees { score += 0.3 }
        if let number = guess.number, card.cardNumber.hasPrefix(number) {
            score += 0.2
        }
        return min(score, 0.99)
    }
}
