import type { CardRef, ComparableSale, ProviderResult } from "../types.js";

const BASE = "https://api.pokemontcg.io/v2";

interface PriceTier {
  low?: number;
  mid?: number;
  high?: number;
  market?: number;
}

interface PokemonCard {
  id: string;
  name: string;
  number?: string;
  images?: { small?: string; large?: string };
  set?: { id?: string; name?: string; printedTotal?: number };
  tcgplayer?: { updatedAt?: string; prices?: Record<string, PriceTier> };
  cardmarket?: {
    updatedAt?: string;
    prices?: { avg1?: number; avg7?: number; avg30?: number; trendPrice?: number };
  };
}

async function fetchCard(id: string): Promise<PokemonCard | null> {
  const headers: Record<string, string> = {};
  const key = process.env.POKEMONTCG_API_KEY;
  if (key) headers["X-Api-Key"] = key;
  const res = await fetch(`${BASE}/cards/${encodeURIComponent(id)}`, { headers });
  if (!res.ok) return null;
  const json = (await res.json()) as { data?: PokemonCard };
  return json.data ?? null;
}

/// Resolve card metadata (for other providers' text queries) + a baseline
/// raw price from TCGplayer/Cardmarket. Always available, no key required.
export async function resolveCard(
  id: string
): Promise<{ ref: CardRef; result: ProviderResult | null } | null> {
  const card = await fetchCard(id);
  if (!card) return null;

  const ref: CardRef = {
    id: card.id,
    name: card.name,
    set: card.set?.name,
    number: card.number,
    imageURL: card.images?.large ?? card.images?.small,
  };

  const tiers = card.tcgplayer?.prices ?? {};
  const tier = tiers.holofoil ?? tiers.reverseHolofoil ?? tiers.normal ?? Object.values(tiers)[0];
  const raw = tier?.market ?? tier?.mid ?? tier?.low ?? 0;

  const cm = card.cardmarket?.prices;
  const thirtyDayChange =
    cm?.avg1 && cm?.avg30 && cm.avg30 > 0 ? ((cm.avg1 - cm.avg30) / cm.avg30) * 100 : 0;

  const updatedAt = card.tcgplayer?.updatedAt ?? new Date().toISOString();
  const recentSales: ComparableSale[] = tier
    ? ([
        ["market", tier.market],
        ["low", tier.low],
        ["high", tier.high],
      ] as const)
        .filter(([, p]) => typeof p === "number" && p > 0)
        .map(([label, p], i) => ({
          id: `${card.id}-tcg-${i}`,
          marketplace: "TCGplayer",
          title: `${card.name} — TCGplayer ${label} (raw)`,
          salePrice: p as number,
          shippingPrice: 0,
          saleDate: updatedAt,
          condition: "Near Mint (raw)",
          matchQuality: i === 0 ? "exact" : "strong",
          imageURL: ref.imageURL,
        }))
    : [];

  const result: ProviderResult | null =
    raw > 0
      ? { source: "pokemontcg/tcgplayer", raw, thirtyDayChange, recentSales }
      : null;

  return { ref, result };
}
