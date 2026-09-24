#!/usr/bin/env node
/**
 * NFC hardware contract (static, no Xcode): chip model, RF constants, tap
 * geometry, write gate, NDEF contract, read-back verify, no permanent lock
 * bytes, CoreNFC session type, simulator guard. Reads the Swift/plist source
 * as text (same approach as test-d-codec.mjs) so it runs on Linux CI.
 *
 *   node scripts/test-nfc-hardware.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

let failed = 0;
let total = 0;
function assert(name, cond, detail) {
  total += 1;
  if (cond) {
    console.log(`OK   ${name}`);
  } else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

const appConfig = readFileSync(join(ROOT, 'owner/RedMed/AppConfig.swift'), 'utf8');
const writer = readFileSync(join(ROOT, 'owner/RedMed/NFCWriter.swift'), 'utf8');
const reader = readFileSync(join(ROOT, 'owner/RedMed/NFCReader.swift'), 'utf8');
const manager = readFileSync(join(ROOT, 'owner/RedMed/NFCBandManager.swift'), 'utf8');
const codec = readFileSync(join(ROOT, 'owner/RedMed/ProfileNFCCodec.swift'), 'utf8');
const contentView = readFileSync(join(ROOT, 'owner/RedMed/ContentView.swift'), 'utf8');
const entitlements = readFileSync(join(ROOT, 'owner/RedMed/RedMed.entitlements'), 'utf8');
const infoPlist = readFileSync(join(ROOT, 'owner/RedMed/Info.plist'), 'utf8');
const doc = readFileSync(join(ROOT, 'owner/RedMed/Document/Document.html'), 'utf8');

// --- Chip model (NTAG216-only) ---
assert('chip part is NXP NTAG216', appConfig.includes('static let chipPart = "NXP NTAG216"'));
assert('chip family ISO 14443A Type 2 (NXP NTAG216)', appConfig.includes('static let family = "ISO 14443A Type 2 (NXP NTAG216)"'));
assert('writer rejects non-NTAG216 families by name', writer.includes('Not NTAG213/215, MIFARE, LF, or UHF'));
assert('writer capacity error names NXP NTAG216', writer.includes('Product band is NXP NTAG216'));
assert('codec capacity note names NXP NTAG216', codec.includes('too large for NXP NTAG216') && codec.includes('bytes on tag — NXP NTAG216'));
assert('AppConfig chip-sourcing comment names NTAG215 alongside NTAG213', appConfig.includes('Do not source NTAG213, NTAG215, MIFARE, LF (~125 kHz), or UHF (~860–960 MHz).'));
assert('Document.html names passive NXP NTAG216 chip', doc.includes('<strong>passive NXP NTAG216</strong> at 13.56 MHz (ISO 14443A Type 2, NDEF blank unlocked)'));

// --- RF constants ---
assert('carrier is 13.56 MHz', /static let carrierMHz: Double = 13\.56/.test(appConfig));
assert('walk-by standoff min 6"', /static let walkByStandoffInchesMin = 6/.test(appConfig));
assert('walk-by standoff max 8"', /static let walkByStandoffInchesMax = 8/.test(appConfig));
assert('intentional tap min 1"', /static let intentionalTapInchesMin = 1/.test(appConfig));
assert('intentional tap max 2"', /static let intentionalTapInchesMax = 2/.test(appConfig));
assert('reliable coupling max 4"', /static let reliableCouplingInchesMax = 4/.test(appConfig));

// --- Tap geometry ---
assert('face art logo lockstep (30x9mm)', appConfig.includes('(30×9 mm) on black'));
assert('Document.html face art lockstep', doc.includes('on black silicone (<code>#232425</code>) at 30×9 mm'));
assert('RedMed never starts NFC on mere proximity', /static let requiresExplicitUserSession = true/.test(appConfig));
assert('tap distance summary: walk-by does not fire, deliberate tap does', appConfig.includes("Walk-by won't fire (\\(walkByRangeLabel)). Only a deliberate \\(intentionalTapRangeLabel) antenna tap opens the card."));
assert('ContentView hold-to-write geometry comment', contentView.includes('Hold the band ~1–2″ finishes the program — iOS has no silent write.'));

// --- Write gate ---
assert('writeBand refuses scanner sessions', manager.includes('guard !isScannerSession else { return }'));
assert('writeBand refuses while busy', manager.includes('guard !isBusy else { return }'));
assert('writeBand requires sensitive profile data', manager.includes('guard profile.hasSensitiveProfileData else { return }'));
assert('writeBand enforces NTAG216 850-byte cap', manager.includes('if urlString.utf8.count > 850 {'));
assert('NFCWriter refuses non #d= write URLs', writer.includes('guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else {'));
assert('NFCWriter gated on nfcHardwareEnabled', writer.includes('guard AppConfig.nfcHardwareEnabled else {'));
assert('NFCWriter requires NFC hardware available', writer.includes('guard NFCNDEFReaderSession.readingAvailable else {'));
assert('parked builds only pack — never open a CoreNFC write session', manager.includes('// Parked: pack only — never a Write, never Linked.'));

// --- NDEF contract ---
assert('NDEF record is Well Known Type "U"', writer.includes('type: Data("U".utf8)'));
assert('URI identifier 0x04 maps to https://', writer.includes('(0x04, "https://")'));
assert('write message is a single-record NFCNDEFMessage', writer.includes('let message = NFCNDEFMessage(records: [payload])'));
assert('write checks message length against tag capacity', writer.includes('if capacity > 0, message.length > capacity {'));
assert('queryNDEFStatus handles notSupported/readOnly/readWrite/@unknown', writer.includes('case .notSupported:') && writer.includes('case .readOnly:') && writer.includes('case .readWrite:') && writer.includes('@unknown default:'));
assert('NFCReader decodes only via NFCURICodec.string(from:)', reader.includes('NFCURICodec.string(from: payload)'));
assert('decodeProfile requires a #d= fragment', codec.includes('urlString.range(of: "#d=") != nil'));

// --- Read-back verify ---
assert('write is followed by a readNDEF read-back', writer.includes('tag.writeNDEF(message) { error in') && writer.includes('tag.readNDEF { readMessage, readError in'));
assert('read-back is compared against the written URL via NFCURICodec.match', writer.includes('let ok = written.map { NFCURICodec.match($0, urlString) } ?? false'));
assert('linkBracelet requires a verified read-back before pairing', manager.includes('guard AppConfig.nfcHardwareEnabled, writeVerified else { return }'));

// --- No permanent lock bytes ---
assert('factory does not pre-lock the tag', /static let factoryLock = false/.test(appConfig));
assert('band stays rewritable (not permanently locked)', /static let isRewritable = true/.test(appConfig));
assert('factory does not pre-encode NDEF', /static let factoryPreEncode = false/.test(appConfig));
assert('locked/read-only tags are refused, never force-written', writer.includes('This tag is locked/read-only. RedMed needs NDEF blank unlocked — no factory lock.'));
assert('no lock-byte / permalock API is ever invoked', !writer.includes('writeLock') && !reader.includes('writeLock') && !manager.includes('writeLock'));

// --- CoreNFC session type ---
assert('NFCWriter opens an NDEF (not raw tag) session', writer.includes('NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)'));
assert('NFCReader opens an NDEF (not raw tag) session', reader.includes('NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)'));
assert('neither session uses raw NFCTagReaderSession (lock-byte capable)', !writer.includes('NFCTagReaderSession') && !reader.includes('NFCTagReaderSession'));
assert('both delegates conform to NFCNDEFReaderSessionDelegate', writer.includes('extension NFCWriter: NFCNDEFReaderSessionDelegate') && reader.includes('extension NFCReader: NFCNDEFReaderSessionDelegate'));

// --- Simulator guard ---
assert('NFCWriter has no Simulator fake-success path', writer.includes('No Simulator fake-success path — failures stay failures.'));
assert('NFCReader has no Simulator fake-success path', reader.includes('No Simulator fake-success path — failures stay failures.'));
assert('NFCReader also requires hardware NFC availability', reader.includes('guard NFCNDEFReaderSession.readingAvailable else {'));
{
  const hardwareEnabled = /static let nfcHardwareEnabled = true/.test(appConfig);
  const entitled = entitlements.includes('com.apple.developer.nfc.readersession') && infoPlist.includes('NFCReaderUsageDescription');
  assert(
    'NFC entitlement + usage description stay in lockstep with nfcHardwareEnabled',
    hardwareEnabled === entitled,
    `nfcHardwareEnabled=${hardwareEnabled} entitled=${entitled}`,
  );
}

console.log(`\n${total} check(s), ${failed} failed.`);
if (failed) {
  console.error(`test-nfc-hardware failed: ${failed} check(s)`);
  process.exit(1);
}
console.log('test-nfc-hardware OK');
