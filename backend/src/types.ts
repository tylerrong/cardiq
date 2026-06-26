// Normalized output — mirrors the iOS app's MarketSnapshot so the client can
// decode it directly once its MarketDataService points at this backend.

export type MatchQuality = "exact" | "strong" | "partial" | "weak";

export interface ComparableSale {
  id: string;
  marketplace: string; // "eBay", "TCGplayer", "PriceCharting", "130point"
  title: string;
  salePrice: number;
  shippingPrice: number;
  saleDate: string; // ISO 8601
  condition: string;
  gradingCompany?: string;
  grade?: number;
  matchQuality: MatchQuality;
  imageURL?: string;
}

export interface MarketSnapshot {
  cardId: string;
  rawEstimatedValue: number;
  psa8EstimatedValue: number;
  psa9EstimatedValue: number;
  psa10EstimatedValue: number;
  thirtyDayChangePercentage: number;
  ninetyDayChangePercentage: number;
  oneYearChangePercentage: number;
  salesVolume30Days: number;
  liquidityScore: number;
  recentSales: ComparableSale[];
  updatedAt: string; // ISO 8601
  sources: string[]; // which providers contributed
}

// A card reference. The pokemontcg id is the primary key; name/set/number let
// the eBay / PriceCharting providers build their text queries.
export interface CardRef {
  id: string;
  name?: string;
  set?: string;
  number?: string;
  imageURL?: string;
}

// What a single source returns before aggregation.
export interface ProviderResult {
  source: string;
  raw?: number; // raw/ungraded market value (USD)
  graded?: Record<string, number>; // e.g. { "PSA 10": 520, "PSA 9": 180 }
  thirtyDayChange?: number;
  salesVolume30Days?: number;
  recentSales?: ComparableSale[];
}
