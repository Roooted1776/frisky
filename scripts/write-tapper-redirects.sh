#!/usr/bin/env bash
# One #d=-preserving redirect stub → /tapper/ for every legacy Pages URL.
# Source of truth for the shell remains tapper/index.html.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Heredoc (not a single-quoted string) so JS string literals keep their quotes.
STUB=$(cat <<'EOF'
<!doctype html>
<html lang="en-US">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#fff7f7">
<meta name="color-scheme" content="light">
<meta name="referrer" content="no-referrer">
<title>RedMed</title>
<style>html,body{background:#fff7f7!important;margin:0}</style>
<!-- Legacy / root URL. Canonical scanner shell is /tapper/ — preserve #d=.
     Fix #3: use URL construction to safely compose the destination. -->
<script>
(function () {
  var dest = new URL('/tapper/', location.origin);
  dest.search = location.search;
  location.replace(dest.pathname + dest.search + location.hash);
})();
</script>
<style>
  body {
    margin: 0;
    min-height: 100vh;
    display: grid;
    place-items: center;
    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", system-ui, sans-serif;
    background: #fff7f7;
    color: #1c1917;
  }
  a { color: #e11d48; font-weight: 600; text-decoration: none; }
  a:focus-visible { outline: 2px solid #e11d48; outline-offset: 3px; }
</style>
</head>
<body>
  <p><a id="fallback" href="/tapper/">Open emergency card</a></p>
  <script>
    var dest = new URL('/tapper/', location.origin);
    dest.search = location.search;
    document.getElementById("fallback").href = dest.pathname + dest.search + location.hash;
  </script>
  <!-- Fix #9: clearer noscript message -->
  <noscript><p>JavaScript is required to open this emergency card. Please enable JavaScript in your browser settings, then reload this page.</p></noscript>
</body>
</html>
EOF
)

mkdir -p get
for f in index.html tapper.html card.html get.html get/index.html redmed-emergency.html; do
  printf '%s\n' "$STUB" > "$f"
done

# Guard: stubs must never become a second shell.
for f in index.html tapper.html card.html get.html get/index.html redmed-emergency.html; do
  ! grep -q 'data-tab="medical"' "$f"
  grep -q '/tapper/' "$f"
  grep -q "new URL('/tapper/', location.origin)" "$f"
done

echo "OK unified tapper redirect stubs"
