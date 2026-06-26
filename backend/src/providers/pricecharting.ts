import type { CardRef, ProviderResult } from "../types.js";
import type { PriceProvider } from "./types.js";

// PriceCharting API — graded card values sourced from eBay sales.
// Paid token: https://www.pricecharting.com/api-documentation
// Prices are returned in pennies. Until PRICECHARTING_TOKEN is set, dormant.
const PRODUCT_URL = "https://www.pricecharting.com/api/product";

// PriceCharting's card price fields → grade labels. NOTE: confirm this mapping
// against a live token; PriceCharting's grade↔field naming is idiosyncratic.
interface PriceChartingProduct {
  "loose-price"?: number; // ungraded
  "graded-price"?: number; // ~PSA 9
  "box-only-price"?: number; // ~PSA 9.5 / CGC 9.5
  "manual-only-price"?: number; // ~PSA 10
  "bgs-10-price"?: number; // BGS 10
}

function pennies(value?: number): number | undefined {
  return typeof value === "number" && value > 0 ? value / 100 : undefined;
}

export class PriceChartingProvider implements PriceProvider {
  readonly name = "pricecharting";

  available(): boolean {
    return !!process.env.PRICECHARTING_TOKEN;
  }

  async fetch(card: CardRef): Promise<ProviderResult | null> {
    const token = process.env.PRICECHARTING_TOKEN;
    if (!token || !card.name) return null;

    const numerator = card.number?.split("/")[0] ?? "";
    const query = [card.name, numerator, card.set].filter(Boolean).join(" ");
    const url = `${PRODUCT_URL}?t=${encodeURIComponent(token)}&q=${encodeURIComponent(query)}`;

    const res = await fetch(url);
    if (!res.ok) return null;
    const p = (await res.json()) as PriceChartingProduct;

    const graded: Record<string, number> = {};
    const psa9 = pennies(p["graded-price"]);
    const psa10 = pennies(p["manual-only-price"]);
    const bgs95 = pennies(p["box-only-price"]);
    if (psa9 != null) graded["PSA 9"] = psa9;
    if (psa10 != null) graded["PSA 10"] = psa10;
    if (bgs95 != null) graded["PSA 9.5"] = bgs95;

    const raw = pennies(p["loose-price"]);
    if (raw == null && Object.keys(graded).length === 0) return null;

    return {
      source: "pricecharting",
      raw,
      graded: Object.keys(graded).length ? graded : undefined,
    };
  }
}
