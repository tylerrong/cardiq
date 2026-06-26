import type { CardRef, ComparableSale, ProviderResult } from "../types.js";
import type { PriceProvider } from "./types.js";

// eBay Marketplace Insights API — real completed/sold sales, last 90 days.
// LIMITED ACCESS: apply at
// https://developer.ebay.com/api-docs/buy/static/api-insights.html
// Once approved, set EBAY_OAUTH_TOKEN. Until then this provider is dormant.
const INSIGHTS_URL =
  "https://api.ebay.com/buy/marketplace_insights/v1_beta/item_sales/search";

interface ItemSale {
  title?: string;
  lastSoldPrice?: { value?: string; currency?: string };
  lastSoldDate?: string;
  condition?: string;
  image?: { imageUrl?: string };
}

/// Parse a grading grade out of a sold-listing title, e.g. "... PSA 10 ..." → 10.
function parseGrade(title: string): { company?: string; grade?: number } {
  const m = title.match(/\b(PSA|CGC|BGS|SGC)\s?(10|[1-9](?:\.5)?)\b/i);
  if (!m) return {};
  return { company: m[1].toUpperCase(), grade: parseFloat(m[2]) };
}

function median(values: number[]): number {
  if (values.length === 0) return 0;
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

export class EbayProvider implements PriceProvider {
  readonly name = "ebay";

  available(): boolean {
    return !!process.env.EBAY_OAUTH_TOKEN;
  }

  async fetch(card: CardRef): Promise<ProviderResult | null> {
    const token = process.env.EBAY_OAUTH_TOKEN;
    if (!token || !card.name) return null;

    const numerator = card.number?.split("/")[0] ?? "";
    const query = [card.name, numerator, card.set].filter(Boolean).join(" ");
    const url =
      `${INSIGHTS_URL}?q=${encodeURIComponent(query)}` +
      `&filter=conditions:{USED}&limit=100`;

    const res = await fetch(url, {
      headers: {
        Authorization: `Bearer ${token}`,
        "X-EBAY-C-MARKETPLACE-ID": process.env.EBAY_MARKETPLACE_ID ?? "EBAY_US",
      },
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { itemSales?: ItemSale[] };
    const sales = json.itemSales ?? [];
    if (sales.length === 0) return null;

    const recentSales: ComparableSale[] = [];
    const rawPrices: number[] = [];
    const gradedBuckets: Record<string, number[]> = {};

    for (const s of sales) {
      const price = Number(s.lastSoldPrice?.value);
      if (!Number.isFinite(price) || price <= 0) continue;
      const title = s.title ?? card.name;
      const { company, grade } = parseGrade(title);

      if (company && grade != null) {
        const key = `${company} ${grade}`;
        (gradedBuckets[key] ??= []).push(price);
      } else {
        rawPrices.push(price);
      }

      recentSales.push({
        id: `ebay-${recentSales.length}`,
        marketplace: "eBay",
        title,
        salePrice: price,
        shippingPrice: 0,
        saleDate: s.lastSoldDate ?? new Date().toISOString(),
        condition: s.condition ?? (grade != null ? "Graded" : "Raw"),
        gradingCompany: company,
        grade,
        matchQuality: "strong",
        imageURL: s.image?.imageUrl ?? card.imageURL,
      });
    }

    const graded: Record<string, number> = {};
    for (const [key, prices] of Object.entries(gradedBuckets)) {
      graded[key] = median(prices);
    }

    return {
      source: "ebay/marketplace-insights",
      raw: rawPrices.length ? median(rawPrices) : undefined,
      graded: Object.keys(graded).length ? graded : undefined,
      salesVolume30Days: sales.length,
      recentSales: recentSales.slice(0, 20),
    };
  }
}
