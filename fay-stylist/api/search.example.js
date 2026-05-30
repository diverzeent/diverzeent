// FAY Stylist — serverless product-search proxy (Vercel/Netlify/Cloudflare style).
//
// WHY: affiliate APIs require SECRET keys and don't allow browser CORS. This
// function holds the secrets server-side, calls one or more affiliate product
// APIs, normalizes their results into the shape the front-end expects, and
// returns them. Rename to search.js and deploy; set FAY_CONFIG.PROXY_URL to it.
//
// Front-end calls: POST { slot, intent:{colors,styles,brands}, providers:[...] }
// Must return:     { items: [ {slot,name,brand,store,price,color,styles[],emoji,url}, ... ] }

export default async function handler(req, res) {
  const { slot, intent, providers = ["shopstyle"] } = req.body || {};
  const out = [];

  // ---- ShopStyle Collective (great for Gucci/Prada/LV/Nordstrom/SSENSE) ----
  if (providers.includes("shopstyle")) {
    // Docs: https://www.shopstylecollective.com  (apiKey + pid)
    const KEY = process.env.SHOPSTYLE_API_KEY;
    const q = [slot, ...(intent.colors||[]), ...(intent.brands||[])].join(" ");
    const url = `https://api.shopstyle.com/api/v2/products?pid=${KEY}`
              + `&fts=${encodeURIComponent(q)}&limit=12`
              + (priceCeil(intent) ? `&filters=Price` : "");
    const r = await fetch(url).then(r=>r.json()).catch(()=>({products:[]}));
    for (const p of (r.products||[])) {
      out.push({
        slot,
        name: p.name,
        brand: p.brand?.name || "—",
        store: p.retailer?.name || "Store",
        price: Math.round(p.price?.price ?? p.priceLabel ?? 0),
        color: (p.colors?.[0]?.name || "").toLowerCase() || "black",
        styles: (p.categories||[]).map(c=>c.name.toLowerCase()),
        emoji: emojiFor(slot),
        url: p.clickUrl,                       // already affiliate-tagged
      });
    }
  }

  // ---- Amazon Product Advertising API (Nike, basics, swim, sandals) ----
  if (providers.includes("amazon")) {
    // Use paapi5 SDK with ACCESS_KEY/SECRET_KEY/PARTNER_TAG (server-side only).
    // const data = await amazonSearchItems({ keywords: `${slot} ${intent.colors?.join(" ")}` });
    // map data.SearchResult.Items -> out.push({... url: item.DetailPageURL ...})
  }

  // ---- Rakuten / Sovrn / Skimlinks (1000s of stores, one key) ----
  if (providers.includes("rakuten")) {
    // const r = await fetch(`https://api.linksynergy.com/productsearch/1.0?keyword=...`,
    //   { headers: { Authorization: `Bearer ${process.env.RAKUTEN_TOKEN}` }});
    // map products -> out.push({...})
  }

  res.status(200).json({ items: out });
}

function priceCeil(intent){ return intent?.maxPrice || null; }
function emojiFor(slot){
  return ({top:"👚",bottoms:"👖",dress:"👗",outerwear:"🧥",shoes:"👠",
           bag:"👜",jewelry:"💍",sunglasses:"🕶️",swim:"👙"})[slot] || "🛍️";
}
