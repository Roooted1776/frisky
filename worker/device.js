/**
 * Map request → phone | tablet | wide for passerby tapper layout.
 * Prefer CF-Device-Type when present; else User-Agent (APO-style).
 * Viewport JS on the client still refines after paint using aspect ratio.
 */
export function deviceFromUserAgent(ua) {
  const s = String(ua || '');
  // Mobile phones (not tablets). Same idea as Cloudflare APO cache-by-device.
  if (
    /(?:phone|windows\s+phone|ipod|blackberry|(?:android|bb\d+|meego|silk|googlebot) .+? mobile|palm|windows\s+ce|opera mini|avantgo|mobilesafari|docomo|kaios)/i.test(
      s,
    )
  ) {
    return 'phone';
  }
  if (/(?:ipad|playbook|(?:android|bb\d+|meego|silk)(?! .+? mobile)|tablet)/i.test(s)) {
    return 'tablet';
  }
  return 'wide';
}

export function deviceFromCfHeader(cfDeviceType) {
  const t = String(cfDeviceType || '').toLowerCase();
  if (t === 'mobile') return 'phone';
  if (t === 'tablet') return 'tablet';
  if (t === 'desktop') return 'wide';
  return '';
}

export function deviceFromRequest(request) {
  try {
    const url = new URL(request.url);
    const q = (url.searchParams.get('view') || '').toLowerCase();
    if (q === 'phone' || q === 'tablet' || q === 'wide') return q;
  } catch (_) {
    /* ignore */
  }
  const fromCf = deviceFromCfHeader(request.headers.get('CF-Device-Type'));
  if (fromCf) return fromCf;
  return deviceFromUserAgent(request.headers.get('User-Agent'));
}

export function isHtmlPath(pathname) {
  const p = String(pathname || '');
  if (p === '/' || p === '') return true;
  if (/\.html?$/i.test(p)) return true;
  // Directory indexes staged for the Worker (tapper/, get/, …).
  if (/\/$/.test(p)) return true;
  if (
    /^\/(tapper|get|support|privacy|Document)$/i.test(p) ||
    /^\/(tapper|get|support|privacy|Document)\//i.test(p)
  ) {
    return !/\.[a-z0-9]+$/i.test(p.split('/').pop() || '');
  }
  return false;
}
