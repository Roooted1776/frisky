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
const WRITE_BASE = 'https://roooted1776.github.io/tapper/';
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
function joinList(items) {
  return (items || [])
    .slice(0, MAX_LIST)
    .map((s) => clipStr(String(s).trim()))
    .filter(Boolean)
    .join(', ');
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
  if (chip.pregnant || chip.deafOrVisionImpaired) {
    if (!chip.updated) row.push('');
    row.push(chip.pregnant ? 1 : 0);
    row.push(chip.deafOrVisionImpaired ? 1 : 0);
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
    return v.filter((x) => typeof x === 'string').slice(0, MAX_LIST).map((s) => s.slice(0, MAX_STR));
  }
  if (typeof v !== 'string' || !v) return [];
  return v.split(',').map((s) => s.trim().slice(0, MAX_STR)).filter(Boolean).slice(0, MAX_LIST);
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
  if (/[#?\s]/.test(payload)) return false;
  return /^[A-Za-z0-9_-]+$/.test(payload);
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
assert('legacy idx name=0 Swift', /static let name = 0/.test(swift));
assert('write base AppConfig', appConfig.includes(`"${WRITE_BASE}"`));
assert('empty persist guard', profileData.includes('if !hasSensitiveProfileData && (Self.hasStoredProfile()'));
assert('embed escapes lt', swift.includes('u003c'));

// --- OwnerBandURI ---
assert('URI accept AES payload', isValidWriteURL(`${WRITE_BASE}#d=${b64url(Buffer.from('x'))}`));
assert('URI reject empty', !isValidWriteURL(`${WRITE_BASE}#d=`));
assert('URI reject other host', !isValidWriteURL(`https://example.com/tapper/#d=abc`));
assert('URI reject query', !isValidWriteURL(`${WRITE_BASE}#d=abc?x=1`));
assert('URI reject second hash', !isValidWriteURL(`${WRITE_BASE}#d=abc#more`));
assert('URI reject space', !isValidWriteURL(`${WRITE_BASE}#d=ab c`));
assert('URI reject +', !isValidWriteURL(`${WRITE_BASE}#d=ab+c`));

const tapperCrash = appConfig.match(/static let tapperNote =\s+"([^"]+)"/);
assert('crash tapper note lockstep', !!(tapperCrash && tapper.includes(tapperCrash[1])));

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

if (failed) {
  console.error(`test-d-codec failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-d-codec OK');
