#!/usr/bin/env bash
#
# Build scaling-book.pdf from a checkout of the upstream book.
#
# Robustness model (so an upstream content change does not break the build):
#   1. General preprocessing (preprocess.py) fixes whole *classes* of
#      MathJax-vs-LaTeX mismatches, not specific strings.
#   2. A broad preamble (preamble.tex) defines MathJax-only macros and maps
#      Unicode/emoji that the PDF fonts lack.
#   3. TOLERANT COMPILE: we run pandoc -> .tex, then xelatex in nonstopmode and
#      accept the build as long as a PDF of reasonable length is produced. An
#      unknown macro or glyph then degrades one spot instead of failing the job.
#
# Usage: build/build.sh <path-to-upstream-checkout> <path-to-output-pdf>
# Requires on PATH: pandoc, xelatex, python3, convert (ImageMagick), pdfinfo.

set -euo pipefail

UPSTREAM="${1:?usage: build.sh <upstream-dir> <output-pdf>}"
OUT_PDF="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Minimum number of pages we expect a real build to contain. If xelatex bails
# out catastrophically we get a near-empty PDF; this gate catches that.
MIN_PAGES="${MIN_PAGES:-150}"

cd "$UPSTREAM"

echo "==> Combining chapters (upstream script)"
python3 bin/convert_to_single_md.py

echo "==> Flattening animated GIFs to PNG"
# ImageMagick 7 uses `magick`, 6 uses `convert`. Support both.
if command -v magick >/dev/null 2>&1; then IM="magick"; else IM="convert"; fi
shopt -s globstar nullglob
for f in assets/**/*.gif; do
  "$IM" "${f}[0]" "${f%.gif}.png" && echo "    $f -> ${f%.gif}.png"
done

echo "==> Preprocessing combined markdown"
python3 "$HERE/preprocess.py" scaling-book-combined.md

echo "==> pandoc: markdown -> LaTeX"
pandoc scaling-book-combined.md \
  -o book.tex -s \
  --toc --toc-depth=2 \
  --top-level-division=chapter \
  --include-in-header="$HERE/preamble.tex" \
  -V geometry:margin=0.85in \
  -V colorlinks=true -V linkcolor=blue -V urlcolor=blue -V toccolor=black \
  -V documentclass=report \
  --metadata title="How to Scale Your Model" \
  --metadata author="Austin et al., Google DeepMind"

echo "==> xelatex (tolerant, 2 passes for TOC)"
# nonstopmode + '|| true': never abort the script on a recoverable LaTeX error.
for pass in 1 2; do
  echo "    pass $pass"
  xelatex -interaction=nonstopmode -file-line-error book.tex >"xelatex-pass$pass.log" 2>&1 || true
done

if [ ! -f book.pdf ]; then
  echo "ERROR: xelatex produced no PDF at all. Tail of log:" >&2
  tail -n 40 xelatex-pass2.log >&2 || true
  exit 1
fi

PAGES="$(pdfinfo book.pdf 2>/dev/null | awk '/^Pages:/{print $2}')"
PAGES="${PAGES:-0}"
echo "==> Produced book.pdf with $PAGES pages (gate: >= $MIN_PAGES)"
if [ "$PAGES" -lt "$MIN_PAGES" ]; then
  echo "ERROR: PDF has only $PAGES pages; treating as a failed build." >&2
  echo "Last LaTeX errors:" >&2
  grep -iE "^.*:[0-9]+:|! " "xelatex-pass2.log" | head -n 30 >&2 || true
  exit 1
fi

cp book.pdf "$OUT_PDF"
echo "==> Wrote $OUT_PDF"

# Surface a warning summary so quality regressions are visible even on success.
echo "==> LaTeX warning summary (non-fatal):"
{
  grep -c "Undefined control sequence" xelatex-pass2.log | sed 's/^/    undefined macros: /'
  grep -c "Missing character" xelatex-pass2.log | sed 's/^/    missing glyphs:   /'
  grep -c "Overfull\|Underfull" xelatex-pass2.log | sed 's/^/    over/underfull:   /'
} 2>/dev/null || true
