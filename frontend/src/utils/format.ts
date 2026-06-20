// Pure formatting helpers — no side effects, no API calls.

/** ISO date (yyyy-mm-dd) → Brazilian format (dd/mm/yyyy). */
export function formatDate(iso: string | null): string {
  if (!iso) return "—";
  const [y, m, d] = iso.split("-");
  return `${d}/${m}/${y}`;
}

/** "04:00:00" → "04:00". */
export function formatTime(time: string | null): string {
  if (!time) return "—";
  return time.slice(0, 5);
}

/** Numeric points → compact display ("25", "18.5"). */
export function formatPoints(points: number | string | null): string {
  if (points === null || points === undefined) return "0";
  const n = typeof points === "string" ? parseFloat(points) : points;
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}

/** Distance in km with one decimal. */
export function formatKm(km: number | string): string {
  const n = typeof km === "string" ? parseFloat(km) : km;
  return `${n.toFixed(1)} km`;
}
