# scaling-book-pdf

Automatically builds a PDF of the [**How to Scale Your Model**](https://github.com/jax-ml/scaling-book)
book (Austin et al., Google DeepMind) and (optionally) commits it into this repo.

The latest build is uploaded as a workflow **artifact** (`scaling-book-pdf`) and,
once enabled, committed to [`scaling-book.pdf`](scaling-book.pdf).

## How it works

A scheduled GitHub Action ([`.github/workflows/build-pdf.yml`](.github/workflows/build-pdf.yml)):

1. Runs **weekly on Monday** (and on-demand from the Actions tab).
2. Reads the latest commit SHA on upstream `main` with `git ls-remote` (cheap — no clone).
3. Compares it against `.last_build_sha`.
   - **No change** → skips the build entirely.
   - **New commit** → clones upstream, builds the PDF, uploads it as an artifact,
     and (if `commit_pdf` is enabled) commits `scaling-book.pdf` + `.last_build_sha` back.

## The build pipeline (`build/`)

`build/build.sh` is the single source of truth (used by CI and locally):

1. `python bin/convert_to_single_md.py` (upstream) merges all chapters into one file.
2. `build/preprocess.py` applies **general** markdown fixups (see below).
3. Animated GIFs are flattened to PNG (LaTeX can't embed GIFs).
4. `pandoc` → LaTeX, then `xelatex` → PDF, with `build/preamble.tex` for math macros.

### Designed not to break when the book changes

A LaTeX build is strict: one unknown macro normally kills the whole PDF. To stay
robust against upstream edits, the pipeline has three layers:

- **Tolerant compile.** `xelatex` runs in `nonstopmode` and the build is considered
  successful as long as a PDF of reasonable length is produced (page-count gate).
  An unknown macro or glyph then degrades *one spot* instead of failing the job.
- **General preprocessing.** `preprocess.py` targets *classes* of MathJax-vs-LaTeX
  mismatches (delimiter spacing, `_` in `\text{}`, `\\[`, GIFs, a few Unicode
  glyphs) — patterns, never specific sentences.
- **Dependency-light preamble.** Only packages guaranteed present in the pinned
  toolchain; MathJax-only macros are defined with `\providecommand` so they never
  clash. A missing package would be fatal, so we avoid optional ones.

After each build the Action uploads the combined markdown + `xelatex` log as a
`build-logs` artifact and prints a warning summary, so quality regressions are
visible even when the build still succeeds.

## Configuration

- **Schedule:** edit the `cron` line in the workflow (`0 6 * * 1` = Mondays 06:00 UTC).
- **Force a rebuild / commit:** Actions → *Build Scaling Book PDF* → *Run workflow*,
  then toggle `force` / `commit_pdf`.
- **Pandoc version:** pinned via `PANDOC_VERSION` (older pandoc mishandles the math).

## First run

After pushing, run the workflow once manually. To let it commit the PDF, set
**Settings → Actions → General → Workflow permissions → Read and write**, then run
with `commit_pdf=true`.

## Building locally

Requires `pandoc` (3.10+), a LaTeX engine with `xelatex`, ImageMagick, and poppler:

```bash
git clone https://github.com/jax-ml/scaling-book.git upstream
bash build/build.sh upstream scaling-book.pdf
```

---

The book content is © its authors under the upstream repo's license. This repo
only automates building a PDF from it.
