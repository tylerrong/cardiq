import Foundation

enum CardCategory: String, Codable, CaseIterable, Sendable {
    case pokemon
}

enum CardRarity: String, Codable, CaseIterable, Sendable {
    case common
    case uncommon
    case rare
    case holo
    case reverseHolo
    case ultraRare
    case secretRare
    case fullArt
    case altArt
    case specialArt
    case hyperRare
    case illustrationRare
    case specialIllustrationRare
    case trainerGallery

    var displayName: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .holo: "Holo Rare"
        case .reverseHolo: "Reverse Holo"
        case .ultraRare: "Ultra Rare"
        case .secretRare: "Secret Rare"
        case .fullArt: "Full Art"
        case .altArt: "Alt Art"
        case .specialArt: "Special Art"
        case .hyperRare: "Hyper Rare"
        case .illustrationRare: "Illustration Rare"
        case .specialIllustrationRare: "Special Illustration Rare"
        case .trainerGallery: "Trainer Gallery"
        }
    }
}

struct CardIdentity: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var category: CardCategory
    var name: String
    var setName: String
    var setCode: String
    var cardNumber: String
    var year: Int
    var variant: String?
    var rarity: CardRarity
    var language: String
    var isFirstEdition: Bool
    var isHolo: Bool
    var isReverseHolo: Bool
    var imageURL: String?
    var identificationConfidence: Double

    var displayTitle: String {
        "\(name) - \(setName)"
    }

    var displayNumber: String {
        "\(setCode) \(cardNumber)"
    }
}

enum ScanStatus: String, Codable, Sendable {
    case inProgress
    case awaitingIdentification
    case processing
    case complete
    case failed
}

struct CardScan: Identifiable, Codable, Sendable {
    let id: String
    var cardIdentity: CardIdentity?
    var frontImageLocalPath: String?
    var backImageLocalPath: String?
    var surfaceImageLocalPath: String?
    var status: ScanStatus
    var createdAt: Date
    var gradingReport: GradingReport?
    var marketSnapshot: MarketSnapshot?
    var purchasePrice: Double?
    var purchaseDate: Date?
    var quantity: Int
    var notes: String?
    var officialGrade: Double?
    var officialGradingCompany: String?
}

struct ImageQualityReport: Codable, Sendable {
    var overallScore: Double
    var isBlurry: Bool
    var hasGlare: Bool
    var isCropped: Bool
    var isSleeved: Bool
    var isSlabbed: Bool
    var lightingScore: Double
    var frontCardCoverage: Double
    var backCardCoverage: Double
    var retakeInstructions: [String]

    var passesMinimumQuality: Bool {
        overallScore >= 0.6 && !isBlurry && !isCropped
    }
}

struct GradingReport: Codable, Sendable {
    var estimatedGrade: Double
    var confidence: Double
    var psa10Probability: Double
    var psa9Probability: Double
    var psa8Probability: Double
    var psa7OrLowerProbability: Double
    var frontCenteringHorizontal: Double
    var frontCenteringVertical: Double
    var backCenteringHorizontal: Double
    var backCenteringVertical: Double
    var cornerScore: Double
    var edgeScore: Double
    var surfaceScore: Double
    var printQualityScore: Double
    var detectedDefects: [DetectedDefect]
    var explanation: String
    var createdAt: Date

    var gradeDescriptor: String {
        switch estimatedGrade {
        case 10: "Gem Mint"
        case 9.5: "Gem Mint"
        case 9..<9.5: "Mint"
        case 8..<9: "Near Mint-Mint"
        case 7..<8: "Near Mint"
        case 6..<7: "Excellent-Mint"
        case 5..<6: "Excellent"
        default: "Below Excellent"
        }
    }

    var centeringDescription: String {
        let fh = Int(frontCenteringHorizontal * 100)
        let fhComp = 100 - fh
        return "\(fh)/\(fhComp)"
    }

    var probabilityTotal: Double {
        psa10Probability + psa9Probability + psa8Probability + psa7OrLowerProbability
    }
}

struct DetectedDefect: Identifiable, Codable, Sendable {
    let id: String
    var type: DefectType
    var severity: DefectSeverity
    var confidence: Double
    var locationDescription: String
    var normalizedBoundingBox: CIQRect?
    var explanation: String
}

struct CIQRect: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

enum DefectType: String, Codable, CaseIterable, Sendable {
    case cornerWhitening
    case roundedCorner
    case edgeChipping
    case scratch
    case dent
    case crease
    case printLine
    case staining
    case discoloration
    case surfaceWear
    case offCentering
    case unknown

    var displayName: String {
        switch self {
        case .cornerWhitening: "Corner Whitening"
        case .roundedCorner: "Rounded Corner"
        case .edgeChipping: "Edge Chipping"
        case .scratch: "Scratch"
        case .dent: "Dent"
        case .crease: "Crease"
        case .printLine: "Print Line"
        case .staining: "Staining"
        case .discoloration: "Discoloration"
        case .surfaceWear: "Surface Wear"
        case .offCentering: "Off-Centering"
        case .unknown: "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .cornerWhitening, .roundedCorner: "square.dashed"
        case .edgeChipping: "rectangle.slash"
        case .scratch: "line.diagonal"
        case .dent: "circle.dashed"
        case .crease: "arrow.triangle.branch"
        case .printLine: "line.horizontal.3"
        case .staining, .discoloration: "drop.fill"
        case .surfaceWear: "square.stack.3d.up"
        case .offCentering: "arrow.up.left.and.arrow.down.right"
        case .unknown: "questionmark.circle"
        }
    }
}

enum DefectSeverity: String, Codable, Sendable {
    case minor
    case moderate
    case severe

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .minor: "warning"
        case .moderate: "warning"
        case .severe: "negative"
        }
    }
}
