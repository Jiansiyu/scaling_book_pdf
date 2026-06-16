# scaling-book-pdf

[![Build Scaling Book PDF](https://github.com/Jiansiyu/scaling_book_pdf/actions/workflows/build-pdf.yml/badge.svg)](https://github.com/Jiansiyu/scaling_book_pdf/actions/workflows/build-pdf.yml)

A PDF build of **How to Scale Your Model**, kept in sync with the upstream book.

> **About the book.** [*How to Scale Your Model*](https://jax-ml.github.io/scaling-book/)
> is an open book by Jacob Austin, Sholto Douglas, and colleagues at **Google DeepMind**
> ([source repo](https://github.com/jax-ml/scaling-book)). It explains how LLMs run at
> scale on TPUs — rooflines, sharding, the transformer math, and how to choose
> parallelism strategies for training and inference that avoid communication bottlenecks.
> The original is a website; this repo turns it into a single PDF (see
> [`scaling-book.pdf`](scaling-book.pdf)).

## How it works

A GitHub Action ([`.github/workflows/build-pdf.yml`](.github/workflows/build-pdf.yml)) runs
**weekly on Monday** (and on-demand): it checks upstream `main`, and **only rebuilds when
there's a new commit** (tracked via `.last_build_sha`). On a rebuild it clones upstream,
runs [`build/build.sh`](build/build.sh) (merge chapters → preprocess → flatten GIFs →
`pandoc` + `xelatex`), uploads the PDF as an artifact, and commits it back.

### Built to survive upstream changes

LaTeX normally fails on a single unknown macro. To stay robust, the pipeline (1) compiles
in `nonstopmode` and succeeds as long as a PDF of reasonable length is produced, (2)
preprocesses *classes* of MathJax↔LaTeX mismatches rather than specific text, and (3) uses
a dependency-light preamble with `\providecommand` macros. A worst case degrades one spot
instead of breaking the build; each run also uploads the log + combined markdown for review.

## Build locally

Requires `pandoc` (3.10+), `xelatex`, ImageMagick, and poppler:

```bash
git clone https://github.com/jax-ml/scaling-book.git upstream
bash build/build.sh upstream scaling-book.pdf
```

## Configuration

- **Schedule:** the `cron` line in the workflow (`0 6 * * 1` = Mondays 06:00 UTC).
- **Manual run / force / commit:** Actions → *Build Scaling Book PDF* → *Run workflow*.

---

Book content © its authors under the upstream repo's license. This repo only automates
building the PDF.
