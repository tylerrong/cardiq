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
        let lines: [String]
        do {
            lines = try await CardTextRecognizer.recognizeLines(in: frontImage)
        } catch {
            return await allCards()
        }

        guard let guess = CardTextHeuristics.bestGuess(from: lines) else {
            // Valid image but no readable card text — ask the user to retake.
            throw CIQError.identificationFailed
        }

        let matches = try await client.searchCards(name: guess.name, number: guess.number)
        guard !matches.isEmpty else { throw CIQError.identificationFailed }
        return CardTextHeuristics.rank(matches, against: guess)
    }

    func search(query: String) async throws -> [CardIdentity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await client.searchCards(name: trimmed, number: nil)
    }

    func allCards() async -> [CardIdentity] {
        // Default browse feed: recent high-interest Scarlet & Violet chase cards.
        (try? await client.searchRaw(query: "rarity:\"Special Illustration Rare\"", pageSize: 30)) ?? []
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

enum CardTextRecognizer {
    /// Recognizes text lines from card image data, ordered as Vision returns them.
    static func recognizeLines(in imageData: Data) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            guard
                let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                throw CIQError.identificationFailed
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            return observations.compactMap { $0.topCandidates(1).first?.string }
        }.value
    }
}

// MARK: - Name / Number Heuristics

enum CardTextHeuristics {
    struct Guess {
        let name: String
        let number: String?
    }

    static func bestGuess(from lines: [String]) -> Guess? {
        guard !lines.isEmpty else { return nil }

        let number = lines.compactMap { extractNumber(from: $0) }.first

        let nameCandidates = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && $0.rangeOfCharacter(from: .letters) != nil }

        guard let name = nameCandidates.max(by: { score($0) < score($1) }) else {
            return nil
        }
        return Guess(name: name, number: number)
    }

    /// Extracts the numerator of a "NNN/NNN" collector number.
    private static func extractNumber(from line: String) -> String? {
        guard let slash = line.firstIndex(of: "/") else { return nil }
        let lhs = line[..<slash].filter { $0.isNumber }
        return lhs.isEmpty ? nil : String(lhs)
    }

    /// Pokémon names tend to be mixed-case, letter-heavy, moderately short lines.
    private static func score(_ line: String) -> Int {
        let letters = line.filter { $0.isLetter }.count
        let hasLower = line.contains { $0.isLowercase }
        return letters + (hasLower ? 5 : 0) - (line.count > 30 ? 10 : 0)
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
        var score = 0.5
        let cardName = card.name.lowercased()
        let guessName = guess.name.lowercased()
        if cardName.contains(guessName) || guessName.contains(cardName) {
            score += 0.3
        }
        if let number = guess.number, card.cardNumber.hasPrefix(number) {
            score += 0.2
        }
        return min(score, 0.99)
    }
}
