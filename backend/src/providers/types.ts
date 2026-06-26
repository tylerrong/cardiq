import type { CardRef, ProviderResult } from "../types.js";

/// A price source. Each provider is independent and reports whether it's
/// configured (has a key / access) so the aggregator can skip dormant ones.
export interface PriceProvider {
  readonly name: string;
  /// True when the provider has the credentials/access it needs.
  available(): boolean;
  /// Fetch pricing for a card, or null if it has nothing / isn't available.
  fetch(card: CardRef): Promise<ProviderResult | null>;
}
