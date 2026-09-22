/**
 * redmed-emergency — static passerby assets + edge device aspect hint.
 * Injects data-device-edge from UA / CF-Device-Type. Auto layout is CSS
 * @media — only ?view=phone|tablet|wide locks html[data-device] before paint.
 * Forcing UA data-device on Auto painted desktop-wide before static CSS.
 */
import { deviceFromRequest, isHtmlPath, viewLockFromRequest } from './device.js';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const assetResponse = await env.ASSETS.fetch(request);

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return assetResponse;
    }
    if (!isHtmlPath(url.pathname)) {
      return assetResponse;
    }
    const ct = (assetResponse.headers.get('content-type') || '').toLowerCase();
    if (ct && !ct.includes('text/html')) {
      return assetResponse;
    }

    const device = deviceFromRequest(request);
    const lock = viewLockFromRequest(request);
    const headers = new Headers(assetResponse.headers);
    headers.set('Vary', mergeVary(headers.get('Vary'), 'User-Agent, CF-Device-Type'));

    return new HTMLRewriter()
      .on('html', {
        element(el) {
          // Do not override an explicit client lock already in the file.
          const existing = el.getAttribute('data-view-lock');
          if (existing === 'phone' || existing === 'tablet' || existing === 'wide') {
            el.setAttribute('data-device-edge', device);
            return;
          }
          el.setAttribute('data-device-edge', device);
          if (lock) {
            el.setAttribute('data-device', lock);
            el.setAttribute('data-view-lock', lock);
          } else {
            // Auto: leave data-device unset so :root @media is live on first paint.
            el.removeAttribute('data-device');
            el.removeAttribute('data-view-lock');
          }
        },
      })
      .transform(
        new Response(assetResponse.body, {
          status: assetResponse.status,
          statusText: assetResponse.statusText,
          headers,
        }),
      );
  },
};

function mergeVary(existing, extra) {
  const parts = String(existing || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  String(extra || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .forEach((p) => {
      if (!parts.some((x) => x.toLowerCase() === p.toLowerCase())) parts.push(p);
    });
  return parts.join(', ');
}
