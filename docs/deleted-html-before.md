# HTML before delete (commit e88de61 / parent of ea676c9)
Deleted in `ea676c9` — restoring intent as Swift under `Main.swift` except card + policies.

## Deleted

| File | Bytes | Role |
|------|------:|------|
| `get.html` | 6155 | App Store / band setup landing — owner packaging page |
| `Main.dc.html` | 168413 | Claude design canvas for full owner UI (tabs, edit, NFC, Aid) |
| `RedMed.html` | 308012 | Bundled preview of Main.dc.html design canvas |
| `RedMed-standalone.html` | 475768 | Standalone bundled preview of Main.dc.html |

## Kept as HTML (non-app)

- `card.html` (+ `assets/`) — Passerby bracelet scan page for Cloudflare Pages
- Policy HTML + `legal-doc.css` — sole copies under `RedMed-Xcode/RedMed/` (app bundle);
  repo-root policy duplicates removed
- `HowItWorks.html` — thin redirect stub under `RedMed-Xcode/RedMed/` → `redmed://main`

## get.html excerpt (before)

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Set up your RedMed band</title>
<meta name="description" content="Program your RedMed NFC band once on iPhone. After that, anyone can tap the band — their phone opens your emergency card. No app for readers.">
<link rel="stylesheet" href="assets/legal-doc.css">
<style>
  body { display:flex; align-items:center; justify-content:center; padding:40px 16px 80px; }
  .get-card {
    width:100%; max-width:400px;
    background:rgba(255,255,255,0.05);
    border:1px solid rgba(255,255,255,0.08);
    border-radius:24px;
    padding:36px 28px 32px;
    text-align:center;
  }
  .brand {
    font-size:28px; font-weight:800; letter-spacing:-0.6px; color:#e11d48; margin-bottom:4px;
  }
  .hero-well {
    width:88px; height:88px; margin:24px auto 20px;
    display:grid; place-items:center; position:relative;
  }
  .hero-well .ring { position:absolute; inset:0; border-radius:50%; border:1.5px solid rgba(225,29,72,0.2); }
  .hero-well .fill { position:absolute; inset:10px; border-radius:50%; background:rgba(225,29,72,0.1); }
  .hero-well svg
```

## Main.dc.html excerpt (before)

```html
<template id="__bundler_thumbnail" data-bg-color="#0a0a0a">
  <svg viewBox="0 0 120 80" xmlns="http://www.w3.org/2000/svg">
    <rect width="120" height="80" fill="#0a0a0a"/>
    <circle cx="60" cy="36" r="22" fill="#e11d48" opacity="0.15"/>
    <text x="60" y="42" font-family="Georgia,serif" font-size="18" font-weight="bold" fill="#e11d48" text-anchor="middle">R</text>
    <text x="60" y="62" font-family="sans-serif" font-size="6" fill="#fff" text-anchor="middle" opacity="0.5">REDMED</text>
  </svg>
</template>
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="">
<link href="https://fonts.googleapis.com/css2?family=Plus+Ja
```
