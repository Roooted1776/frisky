#!/usr/bin/env python3
"""Idempotent App Store review patches for Swift copy + tapper.html."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str) -> str:
    if new.strip() in text and old not in text:
        return text
    if old not in text:
        return text
    return text.replace(old, new, 1)


def patch_nfc_view(text: str) -> str:
    text = replace_once(
        text,
        """                VStack(spacing: 16) {
                    factsCard
                    setupCard
                        .padding(.top, 4)
                    firstResponderPreviewLink
                }""",
        """                VStack(spacing: 16) {
                    if !AppConfig.nfcHardwareEnabled {
                        parkedBanner
                    }
                    factsCard
                    setupCard
                        .padding(.top, 4)
                    firstResponderPreviewLink
                }""",
    )
    if "private var parkedBanner: some View" not in text:
        text = replace_once(
            text,
            "    private var firstResponderPreviewLink: some View {",
            """    private var parkedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview only")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.redmedAccent)
            Text(AppConfig.BraceletRF.hardwareParkedSummary)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.redmedMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .redmedBox()
        .accessibilityLabel("Band write is preview-only in this build")
    }

    private var firstResponderPreviewLink: some View {""",
        )
    text = replace_once(
        text,
        """    private var writeButtonTitle: String {
        if band.isWriting {
            return "Hold near the band…"
        }
        return "Write the band"
    }""",
        """    private var writeButtonTitle: String {
        if band.isWriting {
            return AppConfig.nfcHardwareEnabled ? "Hold near the band…" : "Packing…"
        }
        return AppConfig.nfcHardwareEnabled ? "Write the band" : "Preview packed card"
    }""",
    )
    text = replace_once(
        text,
        '''                tipRow("Write once after RedMed is filled — blank unlocked NXP NTAG216 (ISO 14443A Type 2).")
                tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                tipRow("Scan / Preview: same HTML card helpers get — quick, no login, no server, no app.")''',
        '''                if AppConfig.nfcHardwareEnabled {
                    tipRow("Write once after RedMed is filled — blank unlocked NXP NTAG216 (ISO 14443A Type 2).")
                    tipRow("Write packs #d= onto the chip only — never a vendor cloud or social/short link.")
                    tipRow("Scan / Preview: same HTML card helpers get — quick, no login, no server, no app.")
                } else {
                    tipRow("This build cannot write a physical band (NFC Tag Reading is parked).")
                    tipRow("Preview packed card opens the same HTML helpers would see — no Linked flag.")
                    tipRow("Live write ships when NFC Tag Reading is on the App ID. See docs/NFC-RESTORE.md.")
                }''',
    )
    return text


def patch_redmed_view(text: str) -> str:
    text = replace_once(
        text,
        """        } else if !profile.showsBraceletAsLinked {
            OwnerNextStepBanner(
                icon: "wave.3.right",
                title: "Write your band",
                detail: "Write the band on the NFC tab so a passerby tap opens this card.",
                actionTitle: "NFC",
                action: {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            )
        }""",
        """        } else if !profile.showsBraceletAsLinked {
            OwnerNextStepBanner(
                icon: "wave.3.right",
                title: AppConfig.nfcHardwareEnabled ? "Write your band" : "Preview the helper card",
                detail: AppConfig.nfcHardwareEnabled
                    ? "Write the band on the NFC tab so a passerby tap opens this card."
                    : "Band write is preview-only in this build. Open NFC to see what helpers would see.",
                actionTitle: "NFC",
                action: {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            )
        }""",
    )
    text = replace_once(
        text,
        '            stepRow(number: "3", title: "Write the band", detail: "NFC tab packs the card onto the chip. Helpers tap. No app, no login.")',
        '            stepRow(number: "3", title: AppConfig.nfcHardwareEnabled ? "Write the band" : "Preview the helper card", detail: AppConfig.nfcHardwareEnabled ? "NFC tab packs the card onto the chip. Helpers tap. No app, no login." : "NFC tab packs the card for Preview. Live band write ships when NFC Tag Reading is on the App ID.")',
    )
    return text


def patch_tapper(text: str) -> str:
    text = text.replace(
        "  // Seizure stopwatch — mirrors owner Find Help; auto-dials at 5:00.\n",
        "  // Seizure stopwatch — mirrors owner Find Help. Never auto-dials.\n",
    )
    text = text.replace(
        """      if (elapsed >= CALL_AT) {
        stop(false);
        location.href = emergencyTel();
        return;
      }
      paint();""",
        """      if (elapsed >= CALL_AT) {
        paint();
        return;
      }
      paint();""",
    )
    text = text.replace(
        '<div class="seizure-hint" id="seizureHint">→ <span class="emg">112</span> at 5:00</div>',
        '<div class="seizure-hint" id="seizureHint">Call <span class="emg">112</span> at 5:00</div>',
    )
    old_paint = """      if (past) {
        hintEl.textContent = '5:00 — call';
      } else {
        hintEl.textContent = '';
        hintEl.appendChild(document.createTextNode('→ '));
        var emg = document.createElement('span');
        emg.className = 'emg';
        emg.textContent = ((document.querySelector('.emg') || {}).textContent || '112');
        hintEl.appendChild(emg);
        hintEl.appendChild(document.createTextNode(' at 5:00'));
      }"""
    new_paint = """      var num = ((document.querySelector('.emg') || {}).textContent || '112');
      hintEl.textContent = '';
      var existingCall = document.getElementById('seizureCallBtn');
      if (past) {
        hintEl.appendChild(document.createTextNode('5:00 — tap Call'));
        if (!existingCall && btn && btn.parentNode) {
          var callBtn = document.createElement('a');
          callBtn.id = 'seizureCallBtn';
          callBtn.className = 'seizure-btn';
          callBtn.setAttribute('href', emergencyTel());
          callBtn.textContent = 'Call';
          btn.parentNode.insertBefore(callBtn, btn);
        } else if (existingCall) {
          existingCall.setAttribute('href', emergencyTel());
        }
      } else {
        if (existingCall && existingCall.parentNode) existingCall.parentNode.removeChild(existingCall);
        hintEl.appendChild(document.createTextNode('Call '));
        var emg = document.createElement('span');
        emg.className = 'emg';
        emg.textContent = num;
        hintEl.appendChild(emg);
        hintEl.appendChild(document.createTextNode(' at 5:00'));
      }"""
    text = text.replace(old_paint, new_paint)
    disclaimer = '<p class="foot-note">First-aid reference only. Not medical advice and not a substitute for emergency dispatch. Call emergency services and follow their instructions.</p>'
    original_foot = '<p class="foot-note">Local only once tap — everyone and everything. No servers · no online. No Bluetooth · passive HF NFC. No PII or PHI leaves this device through RedMed.</p>'
    if disclaimer not in text:
        text = text.replace(
            original_foot,
            disclaimer + "\n        " + original_foot,
        )
    return text


def write_if_changed(path: Path, text: str) -> bool:
    original = path.read_text(encoding="utf-8")
    if original == text:
        print(f"unchanged {path}")
        return False
    path.write_text(text, encoding="utf-8")
    print(f"patched {path}")
    return True


def main() -> int:
    nfc = ROOT / "RedMed-Xcode" / "RedMed" / "NFCView.swift"
    redmed = ROOT / "RedMed-Xcode" / "RedMed" / "RedMedView.swift"
    tappers = [
        ROOT / "tapper.html",
        ROOT / "tapper" / "index.html",
        ROOT / "RedMed-Xcode" / "RedMed" / "tapper.html",
    ]
    write_if_changed(nfc, patch_nfc_view(nfc.read_text(encoding="utf-8")))
    write_if_changed(redmed, patch_redmed_view(redmed.read_text(encoding="utf-8")))
    for path in tappers:
        updated = patch_tapper(path.read_text(encoding="utf-8"))
        if "location.href = emergencyTel()" in updated:
            print(f"FAILED autodial still present in {path}")
            return 1
        write_if_changed(path, updated)
    print("ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
