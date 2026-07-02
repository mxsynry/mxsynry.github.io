/**
 * Shared utility functions used across mxsynry.github.io pages.
 *
 * Loaded as a plain <script> before page-specific code.
 * All helpers are exposed on the global `MxUtils` namespace and can
 * also be accessed as bare globals (escapeHtml, escapeAttr, …) for
 * convenience — pages that previously defined these locally will pick
 * up the shared versions automatically.
 */
(function (global) {
  'use strict';

  var HTML_ENTITIES = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  };

  function escapeHtml(value) {
    if (value == null) return '';
    return String(value).replace(/[&<>"']/g, function (ch) {
      return HTML_ENTITIES[ch];
    });
  }

  function escapeAttr(value) {
    return escapeHtml(value).replace(/`/g, '&#96;');
  }

  function formatSize(bytes) {
    if (bytes == null) return '';
    var units = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    while (bytes >= 1024 && i < units.length - 1) { bytes /= 1024; i++; }
    return bytes.toFixed(i === 0 ? 0 : 1) + ' ' + units[i];
  }

  function formatDate(value) {
    if (!value) return 'unknown';
    var d = new Date(value);
    if (Number.isNaN(d.getTime())) return 'unknown';
    return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
  }

  function uniqueBy(arr, fn) {
    var seen = new Set();
    return arr.filter(function (x) {
      var k = fn(x);
      if (k === undefined || k === null || seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  }

  var ns = {
    escapeHtml: escapeHtml,
    escapeAttr: escapeAttr,
    formatSize: formatSize,
    formatDate: formatDate,
    uniqueBy: uniqueBy
  };

  global.MxUtils = ns;

  // Expose each helper as a bare global so existing call-sites
  // continue to work after removing page-local definitions.
  for (var key in ns) {
    if (ns.hasOwnProperty(key) && !(key in global)) {
      global[key] = ns[key];
    }
  }
})(typeof globalThis !== 'undefined' ? globalThis : typeof window !== 'undefined' ? window : this);
