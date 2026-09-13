export function summarizeReviews(reviews: { rating: number | null }[]) {
  const ratings = reviews.map(r => r.rating).filter((r): r is number => typeof r === "number" && Number.isFinite(r) && r >= 0 && r <= 5);
  return { count: reviews.length, rated: ratings.length, average: ratings.length ? ratings.reduce((a, b) => a + b, 0) / ratings.length : null };
}
