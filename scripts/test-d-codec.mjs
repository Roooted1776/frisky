#!/usr/bin/env node
/**
 * `#d=` codec lockstep: tapper.html decode vs Swift ProfileNFCCodec wire format.
 * Runs on Linux (no Xcode). Fail closed on constant drift or a broken round-trip.
 *
 *   node scripts/test-d-codec.mjs
 */
import { createHash, createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import { inflateSync, deflateSync } from 'node:zlib';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const KEY_LABEL = 'RedMed-NFC-AES-GCM-v1';
const AES_VERSION = 0x02;
const ZLIB_VERSION = 0x01;
const MAX_PAYLOAD = 8192;
const MAX_STR = 200;
const MAX_LIST = 40;
const WRITE_BASE = 'https://redmed-emergency.maxaguilaraasted.workers.dev/tapper/';
const KEY = createHash('sha256').update(KEY_LABEL).digest();

let failed = 0;
function ok(name) {
  console.log(`OK   ${name}`);
}
function fail(name, detail) {
  failed += 1;
  console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
}
function assert(name, cond, detail) {
  if (cond) ok(name);
  else fail(name, detail);
}

function b64url(buf) {
  return Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
function b64urlDecode(raw) {
  let b64 = raw.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4) b64 += '=';
  return Buffer.from(b64, 'base64');
}

function clipStr(s) {
  return String(s ?? '').slice(0, MAX_STR);
}
function flattenListItems(items) {
  const out = [];
  for (const raw of items || []) {
    for (const part of String(raw).split(',')) {
      const t = clipStr(part.trim());
      if (t) out.push(t);
      if (out.length >= MAX_LIST) return out;
    }
  }
  return out;
}

function joinList(items) {
  return flattenListItems(items).join(', ');
}

/** Swift `compactArray` — current AES writes. */
function compactArray(chip) {
  const phoneRaw = (chip.contacts && chip.contacts[0] && chip.contacts[0].phone) || '';
  const digits = clipStr(String(phoneRaw).replace(/[^\d+]/g, '').slice(0, 20));
  const contacts = (chip.contacts || []).slice(0, MAX_LIST).map((c) => [
    clipStr(c.name || ''),
    clipStr(c.rel || ''),
    clipStr(c.phone || ''),
  ]);
  const row = [
    clipStr(chip.blood || ''),
    joinList(chip.allergies),
    joinList(chip.meds),
    digits,
    clipStr(chip.name || ''),
    clipStr(chip.dob || ''),
    joinList(chip.conditions),
    contacts,
    chip.donor ? 1 : 0,
  ];
  if (chip.updated) row.push(clipStr(chip.updated));
  const notes = clipStr(String(chip.notes || '').trim());
  if (chip.pregnant || chip.deafOrVisionImpaired || notes) {
    if (!chip.updated) row.push('');
    row.push(chip.pregnant ? 1 : 0);
    row.push(chip.deafOrVisionImpaired ? 1 : 0);
    if (notes) row.push(notes);
  }
  return row;
}

function aesSeal(plainBuf) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', KEY, iv);
  const enc = Buffer.concat([cipher.update(plainBuf), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([Buffer.from([AES_VERSION]), iv, enc, tag]);
}

function aesOpen(bytes) {
  if (!bytes.length || bytes[0] !== AES_VERSION) return null;
  if (bytes.length < 1 + 12 + 16) return null;
  const iv = bytes.subarray(1, 13);
  const tag = bytes.subarray(bytes.length - 16);
  const ciphertext = bytes.subarray(13, bytes.length - 16);
  try {
    const decipher = createDecipheriv('aes-256-gcm', KEY, iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
  } catch {
    return null;
  }
}

function isDonorFlag(v) {
  return v === true || v === false || v === 0 || v === 1 || v === '0' || v === '1';
}
function looksLikeDob(v) {
  if (typeof v === 'number') return true;
  if (typeof v !== 'string') return false;
  const digits = v.replace(/\D/g, '');
  return digits.length === 6 || digits.length === 8 || v.includes('-');
}
function isLegacyCompactArray(arr) {
  if (!Array.isArray(arr) || arr.length < 4) return false;
  if (arr.length >= 9 && isDonorFlag(arr[8])) return false;
  const donorLike = isDonorFlag(arr[3]);
  if (donorLike && Array.isArray(arr[4])) return true;
  if (donorLike && typeof arr[2] === 'number' && arr[2] >= 0 && arr[2] <= 7) return true;
  if (
    donorLike &&
    typeof arr[0] === 'string' &&
    ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].indexOf(arr[0]) < 0 &&
    looksLikeDob(arr[1]) &&
    arr.length <= 9
  ) {
    return true;
  }
  return false;
}

function splitList(v) {
  if (Array.isArray(v)) {
    return flattenListItems(v.filter((x) => typeof x === 'string'));
  }
  if (typeof v !== 'string' || !v) return [];
  return flattenListItems([v]);
}

function profileFromCurrentArray(arr) {
  const str = (i) => {
    if (i >= arr.length || arr[i] == null) return '';
    if (typeof arr[i] === 'string') return arr[i];
    if (typeof arr[i] === 'number' || typeof arr[i] === 'boolean') return String(arr[i]);
    return '';
  };
  return {
    blood: str(0),
    allergies: splitList(arr[1]),
    meds: splitList(arr[2]),
    name: clipStr(str(4)),
    dob: clipStr(str(5)),
    conditions: splitList(arr[6]),
    contacts: Array.isArray(arr[7])
      ? arr[7].slice(0, MAX_LIST).map((row) => ({
          name: clipStr(row[0]),
          rel: clipStr(row[1]),
          phone: String(row[2] || '').replace(/[^\d+]/g, '').slice(0, 20),
        }))
      : [],
    donor: !!(arr[8] === true || arr[8] === 1 || arr[8] === '1'),
    updated: clipStr(str(9)),
    pregnant: !!(arr[10] === true || arr[10] === 1 || arr[10] === '1'),
    deafOrVisionImpaired: !!(arr[11] === true || arr[11] === 1 || arr[11] === '1'),
    notes: clipStr(str(12)),
  };
}

function profileFromLegacyArray(arr) {
  return {
    name: clipStr(arr[0]),
    dob: arr[1],
    blood: arr[2],
    donor: !!(arr[3] === true || arr[3] === 1 || arr[3] === '1'),
    allergies: splitList(arr[4]),
    meds: splitList(arr[5]),
    conditions: splitList(arr[6]),
    contacts: Array.isArray(arr[7]) ? arr[7] : [],
    updated: arr[8] || '',
  };
}

function decodeJSON(bytes) {
  if (!bytes || !bytes.length) return null;
  const c = bytes[0];
  if (c !== 0x7b && c !== 0x5b) return null;
  return JSON.parse(bytes.toString('utf8'));
}

function decodePayload(encoded) {
  const data = b64urlDecode(encoded);
  if (!data.length || data.length > MAX_PAYLOAD) return null;
  if (data[0] === AES_VERSION) {
    const plain = aesOpen(data);
    if (!plain) return null;
    const json = decodeJSON(plain);
    if (json == null) return null;
    return Array.isArray(json)
      ? isLegacyCompactArray(json)
        ? profileFromLegacyArray(json)
        : profileFromCurrentArray(json)
      : json;
  }
  const direct = decodeJSON(data);
  if (direct != null) {
    return Array.isArray(direct)
      ? isLegacyCompactArray(direct)
        ? profileFromLegacyArray(direct)
        : profileFromCurrentArray(direct)
      : direct;
  }
  try {
    const body = data[0] === ZLIB_VERSION ? data.subarray(1) : data;
    const inflated = inflateSync(body);
    if (inflated.length > 65536) return null;
    const json = decodeJSON(inflated);
    if (json == null) return null;
    return Array.isArray(json)
      ? isLegacyCompactArray(json)
        ? profileFromLegacyArray(json)
        : profileFromCurrentArray(json)
      : json;
  } catch {
    return null;
  }
}

function isValidWriteURL(urlString, base = WRITE_BASE) {
  if (!urlString.startsWith(base)) return false;
  const rest = urlString.slice(base.length);
  if (!rest.startsWith('#d=')) return false;
  const payload = rest.slice(3);
  if (!payload) return false;
  // Match Swift OwnerBandURI — reject # ? & whitespace before charset check.
  if (/[#?&\s]/.test(payload)) return false;
  return /^[A-Za-z0-9_-]+$/.test(payload);
}

/** Mirror Swift `ProfileNFCCodec.extractPayload` + tapper `split('&')[0]`. */
function extractPayload(raw) {
  const trimmed = String(raw || '').trim();
  if (!trimmed) return null;
  let payload;
  const idx = trimmed.indexOf('#d=');
  if (idx >= 0) payload = trimmed.slice(idx + 3);
  else payload = trimmed;
  const amp = payload.indexOf('&');
  if (amp >= 0) payload = payload.slice(0, amp);
  return payload || null;
}

function isBase64urlCharset(s) {
  return /^[A-Za-z0-9_-]*$/.test(s);
}

function sampleChip() {
  return {
    name: 'Jane Doe',
    dob: '1990-03-14',
    blood: 'O+',
    donor: true,
    pregnant: true,
    deafOrVisionImpaired: false,
    allergies: ['Penicillin'],
    meds: ['Levothyroxine'],
    conditions: ['Hypothyroidism'],
    contacts: [{ name: 'Sam', rel: 'Spouse', phone: '+15551212' }],
    updated: '2026-08-31',
  };
}

// --- constant lockstep ---
const swift = readFileSync(join(ROOT, 'RedMed-Xcode/RedMed/ProfileNFCCodec.swift'), 'utf8');
const tapper = readFileSync(join(ROOT, 'tapper/index.html'), 'utf8');
const appConfig = readFileSync(join(ROOT, 'RedMed-Xcode/RedMed/AppConfig.swift'), 'utf8');
const profileData = readFileSync(join(ROOT, 'RedMed-Xcode/RedMed/ProfileData.swift'), 'utf8');
const support = readFileSync(join(ROOT, 'support/index.html'), 'utf8');

assert('KEY_LABEL in Swift', swift.includes(`keyLabel = "${KEY_LABEL}"`));
assert('KEY_LABEL in tapper', tapper.includes(`KEY_LABEL = '${KEY_LABEL}'`));
assert('AES 0x02 Swift', /aesVersion: UInt8 = 0x02/.test(swift));
assert('AES 0x02 tapper', /AES_VERSION = 0x02/.test(tapper));
assert('zlib 0x01 Swift', /zlibVersion: UInt8 = 0x01/.test(swift));
assert('zlib 0x01 tapper', /ZLIB_VERSION = 0x01/.test(tapper));
assert('MAX_PAYLOAD Swift', swift.includes('maxEncodedLength = 8192'));
assert('MAX_PAYLOAD tapper', tapper.includes('MAX_PAYLOAD = 8192'));
assert('MAX_STR Swift', /maxStr = 200/.test(swift));
assert('MAX_STR tapper', tapper.includes('MAX_STR = 200'));
assert('MAX_LIST Swift', /maxList = 40/.test(swift));
assert('MAX_LIST tapper', tapper.includes('MAX_LIST = 40'));
assert('current idx name=4 Swift', /static let name = 4/.test(swift));
assert('current idx blood=0 Swift', /static let blood = 0/.test(swift));
assert('current idx notes=12 Swift', /static let notes = 12/.test(swift));
assert('legacy idx name=0 Swift', /static let name = 0/.test(swift));
assert('write base AppConfig', appConfig.includes(`"${WRITE_BASE}"`));
assert('empty persist guard', profileData.includes('if !hasSensitiveProfileData') && profileData.includes('return false'));
assert('embed escapes lt', swift.includes('u003c'));

// --- OwnerBandURI ---
assert('URI accept AES payload', isValidWriteURL(`${WRITE_BASE}#d=${b64url(Buffer.from('x'))}`));
assert('URI reject empty', !isValidWriteURL(`${WRITE_BASE}#d=`));
assert('URI reject other host', !isValidWriteURL(`https://example.com/tapper/#d=abc`));
assert('URI reject query', !isValidWriteURL(`${WRITE_BASE}#d=abc?x=1`));
assert('URI reject second hash', !isValidWriteURL(`${WRITE_BASE}#d=abc#more`));
assert('URI reject space', !isValidWriteURL(`${WRITE_BASE}#d=ab c`));
assert('URI reject +', !isValidWriteURL(`${WRITE_BASE}#d=ab+c`));
assert('URI reject amp tab', !isValidWriteURL(`${WRITE_BASE}#d=abc&tab=aid`));
assert('Swift strips amp in extract', /firstIndex\(of: "&"\)/.test(swift));
assert('Swift decode charset gate', swift.includes('isBase64urlCharset'));
assert('tapper splits amp', /hash\.slice\(3\)\.split\('&'\)\[0\]/.test(tapper));

const ampPayload = b64url(Buffer.from('x'));
assert('extract strips &tab=', extractPayload(`${WRITE_BASE}#d=${ampPayload}&tab=aid`) === ampPayload);
assert('extract bare payload', extractPayload(ampPayload) === ampPayload);
assert('extract empty after amp', extractPayload('#d=&tab=aid') === null);
assert('charset rejects plus', !isBase64urlCharset('ab+c'));
assert('charset accepts url', isBase64urlCharset(ampPayload));

const tapperCrash = appConfig.match(/static let tapperNote =\s+"([^"]+)"/);
assert('crash tapper note lockstep', !!(tapperCrash && tapper.includes(tapperCrash[1])));

const findHelpCrash = appConfig.match(/static let findHelpNote =\s+"([^"]+)"/);
assert(
  'crash findHelpNote names iPhone Crash Detection for lock/kill',
  !!(
    findHelpCrash &&
    /iPhone Crash Detection/.test(findHelpCrash[1]) &&
    /lock or kill/.test(findHelpCrash[1]) &&
    /while RedMed is open/.test(findHelpCrash[1])
  )
);
assert(
  'support page matches findHelpNote lock/kill honesty',
  !!(findHelpCrash && /iPhone Crash Detection/.test(support) && /lock or kill/.test(support))
);

const localOnly = appConfig.match(/static let localOnlyLine =\s+"([^"]+)"/);
assert('Aid localOnlyLine lockstep', !!(localOnly && tapper.includes(localOnly[1])));
assert('early vitals expandBlood', /function expandBloodEarly/.test(tapper) && /EARLY_BLOOD/.test(tapper));
assert('GPS pill status lockstep', /id="gpsPill"/.test(tapper) && /setGpsPill\('LIVE GPS'\)/.test(tapper) && /ACQUIRING GPS/.test(tapper));
assert('CPR Beat & Breath on tapper', /id="cprToggle"/.test(tapper) && /Start Beat/.test(tapper) && /scheduleCPR\(545\)/.test(tapper));

function extractFn(name, params) {
  const re = new RegExp('function ' + name + '\\(' + params + '\\) \\{([\\s\\S]*?)\\n\\s*\\}');
  const m = tapper.match(re);
  if (!m) throw new Error('missing ' + name);
  return new Function(...params.split(', '), m[1]);
}

const cprBeatDelay = extractFn('cprBeatDelay', 'prevAt, now, ms');
{
  const first = cprBeatDelay(0, 1000, 545);
  assert('cpr first beat is 545ms', first.delay === 545 && first.at === 1545);
  // Fired 55ms late — next delay shortens so the 110 bpm grid does not slip.
  const late = cprBeatDelay(first.at, 1600, 545);
  assert('cpr late tick catches up', late.at === 2090 && late.delay === 490);
  const stalled = cprBeatDelay(late.at, 5000, 545);
  assert('cpr stall does not burst', stalled.delay === 545 && stalled.at === 5545);
}

const jerkSampleDt = extractFn('jerkSampleDt', 'lastAt, now, fallback');
assert('jerk uses 50Hz until a sample exists', jerkSampleDt(0, 1, 0.02) === 0.02);
assert('jerk uses real 60Hz gap', Math.abs(jerkSampleDt(1, 1.0167, 0.02) - 0.0167) < 1e-9);
assert('jerk ignores a long pause', jerkSampleDt(1, 1.5, 0.02) === 0.02);
// 2g step at 100Hz is 200 g/s. Fixed 0.02s DT reports only 100 and drops it.
const stepG = 2;
const fastDt = jerkSampleDt(1, 1.01, 0.02);
assert('fixed DT would hide a fast jerk', (stepG / 0.02) < 140 && (stepG / fastDt) >= 140);
assert('fast sample keeps a 200 g/s jerk', Math.abs(stepG / fastDt - 200) < 1e-6);

assert('logo waits for profile paint', !tapper.includes('redmedLogoPreload') && !/id="rmLogo"[^>]*\ssrc=/.test(tapper));
assert('GPS skips sub-5m jitter', /function metersBetween\(lat1, lon1, lat2, lon2\)/.test(tapper) && /moved = metersBetween\(prev\.latitude, prev\.longitude, lat, lon\) >= 5/.test(tapper));

const sw = readFileSync(join(ROOT, 'sw.js'), 'utf8');
assert('sw cache v172', sw.includes("CACHE = 'redmed-tapper-v173'"));
{
  const assetsBlock = sw.match(/var ASSETS = \[([\s\S]*?)\];/);
  assert('sw does not precache out-of-scope assets', !!(assetsBlock && !assetsBlock[1].includes('../')));
}

// --- plaintext named JSON (smoke / Linux preview path) ---
const named = {
  name: 'Jane Doe',
  dob: '1990-03-14',
  blood: 'O+',
  donor: true,
  allergies: ['Penicillin'],
  meds: ['Levothyroxine'],
  conditions: ['Hypothyroidism'],
  contacts: [{ name: 'Sam', rel: 'Spouse', phone: '5551212' }],
  updated: '2026-08-31',
};
const namedB64 = b64url(Buffer.from(JSON.stringify(named)));
const namedOut = decodePayload(namedB64);
assert('plaintext JSON name', namedOut && namedOut.name === 'Jane Doe');
assert('plaintext JSON blood', namedOut && namedOut.blood === 'O+');

// --- current compact + pregnant flag ---
const chip = sampleChip();
const current = compactArray(chip);
assert('current not legacy', !isLegacyCompactArray(current));
assert('current donor at 8', current[8] === 1);
assert('current pregnant at 10', current[10] === 1);
const fromCurrent = profileFromCurrentArray(current);
assert('current decode name', fromCurrent.name === 'Jane Doe');
assert('current decode pregnant', fromCurrent.pregnant === true);
assert('current decode deaf false', fromCurrent.deafOrVisionImpaired === false);
assert('current decode notes empty', !fromCurrent.notes);

const withNotes = Object.assign({}, sampleChip(), { notes: 'Pacemaker. No MRI.' });
const notesRow = compactArray(withNotes);
assert('notes at 12', notesRow[12] === 'Pacemaker. No MRI.');
const fromNotes = profileFromCurrentArray(notesRow);
assert('notes decode', fromNotes.notes === 'Pacemaker. No MRI.');
assert('notes keeps pregnant', fromNotes.pregnant === true);

// --- legacy compact ---
const legacy = ['Jane Doe', '1990-03-14', 'O+', 1, ['Penicillin'], ['Levothyroxine'], ['Hypothyroidism'], [['Sam', 'Spouse', '5551212']], '2026-08-31'];
assert('legacy detected', isLegacyCompactArray(legacy));
const fromLegacy = profileFromLegacyArray(legacy);
assert('legacy decode name', fromLegacy.name === 'Jane Doe');
assert('legacy decode donor', fromLegacy.donor === true);

// name that looks like blood must not flip current→legacy when donor is at 8
const oPos = ['O+', 'Penicillin', 'meds', '5551212', 'O+', '1990-03-14', 'cond', [], 0, '2026'];
assert('O+ name stays current', !isLegacyCompactArray(oPos));

// --- AES-GCM round-trip (CryptoKit combined = nonce || ciphertext || tag) ---
const jsonBytes = Buffer.from(JSON.stringify(current));
const sealed = aesSeal(jsonBytes);
assert('AES payload starts 0x02', sealed[0] === AES_VERSION);
const opened = aesOpen(sealed);
assert('AES open JSON', opened && opened.toString() === jsonBytes.toString());
const encoded = b64url(sealed);
assert('AES encoded length', encoded.length > 0 && encoded.length <= MAX_PAYLOAD);
const round = decodePayload(encoded);
assert('AES round name', round && round.name === 'Jane Doe');
assert('AES round blood', round && round.blood === 'O+');
assert('AES round pregnant', round && round.pregnant === true);
assert('AES round contact', round && round.contacts[0] && round.contacts[0].name === 'Sam');
assert('AES write URL', isValidWriteURL(`${WRITE_BASE}#d=${encoded}`));

const notesJson = Buffer.from(JSON.stringify(notesRow));
const notesRound = decodePayload(b64url(aesSeal(notesJson)));
assert('AES round notes', notesRound && notesRound.notes === 'Pacemaker. No MRI.');

const tampered = Buffer.from(sealed);
tampered[20] ^= 0xff;
assert('AES tamper fails', aesOpen(tampered) === null);

// --- zlib 0x01 named JSON ---
const zbody = deflateSync(Buffer.from(JSON.stringify(named)));
const zpayload = Buffer.concat([Buffer.from([ZLIB_VERSION]), zbody]);
const zround = decodePayload(b64url(zpayload));
assert('zlib 0x01 name', zround && zround.name === 'Jane Doe');

// --- field caps ---
const long = 'x'.repeat(250);
assert('clipStr 200', clipStr(long).length === MAX_STR);
const many = Array.from({ length: 50 }, (_, i) => `item${i}`);
assert('joinList 40', joinList(many).split(', ').length === MAX_LIST);
assert('joinList flattens comma in item', joinList(['Penicillin, Sulfa']) === 'Penicillin, Sulfa');
assert('splitList flattens comma in item', splitList('Penicillin, Sulfa').join('|') === 'Penicillin|Sulfa');
assert('splitList flattens comma in array item', splitList(['Penicillin, Sulfa']).join('|') === 'Penicillin|Sulfa');

// --- passerby empty-state / SOS auto-arm gates (tapper/index.html) ---
const tapperSrc = readFileSync(join(ROOT, 'tapper/index.html'), 'utf8');
assert('profileHasContent in tapper', tapperSrc.includes('function profileHasContent'));
assert('is-unlinked toggle in tapper', tapperSrc.includes("classList.toggle('is-unlinked'"));
assert('first-paint is-unlinked without #d=', tapperSrc.includes('classList.add("is-unlinked")') || tapperSrc.includes("classList.add('is-unlinked')"));
assert('decode-fail empty copy', tapperSrc.includes("Couldn't Read This Band") && tapperSrc.includes('function paintEmptyStateCopy'));
assert('zlib missing DecompressionStream hint', tapperSrc.includes('cannot decode older band formats'));
assert('passerby loaded not Linked Bracelet', tapperSrc.includes('Medical ID Loaded'));
assert('paintedFromBand requires content', tapperSrc.includes('paintedFromBand = !!fromBand && hasPatient'));
assert('treat-first early vitals script', tapperSrc.includes('__redmedEarlyVitals') && tapperSrc.includes('Treat-first:'));
assert('hashchange re-decodes #d=', tapperSrc.includes('decodeProfile().then(function (p)') && tapperSrc.includes('hashchange'));
assert('own-phone handoff before SOS', tapperSrc.includes('redmed://band') && tapperSrc.includes('handoffToInstalledAppThenMaybeArm'));
const tapperAid = tapperSrc.indexOf('id="aidStopAlarm"');
const tapper911 = tapperSrc.indexOf('id="panel-911"');
const tapperAidPanel = tapperSrc.indexOf('id="panel-aid"');
assert('Stop The Alarm lives on 911', tapper911 >= 0 && tapperAid > tapper911 && (tapperAidPanel < 0 || tapperAid < tapperAidPanel));
assert('crash hint names Stop The Alarm', tapperSrc.includes('Tap Stop The Alarm to cancel'));
assert('device aspect early pick', tapperSrc.includes('__redmedPickDevice') && tapperSrc.includes('shortSide < 500'));
assert('device aspect auto aria-current', tapperSrc.includes("setAttribute('aria-current', 'true')"));
assert('device aspect orientationchange', tapperSrc.includes("orientationchange"));
const extracted = tapperSrc.match(/function profileHasContent\(p\) \{[\s\S]*?\n  \}/);
assert('profileHasContent extract', !!extracted);
if (extracted) {
  const profileHasContent = new Function(`${extracted[0]}; return profileHasContent;`)();
  assert('empty object no content', profileHasContent({}) === false);
  assert('empty array no content', profileHasContent([]) === false);
  assert('null no content', profileHasContent(null) === false);
  assert('name is content', profileHasContent({ name: 'Jane Doe' }) === true);
  assert('blood is content', profileHasContent({ blood: 'O+' }) === true);
  assert('notes is content', profileHasContent({ notes: 'Pacemaker' }) === true);
  assert('blank name no content', profileHasContent({ name: '  ' }) === false);
}

if (failed) {
  console.error(`test-d-codec failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-d-codec OK');
