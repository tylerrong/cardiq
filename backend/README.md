# CardIQ Price Aggregator

A small backend that pulls card prices from multiple sources, normalizes them into
a single `MarketSnapshot`, caches the result, and serves it to the CardIQ iOS app.

This exists because the good price sources have **no usable client-side API** —
eBay sold data is gated, TCGplayer's API is closed, 130point has no API. They must
be pulled **server-side**, here, not from the phone.

## Run

```bash
npm install
cp .env.example .env   # fill in what you have
npm run dev            # http://localhost:8787
```

## Endpoints

- `GET /health` — status + which sources are active
- `GET /v1/price/:cardId` — normalized `MarketSnapshot` for a pokemontcg.io card id

```bash
curl localhost:8787/v1/price/sv6-216   # Bloodmoon Ursaluna ex
```

## Sources (plug in as access lands)

| Source | Gives | Status | How to activate |
|--------|-------|--------|-----------------|
| **pokemontcg / TCGplayer** | raw market + Cardmarket trend | ✅ on (no key) | `POKEMONTCG_API_KEY` optional, raises limits |
| **eBay Marketplace Insights** | real sold comps, graded medians | ⏳ dormant | Apply for [limited access](https://developer.ebay.com/api-docs/buy/static/api-insights.html), set `EBAY_OAUTH_TOKEN` |
| **PriceCharting** | graded values (from eBay sales) | ⏳ dormant | Paid token → `PRICECHARTING_TOKEN` |

Priority when merging: **eBay sold → PriceCharting → TCGplayer baseline.** Real graded
comps replace the heuristic PSA tiers; raw prefers real sold over market price.

### TODOs once credentials exist
- **eBay** (`src/providers/ebay.ts`): confirm the Marketplace Insights response fields
  and grade-from-title parsing against live data.
- **PriceCharting** (`src/providers/pricecharting.ts`): confirm the grade↔field mapping
  (`graded-price`, `manual-only-price`, …) — their naming is idiosyncratic.

## Architecture

```
GET /v1/price/:id
  → resolveCard(id)            // pokemontcg: metadata + baseline TCGplayer price
  → providers.fetch(ref)       // eBay, PriceCharting (the available ones), in parallel
  → merge()                    // priority + real-graded-over-heuristic
  → TTLCache (6h)              // swap for Postgres/Redis on Supabase
  → MarketSnapshot (JSON)
```

Adapters implement `PriceProvider` (`src/providers/types.ts`) — add a new source by
dropping in one file and registering it in `aggregator.ts`.

## iOS integration

Point the app's `MarketDataService` at `/v1/price/:cardId`; the JSON already matches
`MarketSnapshot`. (A future `HTTPMarketDataService` slots into `MarketDataFactory`.)

## Deployment

Runs on Node today. Portable to **Supabase Edge Functions** (Hono is edge-compatible)
or any host (Railway, Fly, Render) — keep all source API keys here, server-side only.
