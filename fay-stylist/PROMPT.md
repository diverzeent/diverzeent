# ROUGE — AI Outfit Builder & One-Cart Shopping Aggregator

## The product, in one sentence
A web app where a customer sets a **budget**, describes the **vibe/occasion**, and the
system returns a **complete head-to-toe outfit** (top, bottoms, shoes, bag, jewelry,
sunglasses, etc.) assembled from **real, in-stock items** across multiple stores —
color- and style-matched, **always under budget** — with **direct buy links** so they
can purchase everything from one screen.

## The build/system prompt (use this to drive generation)
> Build a responsive web app called **ROUGE**.
>
> **Input:** a budget (USD), a free-text outfit description (e.g. "pink Y2K
> kiss-me going-out fit with heels and a mini bag"), and optional toggles for
> occasion, season, size, and which slots to include (top, bottoms, dress,
> shoes, bag, jewelry, sunglasses, outerwear).
>
> **Processing:**
> 1. Parse the description into structured intent: **colors**, **style tags**
>    (y2k, streetwear, glam, athleisure, business, festival, etc.), **occasion**,
>    **required slots**, and **brand affinities** (gucci, louis vuitton, prada,
>    nike, jordan, ugg, etc.).
> 2. Query one or more **product providers** (affiliate product APIs) for
>    candidate items per slot, filtered by category, price, and keywords.
> 3. **Match & assemble:** score each candidate on color harmony, style-tag
>    overlap, brand affinity, and price, then pick one item per requested slot
>    such that the **sum stays within budget** (greedy + budget backtrack).
> 4. Return the assembled outfit as a flat-lay grid plus a line-item list with
>    prices and **affiliate buy links**, and a running total vs. budget.
>
> **Output / UX:** a flat-lay "moodboard" of the chosen pieces (ROUGE style),
> a checklist with thumbnails, prices, store names, and "Buy" buttons, a total,
> a "regenerate / swap this item" control per slot, and a "Copy all links /
> Open all" action so the customer can check out everywhere fast.
>
> **Constraints:** never exceed the budget; prefer in-stock items; degrade
> gracefully if a provider is unavailable; keep affiliate disclosure visible.

## Categories to support (from the brief)
Clothing, jewelry, shoes, pants, skirts, designer (Gucci, Louis Vuitton, Prada,
Nike, Jordan), heels, boots, sneakers, UGGs, Dunks, Jordans, platforms, sandals,
swimsuits, two-piece sets, crop tops, yoga pants, workout outfits, plus the
"top trend" feed.

## How "scraping" actually works in production (important)
Directly scraping gucci.com / louisvuitton.com / nike.com violates their ToS, is
rate-limited/blocked, and provides **no purchase/checkout integration**. Real
aggregators monetize and stay legal via **affiliate product APIs**, which return
structured products *with* real buy links *and* pay you a commission:

| Provider | Coverage | Why use it |
|---|---|---|
| **Amazon Product Advertising API** | Nike, sandals, swimwear, basics, some designer | Huge catalog + 1-click checkout + commissions |
| **ShopStyle Collective API** | Gucci, Prada, LV, Nordstrom, SSENSE, Farfetch | Built for fashion; brand + price + color filters |
| **LTK / rewardStyle** | Influencer-grade fashion | Curated, on-trend |
| **Rakuten Advertising / Sovrn / Skimlinks** | 1000s of stores incl. designer | One key, many retailers; auto-affiliate links |
| **Farfetch / SSENSE affiliate feeds** | True luxury (Gucci/LV/Prada) | Real designer stock + links |

The template ships with a **provider abstraction** (`providers/`): a built-in demo
catalog works offline today; dropping in API keys (`config.js`) switches it to live
results without changing the matching engine. A `scrape` provider stub is included
**only** for retailers that publish a product feed / allow it — use responsibly and
within each site's terms.

## Matching engine (how items get paired)
- **Color harmony:** map each item's dominant color to a hue; reward
  monochrome, complementary, or shared-accent palettes; penalize clashes.
- **Style overlap:** Jaccard similarity of style tags between the request and item.
- **Brand affinity:** boost requested brands.
- **Budget fit:** assemble one item per slot maximizing total score with
  `sum(price) <= budget` (greedy by score density, then swap-down to fit).

## Roadmap to fully live
1. Get affiliate approvals (Amazon PA-API, ShopStyle/Rakuten).
2. Put keys in `config.js`; set `ACTIVE_PROVIDERS`.
3. Add a tiny serverless proxy (`/api/search`) so API secrets stay server-side
   and CORS is handled (template includes the function signature).
4. Optional: nightly job caches a "Top Trends" feed for the homepage.
