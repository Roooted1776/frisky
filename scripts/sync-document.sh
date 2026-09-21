#!/usr/bin/env bash
# Keep hosted /Document/ lockstep with the in-app Help source of truth.
# Source: RedMed-Xcode/RedMed/Document/{Document.html,legal-doc.css}
# Host:   Document/index.html (full policy) + Document.html (thin #hash redirect)
#         + legal-doc.css
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC=RedMed-Xcode/RedMed/Document
DST=Document

test -f "$SRC/Document.html"
test -f "$SRC/legal-doc.css"

mkdir -p "$DST"
cp "$SRC/Document.html" "$DST/index.html"
cp "$SRC/legal-doc.css" "$DST/legal-doc.css"

# Hosted Document.html is a stub so /Document/Document.html and /Document/
# stay one policy tree (index.html), not two full copies that can drift.
cat > "$DST/Document.html" <<'EOF'
<!doctype html>
<html lang="en-US">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<meta name="theme-color" content="#fff7f7">
<meta name="referrer" content="no-referrer">
<meta http-equiv="refresh" content="0;url=./">
<link rel="canonical" href="./">
<title>RedMed Policies</title>
<script>
(function () {
  location.replace("./" + (location.search || "") + (location.hash || ""));
})();
</script>
</head>
<body style="margin:0;background:#fff7f7;font:17px/1.5 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1c1917">
<main style="max-width:40rem;margin:0 auto;padding:1.5rem 1.25rem">
  <p>Policies live at <a id="go" href="./">/Document/</a> (same text as in-app Help → Policies).</p>
  <script>
    document.getElementById("go").href = "./" + (location.search || "") + (location.hash || "");
  </script>
</main>
</body>
</html>
EOF

# Hosted index must point passerby card at /tapper/ (not a local tapper.html).
grep -q 'href="/tapper/"' "$DST/index.html"
grep -q 'href="legal-doc.css"' "$DST/index.html"
grep -q 'data-tab="medical"' "$DST/index.html" && {
  echo "FAIL hosted Document/index.html looks like tapper shell" >&2
  exit 1
}
# Stub must not contain the full policy body.
! grep -q 'Automatic crash / severe-impact alarm' "$DST/Document.html"
grep -q 'location.replace("./"' "$DST/Document.html"

# privacy/ is a bounce to Document — never a second policy tree.
grep -q '/Document/' privacy/index.html

echo "OK Document host lockstep with $SRC (index=full, Document.html=redirect)"
