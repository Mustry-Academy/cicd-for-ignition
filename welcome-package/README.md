# Welcome Package — CI/CD for Ignition

Source for the Mustry Academy welcome package handed to attendees of *CI/CD for Ignition* before Day 1.
Renders to a print-ready A4 PDF, styled to match the [mustrysolutions.com](https://mustrysolutions.com/) brand.

It lives in the `welcome-package/` folder of the course monorepo, [`cicd-for-ignition`](../README.md), next to
the [preflight](../preflight/) and the labs. It is instructor-facing: students get the PDF, not this folder.
Run `./build.sh` from here (or by path from anywhere); everything it reads and writes is relative to this folder.

## Files

| File                          | Purpose                                                                 |
| ----------------------------- | ----------------------------------------------------------------------- |
| `welcome-package.html`         | Source — content + styling, with `{{NAME}}` link placeholders           |
| `links.conf`                  | Discord invite, course repo and intake survey links                     |
| `build.sh`                    | Builds the PDF: QR codes, link fill-in, headless-Chrome render          |
| `assets/`                     | Logos and the instructor photo used in the page headers, cover and bio   |
| `welcome-package.pdf`          | Latest rendered output (not tracked by git)                             |
| `qr/`                         | Generated QR code SVGs (not tracked by git)                             |

## Dependencies

macOS via Homebrew:

```bash
brew install qrencode
```

Plus a Chromium-class browser (Chrome, Chromium, Edge, or Brave).

## Building the PDF

```bash
./build.sh
```

Writes `welcome-package.pdf` next to the HTML. Pass a path to override:

```bash
./build.sh /tmp/cohort-2026-package.pdf
```

The script auto-detects a Chromium-class browser. If yours lives somewhere unusual:

```bash
CHROME="/path/to/chrome" ./build.sh
```

### What `build.sh` does

1. Loads the links from `links.conf`.
2. Generates QR code SVGs into `qr/` for each URL in the `QR_TARGETS` array
   (Discord invite, course repo, intake survey, instructor LinkedIn).
3. Fills the `{{NAME}}` placeholders in a temporary copy of `welcome-package.html`.
   Fails loudly on any placeholder it doesn't know.
4. Renders that copy to PDF with headless Chrome (`@page` CSS handles A4), then deletes it.

## Spinning up a new cohort

Nothing in the package is tied to a specific cohort: dates and start times live in the
calendar invite, not here. Check the three links in `links.conf` and rebuild. The Discord
link is the general public invite: this repo is public, so never put a cohort invite that
grants a role in `links.conf`. Hand out cohort roles in Discord itself.

To add a new link:

1. Add `NEW_URL="…"` to `links.conf` and `NEW_URL` to `LINK_VARS` in `build.sh`.
2. Reference it as `{{NEW_URL}}` in `welcome-package.html`.
3. For a QR code, add `"name=$NEW_URL"` to `QR_TARGETS` and reference `qr/name.svg`.

## Brand notes

Anchored on [mustrysolutions.com](https://mustrysolutions.com/):

- **Display font** — Visby 800, served from `mustrysolutions.com/fonts/visby/`
- **Body font** — Baton Turbo 400, served from `mustrysolutions.com/fonts/baton/`
- **Mono** — IBM Plex Mono (no custom monospace in the Mustry brand)
- **Ink** — `#10172A` (dark-500)
- **Accent** — `#295EF6` (Mustry primary blue)
- **Surface tints** — `#eff4ff`, `#dbe4ff`, `#c6d4fd`

Because the fonts load over HTTPS from the live site, **the build needs internet access at render time**.
For a fully offline build, drop the four font files into a `fonts/` directory and swap the two
`@import` rules at the top of the `<style>` block in `welcome-package.html` for local
`@font-face` declarations.

## Editing the package

Structure of `welcome-package.html`:

1. **Cover** — `.cover` (dark navy, full-bleed, page-break-after)
2. **Seven content pages**, each opened by a `.page-head` band:
   - `01 · Welcome` — instructor note (signed) + course expectations
   - `02 · Your Instructor` — instructor bio, stats, photo + credentials
   - `03 · System Requirements` — install list + platform notes
   - `04 · Preflight` — fork the course repo, run `./course-setup.sh` (runs the preflight) + QR code
   - `05 · The Course` — typical four-day curriculum + a typical day schedule
   - `06 · Your Timeline` — pre-course timeline + checklist
   - `07 · Good to Know` — logistics + contact band with Discord QR

After editing, run `./build.sh` and open the PDF to check page breaks — most are forced via
`.section-break` divs, but Chrome can still re-flow a section if you add enough content.
The timeline + checklist combo on page 06 is the most sensitive; if the last checklist item
gets orphaned onto its own page, tighten the timeline-row or checklist-item padding in CSS.
