import { WORKER_VERSION } from "./server/config.js";
import {
  BASE_HEADERS,
  withRequestMeta,
  cacheOrRun,
  json,
  errorPayload,
} from "./server/http.js";
import { assertId } from "./server/utils.js";
import { getRolimonsByIds } from "./server/rolimons.js";
import { resolveUsers, getReport, getOutfitDetails } from "./server/roblox.js";

export default {
  async fetch(request, env, ctx) {
    const startedAt = Date.now();
    const requestId =
      typeof crypto?.randomUUID === "function"
        ? crypto.randomUUID()
        : `${startedAt.toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
    const finish = (response) =>
      withRequestMeta(response, requestId, startedAt);

    if (request.method === "OPTIONS") {
      return finish(new Response(null, { status: 204, headers: BASE_HEADERS }));
    }

    const url = new URL(request.url);

    try {
      if (request.method !== "GET") {
        return finish(
          json({ ok: false, error: "Only GET is supported.", requestId }, 405),
        );
      }

      if (url.pathname === "/" || url.pathname === "/api/health") {
        return finish(
          json({
            ok: true,
            name: "outfitsearch-api",
            version: WORKER_VERSION,
            requestId,
            fetchedAt: new Date().toISOString(),
            providers: {
              roblox: { enabled: true, role: "primary" },
              rolimons: {
                enabled: true,
                role: "market-enrichment",
                serverSide: true,
              },
            },
            routes: [
              "/api/resolve?q=USERNAME",
              "/api/report/USER_ID",
              "/api/outfit/OUTFIT_ID",
              "/api/rolimons/item/ASSET_ID",
            ],
          }),
        );
      }

      if (url.pathname === "/api/resolve") {
        return finish(
          await cacheOrRun(request, ctx, () =>
            resolveUsers(url.searchParams.get("q") || ""),
          ),
        );
      }

      const reportMatch = url.pathname.match(/^\/api\/report\/(\d+)$/);
      if (reportMatch) {
        return finish(
          await cacheOrRun(request, ctx, () =>
            getReport(Number(reportMatch[1])),
          ),
        );
      }

      const outfitMatch = url.pathname.match(/^\/api\/outfit\/(\d+)$/);
      if (outfitMatch) {
        return finish(
          await cacheOrRun(request, ctx, () =>
            getOutfitDetails(Number(outfitMatch[1])),
          ),
        );
      }

      const rolimonsItemMatch = url.pathname.match(
        /^\/api\/rolimons\/item\/(\d+)$/,
      );
      if (rolimonsItemMatch) {
        const id = Number(rolimonsItemMatch[1]);
        assertId(id, "Roblox asset ID");
        return finish(
          await cacheOrRun(request, ctx, async () => {
            const logs = [];
            const matched = await getRolimonsByIds([id], logs);
            return {
              ok: true,
              id,
              tracked: Boolean(matched[id]),
              item: matched[id] || null,
              logs,
              fetchedAt: new Date().toISOString(),
            };
          }),
        );
      }

      return finish(
        json(
          { ok: false, error: "Not found.", path: url.pathname, requestId },
          404,
        ),
      );
    } catch (err) {
      return finish(
        json({ ...errorPayload(err, "worker"), requestId }, err.status || 500),
      );
    }
  },
};
