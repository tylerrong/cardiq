# CardIQ

AI-assisted card pre-grading, identification, valuation, and collection management for modern English Pokémon cards.

## Requirements

- Xcode 26+ (Swift 6)
- iOS 18+ / macOS 15+
- No third-party dependencies
- No API credentials required (mock services included)

## Quick Start

1. Open `CardIQ.xcodeproj` in Xcode
2. Select an iOS Simulator target (iPhone 17 Pro recommended)
3. Build and run (⌘R)

The app launches with mock data — all services use deterministic mock implementations that work without network access.

## Architecture

```
CardIQ/
├── App/              # App entry point, root navigation
├── Core/             # AppState, ServiceContainer, errors
├── DesignSystem/     # Colors, typography, spacing tokens, reusable components
├── Models/           # Domain models (CardIdentity, GradingReport, etc.)
├── Services/
│   ├── Protocols/    # Service interfaces
│   └── Mock/         # Mock implementations with seed data
├── Networking/       # API contracts and mock client
├── Persistence/      # SwiftData models
├── Features/
│   ├── Onboarding/   # 7-step onboarding flow
│   ├── Home/         # Dashboard with portfolio summary
│   ├── Scanner/      # Multi-step card scanning state machine
│   ├── Identification/ # Card confirmation with alternatives
│   ├── Grading/      # Grade report with defect overlays
│   ├── GradeROI/     # ROI calculator with outcome table
│   ├── Market/       # Market data with charts and comps
│   ├── Collection/   # Grid/list collection with SwiftData
│   ├── Profile/      # Settings and preferences
│   └── Paywall/      # StoreKit 2-ready subscription UI
└── Resources/        # Assets, seed data
```

### Pattern: MVVM + Services

- **Views**: SwiftUI views, small and focused
- **ViewModels**: `@Observable` classes with business logic
- **Services**: Protocol-based, injected via `ServiceContainer`
- **Persistence**: SwiftData `@Model` for collection items

### Concurrency

Uses Swift 6 strict concurrency with `@MainActor` default isolation (set in build settings). All UI state is MainActor-isolated.

## Key Flows

### Scanner → Grade Report → ROI

1. User taps "Scan a Card"
2. Instructions screen
3. Front image capture (camera or photo picker)
4. Image quality review with pass/fail
5. Back image capture
6. Optional surface close-up
7. Processing animation (8 steps)
8. Card identification confirmation
9. **Grade Report**: estimated grade, probability bars, category scores, centering measurements, detected defects
10. **Grade ROI**: editable inputs, outcome table (Raw/PSA 8/9/10), expected value, recommendation

## Testing

```bash
# Unit tests (21 tests)
xcodebuild test -scheme CardIQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CardIQTests

# UI tests
xcodebuild test -scheme CardIQ -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CardIQUITests
```

### Unit Test Coverage

- Grade probability totals ≈ 100%
- Expected value calculation accuracy
- Selling fee calculation
- Maximum buy price bounds
- Free scan allowance and limits
- Image quality gating (pass/fail)
- Collection gain/loss math
- Deterministic mock results
- Card identification confidence
- Market data value ordering

## Mocked Components

These must be replaced with real implementations before production:

| Component | Mock | Production Replacement |
|-----------|------|----------------------|
| Authentication | `MockAuthenticationService` | Sign in with Apple via AuthenticationServices |
| Card Identification | `MockCardIdentificationService` | Vision ML model or backend API |
| Card Grading | `MockCardGradingService` | Backend ML pipeline |
| Market Data | `MockMarketDataService` | Backend aggregating eBay/TCGPlayer APIs |
| Image Quality | `MockImageQualityService` | Vision framework analysis |
| Subscription | `MockSubscriptionService` | StoreKit 2 integration |
| Image Storage | `MockImageStorageService` | Local filesystem + CloudKit |
| Analytics | `MockAnalyticsService` | Firebase/Amplitude/custom |
| API Client | `MockAPIClient` | URLSession-based client |
| Camera | Photo picker fallback | AVFoundation capture session |

## Seed Data

- 12 mock Pokémon cards across 8 sets
- 8 collection records with varying grades
- 10+ comparable sales per card
- Price history with multiple time ranges
- Multiple grade outcomes (PSA 10 candidate → sell raw)
- Good and poor image quality examples

## Production Readiness Checklist

- [ ] Replace all mock services with real implementations
- [ ] Implement AVFoundation camera capture
- [ ] Integrate Sign in with Apple
- [ ] Set up StoreKit 2 with App Store Connect
- [ ] Build backend API (see API contracts in `Networking/APIContracts.swift`)
- [ ] Train/integrate card identification ML model
- [ ] Train/integrate grading analysis ML model
- [ ] Integrate market data feeds (eBay, TCGPlayer)
- [ ] Add real analytics provider
- [ ] App Store review compliance (disclaimers, privacy)
- [ ] Add NSCameraUsageDescription to Info.plist
- [ ] Add NSPhotoLibraryUsageDescription to Info.plist
- [ ] Security audit (no API keys in source)
- [ ] Accessibility audit (VoiceOver, Dynamic Type)
- [ ] Performance testing on older devices
- [ ] App icon and launch screen
- [ ] Privacy policy and terms of service
