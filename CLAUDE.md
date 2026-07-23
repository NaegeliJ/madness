# Madness — Vault Viewer Fork

A fork of [madness](https://github.com/DannyBen/madness) (Ruby, v1.3.1) turned
into a read-only web viewer for a directory of markdown notes. Notes are served
directly from disk on every request — no build step, no deploy.

The goal is that features work **out of the box**: no vault-side css/js files
and no configuration required. Everything is baked into the app.

## What the fork adds

- **Vault-wide wikilinks** — `[[Note]]` resolves to `Note.md` anywhere under the
  vault (same-directory first, then a base-name index), rendered as a correct
  relative link. Supports `[[Note|alias]]` and `[[Note#anchor]]`.
  Enable with `shortlinks: true` (upstream default is off).
  See `lib/madness/markdown_document.rb`, `document.rb`.
- **Callouts** — Obsidian-style `> [!NOTE] Title` blockquotes render as styled
  callouts; a `+`/`-` fold sign becomes a native `<details>`. Handled
  server-side in `lib/madness/rendering/redcarpet_custom.rb`; styled by the
  baked-in `app/public/css/fork.css`. Always on.
- **Link graph** — a graph button in the sidebar icon bar opens `/graph`, an
  interactive D3 force-directed view. Data is computed **in Ruby on demand**
  (`lib/madness/graph.rb`, `graph_metrics.rb`) from the vault's wikilinks — no
  Python, no separate service. Metrics: degree, betweenness, closeness and
  eigenvector centrality, plus articulation points and bridges (robustness) —
  validated to match NetworkX. The page (`app/public/graph.html`) has a left
  info sidebar (highlight chips + plain-language insights), a right settings
  panel (filters, display, forces, colour scheme), a bottom-right legend,
  directional hover colouring (in/out/both) and an OKF-aware node title.
  Toggle: `graph` (default on).
- **Floating TOC pane** — an auto-generated table of contents floats in the
  right rail on wide screens, built from the page's H2/H3 headers, in memory
  (never written to disk). Toggle: `toc_pane` (default on). Implements #182.
- **OKF frontmatter** — YAML frontmatter (per the Open Knowledge Format) is
  parsed out of the article body and shown as a metadata card in the right rail
  (`_meta_pane.slim`); the frontmatter `title` becomes the page title.
  See `lib/madness/document.rb`.
- **Mobile bottom nav** — on phones the sidebar is hidden, so Home / Search /
  Graph / Theme move into a fixed bottom bar (`_mobile_nav.slim`, safe-area
  aware).

## Layout

- `lib/madness/` — Ruby source (wikilinks, callouts, graph, TOC pane,
  frontmatter).
- `app/public/css/fork.css` — callout, right-rail (TOC + metadata) and
  mobile-nav styles (linked unconditionally in `layout.slim`).
- `app/public/graph.html`, `app/public/js/vendor/d3.min.js` — the graph page.
- `app/public/js/toc-pane.js` — TOC scroll-spy.
- `app/views/` — `_icon.slim`, `_nav.slim` (graph button), `_toc_pane.slim`,
  `_meta_pane.slim`, `_mobile_nav.slim`, `layout.slim`, `document.slim`.
- `sample/` — the upstream demo vault. Local-only demo notes and `.madness.yml`
  used for manual testing are git-ignored (see `.gitignore`).

## Run it

```
docker compose up web        # serves ./sample at http://localhost:3000
VAULT=/path/to/vault docker compose up web
```

The `Dockerfile` builds the gem from local source, so the image always includes
the fork's changes.

## Tests

`spec/madness/fork_spec.rb` (wikilinks + callouts) and `graph_spec.rb` (graph
metrics) cover the fork features with plain expectations. Run with
`bundle exec rspec`. Note: some upstream approval specs are sensitive to the
terminal/gem environment and only pass cleanly in CI.

## Roadmap ideas

Inspired by graph-analysis tooling (e.g. the obsidian-graph-analysis plugin),
possible future additions:

- Color/size nodes by a selectable metric (done for the four centralities).
- "Suggested connections" — surface likely missing links between related notes.
- Stale hub / bridge / authority reports (priority lists from the metrics).
- Community detection / clustering of the graph.
- Local semantic analysis (keywords, domains) — would require an LLM and is a
  larger, separate piece.
