# ROUGE — AI Stylist · Red Edition (for her)

An AI outfit builder + one-cart shopping aggregator, themed around **red** and
styled for women. The customer sets a **budget**, describes a **vibe**, and the
app assembles a complete head-to-toe outfit from real store items — color/style
matched, **always within budget** — with **buy links** for every piece.

**Red Edition specifics**
- Deep red / wine / rose palette with gold accents.
- Catalog seeded with women's red-forward pieces across every slot
  (tops, skirts/pants, dresses, heels/boots, bags, jewelry, swim, outerwear).
- If the shopper names no color, the engine **defaults to red** so looks stay
  on-brand. Naming another color (e.g. "black + red") still works.
- To re-theme to another color later: change the `--pink`/`--rose`/`--wine`
  CSS vars, the example chips, and the implicit color in `parse()`.

## Run it now
Open `index.html` in any browser (double-click, or drag onto a Chrome tab).
No build step, no server needed for the demo. Try the example chips, or type
your own like *"Pink Y2K kiss-me going-out fit with heels and a mini bag."*

## What works in this template (demo mode)
- Natural-language parsing → colors, style tags, occasion, brands
- Matching engine: color harmony + style overlap + brand affinity
- Budget assembly: swaps items cheaper, then **drops optional pieces**
  (sunglasses → jewelry → bag → jacket) to stay under budget; tells the
  customer if the budget is simply too low
- Flat-lay grid (ROUGE style) + line items, prices, stores, **Buy** buttons
- Per-item **Swap**, **Open all**, **Copy all links**, **Regenerate**
- Affiliate disclosure shown

## Go live (real products + real buy links + commissions)
Direct-scraping Gucci/LV/Nike is against their terms and has no checkout. Real
aggregators use **affiliate product APIs**. To switch from demo to live:

1. Get approved for one or more:
   - **ShopStyle Collective** (Gucci/Prada/LV/Nordstrom/SSENSE/Farfetch)
   - **Amazon Product Advertising API** (Nike, basics, swim, sandals)
   - **Rakuten / Sovrn / Skimlinks** (thousands of stores, one key)
2. Deploy `api/search.example.js` as a serverless function (rename to
   `search.js`); put your secret keys in env vars there.
3. In `index.html` → `window.ROUGE_CONFIG`, set:
   ```js
   ACTIVE_PROVIDERS: ["shopstyle","amazon"],
   PROXY_URL: "https://yoursite.com/api/search",
   ```
The matching engine and UI don't change — only the data source does.

## Files
- `index.html` — the full app (UI + engine + demo catalog)
- `api/search.example.js` — serverless proxy stub for live affiliate APIs
- `PROMPT.md` — the product spec / build prompt
- `README.md` — this file

## Note on legality / ethics
Use official affiliate APIs and each retailer's product feed within their terms.
The `scrape` path should only target sites that permit it. Affiliate links must
carry a visible disclosure (already included in the UI).
