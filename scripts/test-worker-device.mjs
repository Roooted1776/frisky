#!/usr/bin/env node
/**
 * Worker device-aspect mapping lockstep (UA / CF-Device-Type / ?view=).
 *   node scripts/test-worker-device.mjs
 */
import { deviceFromUserAgent, deviceFromCfHeader, deviceFromRequest, isHtmlPath } from '../worker/device.js';

let failed = 0;
function assert(name, cond, detail) {
  if (cond) console.log(`OK   ${name}`);
  else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

assert('iphone ua → phone', deviceFromUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)') === 'phone');
assert(
  'android mobile → phone',
  deviceFromUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Mobile Safari/537.36') === 'phone',
);
assert('ipad ua → tablet', deviceFromUserAgent('Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15') === 'tablet');
assert(
  'android tablet → tablet',
  deviceFromUserAgent('Mozilla/5.0 (Linux; Android 13; SM-X700) AppleWebKit/537.36 Safari/537.36') === 'tablet',
);
assert('desktop ua → wide', deviceFromUserAgent('Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15') === 'wide');

assert('CF mobile → phone', deviceFromCfHeader('mobile') === 'phone');
assert('CF tablet → tablet', deviceFromCfHeader('tablet') === 'tablet');
assert('CF desktop → wide', deviceFromCfHeader('desktop') === 'wide');
assert('CF empty → blank', deviceFromCfHeader('') === '');

function req(url, headers = {}) {
  return new Request(url, { headers });
}
assert(
  '?view=phone wins over desktop UA',
  deviceFromRequest(req('https://example.com/tapper/?view=phone', { 'User-Agent': 'Mozilla/5.0 (Macintosh)' })) === 'phone',
);
assert(
  'CF-Device-Type beats UA',
  deviceFromRequest(
    req('https://example.com/tapper/', {
      'User-Agent': 'Mozilla/5.0 (Macintosh)',
      'CF-Device-Type': 'mobile',
    }),
  ) === 'phone',
);
assert(
  'UA fallback',
  deviceFromRequest(req('https://example.com/tapper/', { 'User-Agent': 'Mozilla/5.0 (iPhone)' })) === 'phone',
);

assert('html /tapper/', isHtmlPath('/tapper/') === true);
assert('html /tapper/index.html', isHtmlPath('/tapper/index.html') === true);
assert('not png', isHtmlPath('/tapper/BrandLogo.png') === false);
assert('not sw', isHtmlPath('/sw.js') === false);

if (failed) {
  console.error(`\ntest-worker-device: ${failed} failed`);
  process.exit(1);
}
console.log('test-worker-device OK');
