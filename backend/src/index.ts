import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { activeSources, getSnapshot } from "./aggregator.js";

const app = new Hono();

app.get("/", (c) =>
  c.json({ service: "cardiq-price-aggregator", endpoints: ["/health", "/v1/price/:cardId"] })
);

app.get("/health", (c) => c.json({ status: "ok", sources: activeSources() }));

// Normalized price for a card (by pokemontcg id). Returns a MarketSnapshot the
// iOS app can decode directly.
app.get("/v1/price/:cardId", async (c) => {
  const cardId = c.req.param("cardId");
  try {
    const snapshot = await getSnapshot(cardId);
    if (!snapshot) return c.json({ error: "card not found" }, 404);
    return c.json(snapshot);
  } catch (err) {
    console.error("price error", err);
    return c.json({ error: "aggregation failed" }, 502);
  }
});

const port = Number(process.env.PORT ?? 8787);
serve({ fetch: app.fetch, port });
console.log(`CardIQ price aggregator → http://localhost:${port}  (sources: ${activeSources().join(", ")})`);
