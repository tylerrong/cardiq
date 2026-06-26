import type { ComparableSale, MarketSnapshot, ProviderResult } from "./types.js";
import { TTLCache } from "./cache.js";
import { resolveCard } from "./providers/pokemontcg.js";
import { EbayProvider } from "./providers/ebay.js";
import { PriceChartingProvider } from "./providers/pricecharting.js";
import type { PriceProvider } from "./providers/types.js";

// Priority order: eBay sold first (true sales), then PriceCharting (graded),
// with pokemontcg/TCGplayer as the always-on baseline (resolved separately).
const PROVIDERS: PriceProvider[] = [new EbayProvider(), new PriceChartingProvider()];

// Heuristic graded multipliers — used only when no real graded comp exists.
const PSA8_MULT = 1.1;
const PSA9_MULT = 1.8;
const PSA10_MULT = 4.0;

const cache = new TTLCache<MarketSnapshot>(6 * 60 * 60 * 1000); // 6h

export function activeSources(): string[] {
  return ["pokemontcg/tcgplayer", ...PROVIDERS.filter((p) => p.available()).map((p) => p.name)];
}

export async function getSnapshot(cardId: string): Promise<MarketSnapshot | null> {
  const cached = cache.get(cardId);
  if (cached) return cached;

  const base = await resolveCard(cardId);
  if (!base) return null;

  const results: ProviderResult[] = [];
  if (base.result) results.push(base.result);

  await Promise.all(
    PROVIDERS.filter((p) => p.available()).map(async (p) => {
      try {
        const r = await p.fetch(base.ref);
        if (r) results.push(r);
      } catch {
        /* a failed source must not sink the snapshot */
      }
    })
  );

  const snapshot = merge(cardId, results);
  cache.set(cardId, snapshot);
  return snapshot;
}

function merge(cardId: string, results: ProviderResult[]): MarketSnapshot {
  // eBay first for raw + sales (real sold); pokemontcg/pricecharting fill gaps.
  const byPriority = [...results].sort((a, b) => rank(a.source) - rank(b.source));

  const raw = firstDefined(byPriority.map((r) => r.raw)) ?? 0;
  const graded = mergeGraded(byPriority);
  const thirtyDay = firstDefined(byPriority.map((r) => r.thirtyDayChange)) ?? 0;
  const volume = firstDefined(byPriority.map((r) => r.salesVolume30Days)) ?? 0;

  const recentSales: ComparableSale[] = byPriority.flatMap((r) => r.recentSales ?? []).slice(0, 25);

  return {
    cardId,
    rawEstimatedValue: round(raw),
    psa8EstimatedValue: round(graded["PSA 8"] ?? raw * PSA8_MULT),
    psa9EstimatedValue: round(graded["PSA 9"] ?? raw * PSA9_MULT),
    psa10EstimatedValue: round(graded["PSA 10"] ?? raw * PSA10_MULT),
    thirtyDayChangePercentage: round(thirtyDay),
    ninetyDayChangePercentage: 0,
    oneYearChangePercentage: 0,
    salesVolume30Days: volume,
    liquidityScore: volume > 0 ? Math.min(1, volume / 50) : raw > 0 ? 0.5 : 0.2,
    recentSales,
    updatedAt: new Date().toISOString(),
    sources: results.map((r) => r.source),
  };
}

function mergeGraded(results: ProviderResult[]): Record<string, number> {
  const out: Record<string, number> = {};
  for (const r of results) {
    for (const [grade, value] of Object.entries(r.graded ?? {})) {
      if (out[grade] == null) out[grade] = value; // first (highest priority) wins
    }
  }
  return out;
}

function rank(source: string): number {
  if (source.startsWith("ebay")) return 0;
  if (source.startsWith("pricecharting")) return 1;
  return 2; // pokemontcg/tcgplayer baseline
}

function firstDefined<T>(values: (T | undefined)[]): T | undefined {
  return values.find((v) => v != null);
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}
