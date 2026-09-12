export function priceInfo(text: string | null) {
  const raw = text || "";
  const amount = Number(raw.match(/\d+(?:\.\d+)?/)?.[0] ?? NaN);
  const free = /\bfree\b/i.test(raw);
  if (!Number.isFinite(amount)) return { cost: free ? 0 : Infinity, rating: free ? "good" : "unknown" };
  if (/\b(?:EUR|GBP|VND|CAD|AUD)\b|[€£₫]/i.test(raw)) return { cost: Infinity, rating: "unknown" };
  const lifetime = /lifetime/i.test(raw), weekly = /week/i.test(raw), daily = /daily|day\b/i.test(raw), monthly = /month/i.test(raw);
  const cost = lifetime ? amount / 12 : weekly ? amount * 30 / 7 : daily ? amount * 30 : amount;
  const good = lifetime ? 30 : 10;
  const fair = lifetime ? 60 : weekly || daily ? 18 : monthly ? 20 : 30;
  const score = lifetime ? amount : cost;
  let rating = score <= good ? "good" : score <= fair ? "fair" : "expensive";
  if (free && rating === "expensive") rating = "fair";
  return { cost: free ? 0 : cost, rating };
}
