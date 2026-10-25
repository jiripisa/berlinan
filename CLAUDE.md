# Berlinan — project notes for Claude

## Website (`docs/`, GitHub Pages)

- **The site is bilingual.** Every change to `docs/index.html` or
  `docs/manual.html` must also go into `docs/cs/index.html` /
  `docs/cs/manual.html`, and the other way round. Shared styles and scripts
  live in `docs/assets/` (`site.css`, `manual.css`, `phasing.js`); texts that
  scripts show come from `data-*` attributes on the page.
