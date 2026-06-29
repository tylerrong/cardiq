# CardIQ Grading Models — Engineering Brief

**Audience:** ML engineer building the grading/condition models behind the scan flow.
**TL;DR:** One shared *perception backbone* that reads a card's physical condition, feeding **two distinct models** with different label spaces and different economic purposes. Do not conflate them.

---

## 0. The core mental model

A card's physical state is one thing. How you *label* that state depends on who's asking:

- **The raw market** asks: "What condition is this card in *right now*, to sell ungraded?" → Mint / NM / LP / MP / HP / DMG.
- **A third-party grader (TPG)** asks: "If submitted, what numeric grade would *we* assign?" → PSA 10, BGS 9.5 (+ subgrades), CGC 10, SGC 9.5, etc.

Same pixels, same defects — **two different labeling standards and two different economic decisions** (sell raw vs. grade-and-sell). So:

```
                 ┌─────────────────────────────┐
   scan images → │   Perception Backbone        │  → per-pillar sub-scores
 (front/back/    │  (centering, corners, edges, │     + localized defects
  surface)       │   surface, print)            │
                 └──────────────┬──────────────┘
                                │
              ┌─────────────────┴──────────────────┐
              ▼                                     ▼
   ┌──────────────────────┐            ┌──────────────────────────────┐
   │ MODEL 1              │            │ MODEL 2                       │
   │ Raw Condition         │            │ Grade Forecast (per TPG)      │
   │ → condition tier +    │            │ → P(grade | card, company c)  │
   │   continuous score    │            │   incl. Beckett subgrades     │
   │ → raw price           │            │ → grading ROI per company     │
   └──────────────────────┘            └──────────────────────────────┘
```

**Why one backbone, two heads:** the visual features (whitening, scratches, centering ratios, print lines) are shared ground truth. The two models differ only in how those features map to a *label* and a *price*. Train the backbone once; specialize the heads.

---

## 1. Inputs & preprocessing (shared)

The iOS app already provides:
- **Front image** (required), **back image** (optional), **surface close-up** (optional) — see scan modes below.
- Each capture is **perspective-corrected and cropped to the card** on-device: Vision `VNDetectRectanglesRequest` finds the card quad, `CIPerspectiveCorrection` rectifies it (`CameraCapture.swift`). So you receive a roughly fronto-parallel, card-filling image — but assume real-world glare, white-balance drift, and phone-camera noise.

Backbone preprocessing you should add:
1. **Re-detect & tighten crop**; separate **outer card edge** vs **inner art/border box** (needed for centering).
2. **Lighting/white-balance normalization**; holo/foil glare is the #1 nuisance variable — be glare-robust (this is why the optional surface close-up and, ideally, multi-angle capture exist).
3. **Canonical registration**: if the card is identified (we already do number-first ID), warp to that card's reference template so defect locations are comparable across scans of the same card.

---

## 2. Perception backbone (shared) — the four pillars + print

Graders score four pillars; mirror them as explicit, *localized* sub-models so output is explainable:

| Pillar | Method | Notes |
|---|---|---|
| **Centering** | Classical CV (measure L/R/T/B border widths of inner box vs outer edge) → ratios e.g. `55/45` | Mostly deterministic — do this first, it's high-accuracy and explainable. Front **and** back. |
| **Corners** | Crop 4 corner patches → CNN: sharp / whitening / rounding / fray | Patch-level, severity-graded |
| **Edges** | Edge strips → detect whitening / chipping / dents | |
| **Surface** | Full-surface CNN: scratches, print lines, indents, holo scratches, staining, gloss loss | Needs glare invariance |
| **Print** | Registration / color / print-centering | Often folded into surface |

**Backbone output contract** (this already exists as a struct — your model replaces the mock that fills it):

`GradingReport` (Swift): `frontCenteringHorizontal/Vertical`, `backCenteringHorizontal/Vertical`, `cornerScore`, `edgeScore`, `surfaceScore`, `printQualityScore`, `detectedDefects[]` (`type`, `severity`, `confidence`, `normalizedBoundingBox`, `explanation`), plus the downstream `estimatedGrade`, `confidence`, and `psa{10,9,8,7OrLower}Probability`. You implement the `CardGradingService.analyze(cardId:frontImage:backImage:surfaceImage:)` protocol; today it's `MockCardGradingService`.

Keep the per-pillar sub-scores and bounding boxes — they're both the explainability layer **and** the shared features both heads consume.

---

## 3. Model 1 — Raw Condition Model

**Purpose:** classify ungraded condition on the hobby's raw scale, and do it *better and finer* than the market so CardIQ becomes the reference standard for "what is NM vs LP."

**Label space:** the de-facto marketplace taxonomy (TCGplayer/eBay):
`Gem Mint / Mint → Near Mint → Lightly Played → Moderately Played → Heavily Played → Damaged`.

**Outputs:**
1. **Ordinal distribution** over the tiers (condition is *ordered* → use ordinal regression / CORN loss, **not** plain softmax).
2. **Continuous condition score** (e.g., 0–100 or 1–10) = expected value of the ordinal distribution → lets us rank two "LP" cards. *This finer-than-the-market resolution is the moat:* the market has ~6 buckets; a calibrated continuous, defect-explained score is what makes us the standard.
3. The driving **sub-scores + defects** (already from the backbone) for explainability.

**Labels/data (the hard part — ground truth):**
- **Expert consensus labeling** on raw scans (multiple graders, measure inter-rater agreement; the model should match consensus within tolerance). This clean set is the anchor.
- **Bootstrap** from marketplace listings with stated condition + image (noisy labels) for volume; **self-supervised pretraining** on unlabeled card images, then fine-tune on the clean set.
- Calibrate so the model's tier boundaries match expert consensus.

**→ Pricing connection:** map `(card identity, condition tier, continuous score)` → **raw price**. Build a `condition → price` curve per card (or per rarity bucket) from sold comps segmented by stated condition; the continuous score interpolates *within* a bucket. This is what populates the raw value shown in the scan result. **Model 1 is self-contained and shippable first.**

---

## 4. Model 2 — Grade Forecast Model (per company)

**Purpose:** for a raw card, predict the **grade distribution each TPG would assign**, including subgrades, and turn that into grading ROI.

**Output:** `P(grade = g | images, company c)` for `c ∈ {PSA, BGS, CGC, SGC}`, a *calibrated distribution* (not a point estimate). For **Beckett**, also predict the four **subgrades** (centering / corners / edges / surface) and derive the final BGS grade — model the BGS final as a learned function of subgrades (it is **not** a simple min/avg; there are half-point and Black-Label-10 rules).

**Why per-company — model their habits, don't average them:**
- Different scales: PSA 1–10 integer; BGS 1–10 with .5 + subgrades + Black Label 10; CGC 1–10 with .5, Pristine 10, Perfect 10; SGC 1–10 (+ Authentic).
- Different **tendencies**: centering tolerance differs (e.g., PSA 10 ≈ 55/45 front; BGS 9.5/10 stricter on centering subgrade); surface vs. corner weighting differs; modern vs. vintage leniency differs. These are *learnable company-specific decision boundaries* from labeled data — that's the whole point.

**Architecture:** shared backbone sub-scores + card metadata → a **per-company "grader head"** (or one company-conditioned head) that maps physical condition → that company's grade distribution. BGS head is multi-task (4 subgrades + final).

**Labels/data:** the gold mine is `(card image, company, assigned grade [+subgrades], cert#)`:
- Ingest graded-card images + official grades via **cert lookups / population reports** (TPGs expose pop reports and cert verification; many slabbed listings show the label).
- **Population reports** give per-card/company grade-distribution **priors** (how often *this* card gets a 10 at PSA) — use as priors and for calibration.

**Calibration is non-negotiable** (ROI depends on the probabilities): temperature scaling / isotonic per company; validate with reliability diagrams (ECE/Brier) and against pop-report priors.

---

## 5. Tying it together → Grading ROI (the product surface)

For a scanned raw card:
1. **Model 1** → raw condition + **raw value** `V_raw` (sell-as-is baseline).
2. **Model 2** → per-company grade distributions `P(g | c)`.
3. **Graded pricing**: for each company `c`, grade `g`, look up graded market value `V(card, c, g)` from graded sold comps (pop-weighted).
4. **Expected graded value** per company: `E_c = Σ_g P(g | c) · V(card, c, g)`.
5. **Net ROI** per company: `ROI_c = E_c − gradingCost(c) − sellingFees − V_raw` (opportunity cost of not selling raw).
6. **Surface:** best company by expected net ROI, **plus the risk** — e.g. `P(grade ≥ breakeven grade)`, not just a point estimate. Example output:
   > "PSA: 62% → PSA 10 ($X), expected net **+$Y**. BGS: 41% → 9.5 … CGC: … → **Best: PSA**, 78% chance it beats selling raw."

This distribution-based, per-company recommendation is the reputability/insight layer: *should you grade at all, where, and what's the downside.*

---

## 6. Existing app scaffolding to target

- **Scan modes** (`ScannerState.swift`): `frontOnly` = identify + raw value (runs **Model 1** only); `frontAndBack` = adds grade forecast (needs **Model 2**; surface close-up optional but improves surface scoring).
- **Service seam:** implement `CardGradingService.analyze(...)` (currently `MockCardGradingService`) → returns `GradingReport`. The struct's fields are already the output contract above.
- **Pricing:** `MarketSnapshot` has `rawEstimatedValue` + `psa8/9/10EstimatedValue`; extend to **per-company × grade** graded values to feed ROI.
- **Capture:** `CameraCapture.swift` already crops/rectifies the card; you get a clean-ish card image but must handle glare/WB.

---

## 7. Phasing

- **Phase 0 — Centering (classical CV).** Deterministic, high-accuracy, explainable. Immediate credibility.
- **Phase 1 — Model 1.** Per-pillar defect CNNs → ordinal raw-condition head → raw pricing curve. Ship raw condition + raw value; this is the "become the standard for raw" play and is self-contained.
- **Phase 2 — Model 2.** Ingest graded datasets/pop reports → per-company grader heads (BGS subgrades) → calibrated distributions → ROI.
- **Data flywheel (the long-term moat):** persist every scan's images and, crucially, **let users report the actual grade they received** → closed loop (scan → predict → user grades → record outcome → retrain). This builds a proprietary labeled dataset no competitor has.

---

## 8. What "good" means (eval)

- **Model 1:** agreement with expert consensus (Cohen's κ / MAE on continuous score), calibration of tier boundaries.
- **Model 2:** per-company top-1 grade accuracy, **distribution calibration** (ECE / Brier), subgrade accuracy (BGS), and an **ROI backtest** — did "grade at X" recommendations actually net positive vs. selling raw on held-out cards with known outcomes?

---

### One-paragraph version (drop-in prompt)

> Build two card-grading models on a shared CV backbone that reads a scanned trading card's physical condition (centering via classical CV; corners/edges/surface/print via localized CNNs producing per-pillar 0–10 sub-scores + bounding-boxed defects). **Model 1 (Raw Condition):** an *ordinal* head over hobby condition tiers (Mint→Damaged) plus a continuous score that's finer-grained than the market's buckets, calibrated to expert consensus, mapped to a raw price via condition-segmented sold comps — goal is to become the standard for raw condition. **Model 2 (Grade Forecast):** per-company heads (PSA/BGS/CGC/SGC) that learn each grader's *habits* and output a **calibrated grade distribution** (Beckett includes the 4 subgrades + learned final-grade rule). Combine `Σ P(grade|company)·gradedPrice(company,grade) − costs − rawValue` into per-company **grading ROI** and recommend whether/where to grade with the probability of beating a raw sale. Implement behind `CardGradingService.analyze(front,back,surface)`; persist scans + user-reported actual grades to close the data loop.
