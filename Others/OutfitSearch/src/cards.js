import { $ } from "./dom.js";
import { formatInteger, escapeHtml, escapeAttr } from "./format.js";
import {
  DEMAND_LABELS,
  TREND_LABELS,
  getDisplayItem,
  formatSourceLabel,
  getCommerceDisplay,
} from "./commerce.js";

export function assetCard(item) {
  const display = getDisplayItem(item);
  const el = document.createElement("article");
  el.className = "asset";
  if (display.missingName) el.classList.add("missing-name");
  if (display.rolimons) el.classList.add("rolimons-item");

  const id = Number(display.id || item.id);
  const displayName = escapeHtml(display.name);
  const imageUrl = escapeAttr(item.imageUrl || display.imageUrl || "");
  const creator = escapeHtml(display.creatorName || "Unknown creator");
  const type = escapeHtml(display.metaType || "Asset");
  const fallbackText = escapeHtml(
    (display.metaType || "Asset").slice(0, 2).toUpperCase(),
  );
  const catalogUrl = escapeAttr(
    display.url || `https://www.roblox.com/catalog/${id}`,
  );
  const linkLabel = display.purchasableType === "Bundle" ? "Bundle" : "Catalog";
  const commerce = getCommerceDisplay(display);
  const roli = display.rolimons;
  const source = formatSourceLabel(display);
  const sourcePill = roli ? "Roli" : "Roblox";

  const roliValue =
    Number.isFinite(roli?.value) && roli.value > 0
      ? formatInteger(roli.value)
      : Number.isFinite(roli?.defaultValue) && roli.defaultValue >= 0
        ? formatInteger(roli.defaultValue)
        : "—";
  const roliRap =
    Number.isFinite(roli?.rap) && roli.rap >= 0 ? formatInteger(roli.rap) : "—";
  const marketTags = renderRolimonsTags(roli);

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${displayName}">
      ${thumbnailMarkup(imageUrl, fallbackText)}
    </div>
    <div class="asset-body">
      <div class="item-heading">
        <p class="item-name" title="${displayName}">${displayName}</p>
        <span class="source-pill${roli ? " market" : ""}">${escapeHtml(sourcePill)}</span>
      </div>
      <p class="item-meta">${type} • ID ${id}${display.bundleId ? ` • Bundle ${display.bundleId}` : ""}</p>
      <p class="item-meta">${creator}</p>

      <div class="market-grid">
        <div class="market-stat commerce-stat ${escapeAttr(commerce.tone || "")}">
          <span>Robux</span>
          <strong title="${escapeAttr(commerce.label)}">${escapeHtml(commerce.label)}</strong>
        </div>
        ${
          roli
            ? `
          <div class="market-stat market-value">
            <span>Roli value</span>
            <strong>${escapeHtml(roliValue)}</strong>
          </div>
          <div class="market-stat">
            <span>RAP</span>
            <strong>${escapeHtml(roliRap)}</strong>
          </div>
          <div class="market-stat">
            <span>Market</span>
            <strong>${escapeHtml(roli.acronym || "Tracked")}</strong>
          </div>`
            : ""
        }
      </div>

      ${marketTags ? `<div class="market-tags">${marketTags}</div>` : ""}
      ${display.componentNote && !String(display.componentNote).startsWith("Rolimons ·") ? `<p class="item-note">${escapeHtml(display.componentNote)}</p>` : ""}
      <div class="item-links">
        <a target="_blank" rel="noopener" href="${catalogUrl}">${linkLabel}</a>
        ${roli?.url ? `<a data-market-link target="_blank" rel="noopener" href="${escapeAttr(roli.url)}">Rolimons</a>` : ""}
        <button class="small-btn" type="button" data-copy="${id}">Copy ID</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("[data-copy]", el)?.addEventListener("click", () =>
    navigator.clipboard?.writeText(String(id)),
  );
  return el;
}

function renderRolimonsTags(roli) {
  if (!roli) return "";
  const tags = [];
  const add = (label, accent = false) => {
    if (!label) return;
    tags.push(
      `<span class="market-tag${accent ? " accent" : ""}">${escapeHtml(label)}</span>`,
    );
  };

  if (roli.demand !== null && DEMAND_LABELS.has(roli.demand))
    add(`Demand ${DEMAND_LABELS.get(roli.demand)}`);
  if (roli.trend !== null && TREND_LABELS.has(roli.trend))
    add(`Trend ${TREND_LABELS.get(roli.trend)}`);
  if (roli.projected) add("Projected", true);
  if (roli.hyped) add("Hyped", true);
  if (roli.rare) add("Rare", true);
  return tags.join("");
}

export function outfitCard(outfit, label = "Outfit", onOpen) {
  const el = document.createElement("article");
  el.className = "outfit";
  el.dataset.outfitId = String(outfit.id);
  const name = escapeHtml(outfit.name || `Outfit ${outfit.id}`);

  el.innerHTML = `
    <div class="thumb-wrap" aria-label="${name}">
      ${thumbnailMarkup(escapeAttr(outfit.imageUrl || ""), "OUTFIT")}
    </div>
    <div class="outfit-body">
      <p class="item-name" title="${name}">${name}</p>
      <p class="item-meta">${escapeHtml(label)} ID ${escapeHtml(outfit.id)}</p>
      <div class="item-links">
        <button class="small-btn" type="button" data-open-outfit>Open outfit</button>
      </div>
    </div>`;

  hydrateThumbs(el);
  $("[data-open-outfit]", el)?.addEventListener("click", () => onOpen(outfit));
  return el;
}

function thumbnailMarkup(imageUrl, fallbackText) {
  return `
    <div class="thumb-placeholder" aria-hidden="true"><span>${fallbackText || "ITEM"}</span></div>
    ${imageUrl ? `<img src="${imageUrl}" alt="" loading="lazy" decoding="async" data-thumb-img>` : ""}
  `;
}

function hydrateThumbs(root) {
  for (const img of root.querySelectorAll("[data-thumb-img]")) {
    const wrap = img.closest(".thumb-wrap");
    const loaded = () => wrap?.classList.add("has-image");
    const failed = () => {
      wrap?.classList.remove("has-image");
      img.remove();
    };
    img.addEventListener("load", loaded, { once: true });
    img.addEventListener("error", failed, { once: true });
    if (img.complete && img.naturalWidth > 0) loaded();
  }
}

export function createSkeletonSlot(user, index) {
  const slot = document.createElement("div");
  slot.className = "result-slot";
  slot.dataset.userId = String(user.id);
  slot.innerHTML = `
    <article class="skeleton-card" aria-label="Loading ${escapeAttr(user.name || `account ${index + 1}`)}">
      <div class="skeleton skeleton-avatar"></div>
      <div class="skeleton-lines">
        <div class="skeleton skeleton-line"></div>
        <div class="skeleton skeleton-line"></div>
        <div class="skeleton skeleton-line"></div>
      </div>
    </article>`;
  return slot;
}
