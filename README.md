# scaling-book-pdf

Automatically builds a PDF of the [**How to Scale Your Model**](https://github.com/jax-ml/scaling-book)
book (by Austin et al., Google DeepMind) and commits it into this repo.

The latest build lives at [`scaling-book.pdf`](scaling-book.pdf).

## How it works

A scheduled GitHub Action ([`.github/workflows/build-pdf.yml`](.github/workflows/build-pdf.yml)):

1. Runs **once a day** (and can be triggered manually from the Actions tab).
2. Checks the latest commit SHA on the upstream `main` branch with `git ls-remote`
   (no full clone needed just to check).
3. Compares it against `.last_build_sha`, the SHA from the previous build.
   - **No change** → the job skips the build entirely.
   - **New commit** → it clones upstream, builds the PDF, and pushes
     `scaling-book.pdf` + the updated `.last_build_sha` back to this repo.

### Build pipeline

- `python bin/convert_to_single_md.py` (lives in the upstream repo) merges all
  chapters into one `scaling-book-combined.md`, normalizing Jekyll/Liquid markup
  and math along the way.
- Animated GIFs are flattened to PNG (LaTeX can't embed GIFs).
- `pandoc` + `xelatex` render the combined markdown to PDF.

## Configuration

- **Schedule:** edit the `cron` line in the workflow (`0 6 * * *` = 06:00 UTC daily).
- **Force a rebuild:** Actions tab → *Build Scaling Book PDF* → *Run workflow* →
  set *force* to `true`.

## First run

After pushing this repo to GitHub, trigger the workflow once manually
(Actions → Run workflow) so it produces the first PDF. Make sure
**Settings → Actions → General → Workflow permissions** is set to
*Read and write permissions* so the Action can commit the PDF.

## Building locally

```bash
git clone https://github.com/jax-ml/scaling-book.git upstream
cd upstream
python bin/convert_to_single_md.py
# flatten gifs
for f in assets/**/*.gif; do convert "${f}[0]" "${f%.gif}.png"; done
sed -i 's/\.gif/\.png/g' scaling-book-combined.md
pandoc scaling-book-combined.md -o ../scaling-book.pdf \
  --pdf-engine=xelatex --toc -V geometry:margin=1in
```

(Requires `pandoc`, a LaTeX engine with `xelatex`, and ImageMagick.)

---

The book content is © its authors and distributed under the upstream repo's
license. This repo only automates building a PDF from it.
