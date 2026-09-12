export const FEATURE_OPTIONS = ["Decompiler", "Multi-instance", "RakNet", "Server-side", "Kernel", "Key system", "Keyless", "Client-mod bypass", "Beta", "Longest-running"];

const aliases: Record<string, string> = {
  keysystem: "Key system", keyed: "Key system", keyless: "Keyless",
  multiinstance: "Multi-instance", multiinject: "Multi-instance", multipleinstance: "Multi-instance",
  raknet: "RakNet", decompiler: "Decompiler", verified: "Verified", certified: "Verified",
  beta: "Beta", warning: "Warning flagged", warningred: "Warning flagged", insecure: "Warning flagged",
  clientmods: "Client-mod bypass", clientmod: "Client-mod bypass", clientmodbypass: "Client-mod bypass",
  serverside: "Server-side", freemium: "Freemium", lifetime: "Lifetime", subscription: "Subscription",
  kernel: "Kernel", inviteonly: "Invite-only", trending: "Trending", longestrunning: "Longest-running"
};

export function normalizeFeatures(values: string[]): string[] {
  const labels = new Map<string, string>();
  for (const raw of values) {
    const key = raw.toLowerCase().replace(/[^a-z0-9]/g, "");
    if (key) labels.set(key, aliases[key] || raw.trim());
  }
  return [...new Set(labels.values())].sort();
}
