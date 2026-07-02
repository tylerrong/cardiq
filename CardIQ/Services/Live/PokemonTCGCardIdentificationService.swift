import Foundation
import Vision
import ImageIO
import CoreGraphics
import CoreImage

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
        var lines: [RecognizedLine]
        do {
            lines = try await CardTextRecognizer.recognize(in: frontImage)
        } catch {
            return await allCards()
        }

        var guess = CardTextHeuristics.bestGuess(from: lines)

        // The collector number is the strongest signal but also the smallest
        // print on the card (and gold/stylized on alt arts). When the full-frame
        // pass misses it, re-OCR just the bottom strip where it lives.
        if guess?.number == nil,
           let bottomLines = try? await CardTextRecognizer.recognize(
               in: frontImage,
               regionOfInterest: CGRect(x: 0, y: 0, width: 1, height: 0.16)
           ),
           !bottomLines.isEmpty {
            lines.append(contentsOf: bottomLines)
            guess = CardTextHeuristics.bestGuess(from: lines)
        }

        // Still no number: the print is low-contrast (gold/white foil on dark
        // art, underexposed photo). Re-OCR contrast-boosted and inverted
        // variants of the bottom strip — inversion turns light-on-dark into
        // the dark-on-light text OCR reads best.
        if guess?.number == nil {
            let stripFraction: CGFloat = 0.18
            for variant in CardImagePreprocessor.bottomStripVariants(from: frontImage, stripFraction: stripFraction) {
                guard let stripLines = try? await CardTextRecognizer.recognize(in: variant),
                      !stripLines.isEmpty else { continue }
                // Strip-space -> full-image space so position heuristics hold.
                let remapped = stripLines.map {
                    RecognizedLine(text: $0.text, midY: $0.midY * stripFraction, height: $0.height * stripFraction)
                }
                let merged = lines + remapped
                let candidate = CardTextHeuristics.bestGuess(from: merged)
                if candidate?.number != nil {
                    lines = merged
                    guess = candidate
                    break
                }
            }
        }

        guard let guess else { throw CIQError.identificationFailed }

        // Japanese card: the OCR'd name is kana/kanji. Route to the local
        // Japanese catalog — the English catalog would otherwise "match" the
        // collector number against an unrelated English set. Require the kana
        // signal in the name or in 2+ lines: OCR noise on a dark English photo
        // can hallucinate a single CJK glyph.
        let japaneseLineCount = lines.count(where: { CardTextHeuristics.containsJapanese($0.text) })
        if CardTextHeuristics.containsJapanese(guess.name) || japaneseLineCount >= 2 {
            let jpMatches = await identifyJapanese(guess: guess)
            if !jpMatches.isEmpty { return jpMatches }
            // Fall through: script detection can misfire on holo glare.
        }

        // Local catalog first: matching we control (zero-padding, TG/GG/promo
        // prefixes, squashed OCR names), offline, no rate limits. The live API
        // is the fallback for anything the local catalog doesn't know.
        var matches: [CardIdentity] = []
        if let number = guess.number, let total = guess.setTotal {
            matches = await CardCatalogStore.shared.searchByNumber(number, total: total, language: "en")
        } else if let number = guess.number {
            matches = await CardCatalogStore.shared.searchByNumerator(number, language: "en")
        }
        // A number match that contradicts the OCR'd name is suspect — OCR can
        // drop a digit ("111/110" read as "11/110" matches a different, real
        // card). Merge in name-based candidates and let scoring decide: a
        // name-exact match outranks a number match with a disagreeing name.
        if !guess.name.isEmpty,
           matches.isEmpty || matches.allSatisfy({ !CardTextHeuristics.namesAgree($0.name, guess.name) }) {
            let byName = await CardCatalogStore.shared.matchByName(guess.name, language: "en")
            let known = Set(matches.map(\.id))
            matches += byName.filter { !known.contains($0.id) }
        }
        if matches.isEmpty {
            if let number = guess.number, let total = guess.setTotal {
                matches = (try? await client.searchByNumber(number: number, setTotal: total, name: guess.name)) ?? []
            } else {
                matches = (try? await client.searchCards(name: guess.name, number: guess.number)) ?? []
            }
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

// MARK: - Image preprocessing for low-contrast collector numbers

enum CardImagePreprocessor {
    /// Bottom-strip crops tuned to recover low-contrast collector numbers
    /// (gold/white foil on dark art, underexposed photos): upscaled 2x,
    /// grayscale contrast-boosted, and an inverted variant that turns
    /// light-on-dark print into the dark-on-light text OCR reads best.
    static func bottomStripVariants(from data: Data, stripFraction: CGFloat = 0.18) -> [Data] {
        guard let source = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return [] }
        let extent = source.extent
        let strip = source
            .cropped(to: CGRect(
                x: extent.minX, y: extent.minY,
                width: extent.width, height: extent.height * stripFraction
            ))
            .transformed(by: CGAffineTransform(scaleX: 2, y: 2))

        let boosted = strip.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.0,
            kCIInputContrastKey: 1.7,
            kCIInputBrightnessKey: 0.05,
        ])
        let inverted = boosted.applyingFilter("CIColorInvert")

        let context = CIContext()
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        return [boosted, inverted].compactMap { image in
            context.pngRepresentation(of: image.cropped(to: image.extent), format: .RGBA8, colorSpace: colorSpace)
        }
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
    /// `regionOfInterest` (Vision space, 0 = bottom) restricts a pass to part of the
    /// card — used to re-read the tiny collector number strip when a full pass misses it.
    static func recognize(in imageData: Data, regionOfInterest: CGRect? = nil) async throws -> [RecognizedLine] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            if let regionOfInterest {
                request.regionOfInterest = regionOfInterest
                request.minimumTextHeight = 0.01
            }
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
                // Vision reports boxes relative to the regionOfInterest — remap
                // to full-image space so position/size heuristics stay valid
                // when strip-pass lines are merged with full-pass lines.
                var midY = observation.boundingBox.midY
                var height = observation.boundingBox.height
                if let roi = regionOfInterest {
                    midY = roi.minY + midY * roi.height
                    height *= roi.height
                }
                return RecognizedLine(text: text, midY: midY, height: height)
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
        /// Copyright year printed on the card ("©2023 Pokémon") — a cheap
        /// tie-breaker when the same number/total exists in multiple sets.
        var year: Int?
    }

    private static let nonNamePrefixes = ["basic", "stage", "evolves", "ability", "hp", "weakness", "resistance", "retreat", "no."]

    static func bestGuess(from lines: [RecognizedLine]) -> Guess? {
        guard !lines.isEmpty else { return nil }

        // Collector number near the bottom — the most reliable id (the total
        // pins the set, the numerator the card). Gather every candidate and
        // prefer ones with a 2+ digit total: a 1-digit total is usually a
        // truncated read ("9/1" from "9/111").
        let candidates = lines
            .sorted { $0.midY < $1.midY }
            .flatMap { collectorNumbers(in: $0.text) }
        var collector = candidates.first { digitsOnly($0.total).count >= 2 } ?? candidates.first

        // Promo prints have no "/total" — just a prefixed number ("SWSH284").
        // Only trust the bottom half of the card: stat text at the top ("HP60")
        // matches the same letters+digits shape.
        if collector == nil {
            collector = lines
                .filter { $0.midY < 0.5 }
                .sorted { $0.midY < $1.midY }
                .compactMap { promoNumber(in: $0.text) }
                .first
                .map { (numerator: $0, total: "") }
        }

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
            setTotal: (collector?.total.isEmpty ?? true) ? nil : collector?.total,
            year: copyrightYear(in: lines)
        )
    }

    /// Standalone promo number ("SWSH284", "SVP049"): uppercase prefix glued
    /// to digits, no slash. Lowercase runs are excluded — they're usually OCR
    /// noise from flavor text.
    private static func promoNumber(in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b([A-Z]{2,5}\\d{2,3})\\b") else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else { return nil }
        let value = String(text[r])
        // Card-stat tokens that share the letters+digits shape.
        let prefix = value.prefix { $0.isLetter }
        if ["HP", "LV", "NO"].contains(String(prefix)) { return nil }
        return value
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

    /// Cleans OCR noise from a name: "Charizard@X" -> "Charizard ex", strips
    /// symbols and HP-stat contamination ("Mew 50 HP" -> "Mew").
    private static func cleanName(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "@X", with: " ex")
                   .replacingOccurrences(of: "@x", with: " ex")
        s = s.replacingOccurrences(
            of: "\\b\\d{1,3}\\s*HP\\b|\\bHP\\s*\\d{1,3}\\b",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        s = String(s.filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "'" })
        return s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    /// Every collector number in a line. Handles zero-padding ("047/198"),
    /// prefixed numerators/totals (TG12/TG30, GG44/GG70), and promo-style
    /// prints (SWSH284/307).
    private static func collectorNumbers(in text: String) -> [(numerator: String, total: String)] {
        guard let regex = try? NSRegularExpression(pattern: "\\b([A-Za-z]{0,5}\\d{1,3})\\s*/\\s*([A-Za-z]{0,5}\\d{1,3})\\b") else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let numeratorRange = Range(match.range(at: 1), in: text),
                  let totalRange = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[numeratorRange]), String(text[totalRange]))
        }
    }

    /// Latest plausible copyright year printed on the card (bottom text,
    /// "©1999-2023 Pokémon..." → 2023).
    private static func copyrightYear(in lines: [RecognizedLine]) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b") else { return nil }
        var latest: Int?
        for line in lines where line.midY < 0.25 {
            let range = NSRange(line.text.startIndex..., in: line.text)
            for match in regex.matches(in: line.text, range: range) {
                guard let r = Range(match.range, in: line.text),
                      let year = Int(line.text[r]), (1995...2035).contains(year) else { continue }
                latest = max(latest ?? 0, year)
            }
        }
        return latest
    }

    // MARK: Normalized matching (shared by ranking + catalog lookups)

    static func digitsOnly(_ s: String) -> String { s.filter(\.isNumber) }

    /// "047" -> "47", "TG12" -> "TG12", "swsh284" -> "SWSH284".
    static func normalizedNumerator(_ s: String) -> String {
        let upper = s.uppercased()
        let letters = upper.prefix { $0.isLetter }
        let digits = upper.drop { $0.isLetter }
        let trimmed = digits.drop { $0 == "0" }
        return String(letters) + (trimmed.isEmpty ? "0" : String(trimmed))
    }

    /// Whether a catalog card number ("47/198", "TG12/30") matches an OCR'd
    /// numerator/total, tolerant of zero-padding and letter-prefixed totals.
    static func numberMatches(cardNumber: String, numerator: String, total: String) -> Bool {
        let parts = cardNumber.split(separator: "/")
        guard parts.count == 2 else { return false }
        guard normalizedNumerator(String(parts[0])) == normalizedNumerator(numerator) else { return false }
        let cardTotal = digitsOnly(String(parts[1]))
        let guessTotal = digitsOnly(total)
        return !cardTotal.isEmpty && Int(cardTotal) == Int(guessTotal)
    }

    /// Name comparison tolerant of OCR dropping spaces and casing
    /// ("UmbreonVMAx" vs "Umbreon VMAX", "MeweX" vs "Mew ex").
    static func namesAgree(_ cardName: String, _ guessName: String) -> Bool {
        let card = squash(cardName)
        let guess = squash(guessName)
        guard card.count >= 3, guess.count >= 3 else { return false }
        return namesSimilar(card, guess)
    }

    /// Squashed-name comparison: substring either way, or — for longer names —
    /// a small edit distance to absorb single-glyph OCR confusions
    /// ("mewtwoystar" vs "mewtwovstar"). The budget scales with length so
    /// short names like machop/machoke can't false-positive.
    static func namesSimilar(_ a: String, _ b: String) -> Bool {
        if a.contains(b) || b.contains(a) { return true }
        guard a.count >= 8, b.count >= 8, abs(a.count - b.count) <= 2 else { return false }
        let allowed = max(1, min(a.count, b.count) / 8)
        return editDistance(a, b, limit: allowed) <= allowed
    }

    static func squash(_ s: String) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Levenshtein distance with an early-out once `limit` is exceeded.
    private static func editDistance(_ a: String, _ b: String, limit: Int) -> Int {
        let ac = Array(a.utf8), bc = Array(b.utf8)
        var prev = Array(0...bc.count)
        var curr = [Int](repeating: 0, count: bc.count + 1)
        for i in 1...ac.count {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...bc.count {
                let cost = ac[i - 1] == bc[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > limit { return limit + 1 }
            swap(&prev, &curr)
        }
        return prev[bc.count]
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
        let nameAgrees = namesAgree(card.name, guess.name)
        let nameExact = !guess.name.isEmpty && squash(card.name) == squash(guess.name)
        // Year tie-break: the printed © year separates sets that share a
        // number/total ("160/159" exists in Crown Zenith and Journey Together).
        let yearAgrees: Bool? = guess.year.flatMap { y in card.year > 0 ? y == card.year : nil }

        // Exact collector number + set total is a strong, usually-unique match —
        // but require the OCR'd name not to contradict it. This breaks ties when
        // several cards share a number and de-rates a likely OCR misread, so the
        // confirm screen flags it for the user instead of asserting 97%.
        // A prefixed promo numerator with no printed total ("SWSH284") counts too.
        let strongNumberMatch: Bool
        if let number = guess.number, let total = guess.setTotal {
            strongNumberMatch = numberMatches(cardNumber: card.cardNumber, numerator: number, total: total)
        } else if let number = guess.number, normalizedNumerator(number).contains(where: \.isLetter) {
            let cardNumerator = card.cardNumber.split(separator: "/").first.map(String.init) ?? card.cardNumber
            strongNumberMatch = normalizedNumerator(cardNumerator) == normalizedNumerator(number)
        } else {
            strongNumberMatch = false
        }
        if strongNumberMatch {
            var score: Double
            if guess.name.isEmpty {
                score = 0.9                       // no name read — trust the number
            } else if nameAgrees {
                score = 0.97                      // number + name agree — near-certain
            } else {
                score = 0.72                      // number matched but name disagrees
            }
            if let yearAgrees {
                score += yearAgrees ? 0.02 : -0.1
            }
            return min(max(score, 0.05), 0.99)
        }

        var score = 0.5
        if nameAgrees { score += 0.25 }
        // A card name that accounts for (nearly) the whole OCR read beats a
        // partial prefix match — "MewtwoYSTAR" is Mewtwo VSTAR, not Mewtwo.
        let nameStrong = nameAgrees && squash(card.name).count >= squash(guess.name).count - 2
        if nameExact { score += 0.1 } else if nameStrong { score += 0.08 }
        if let number = guess.number,
           normalizedNumerator(String(card.cardNumber.split(separator: "/").first ?? "")) == normalizedNumerator(number) {
            score += 0.1
        }
        // The printed set total pins the set even when the numerator was
        // misread — "Mew ?/110" is the Holon Phantoms Mew, not a POP Series one.
        if let total = guess.setTotal,
           let cardTotal = card.cardNumber.split(separator: "/").last.map(String.init),
           !digitsOnly(cardTotal).isEmpty,
           Int(digitsOnly(cardTotal)) == Int(digitsOnly(total)) {
            score += 0.05
        }
        if let yearAgrees {
            score += yearAgrees ? 0.05 : -0.1
        }
        return min(max(score, 0.05), 0.99)
    }
}
