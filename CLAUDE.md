# Vault Viewer — Madness Fork

## Was wir bauen

Self-hosted Web-Viewer für den Memory Vault von Hermes (AI Agent).
Hermes schreibt Markdown-Files direkt ins Vault-Verzeichnis.
Dieser Viewer liest und zeigt sie sofort an — kein Build-Step, kein Deploy.

---

## Basis

- **Madness v1.3.1** — `github.com/DannyBen/madness`
- Ruby, Docker-ready, MIT-lizenziert, aktiv maintained
- Reads markdown directly from vault directory on every request
- Neue Files von Hermes erscheinen sofort beim nächsten Page-Load

---

## Architektur

```
Vault (Filesystem — Hermes schreibt hier)
         ↓
Madness (Ruby Server) — Notes, Search, Navigation
         ↓
/graph   — D3.js Graph-Seite (bewusst aufgerufen, nicht auf jeder Seite)
         ↑
graph-data.json — generiert von Python/NetworkX Script (on-demand)
```

---

## Änderungen die nötig sind

### 1. Konfiguration — `.madness.yml`

```yaml
shortlinks: true     # [[Wikilinks]] aktivieren
nav_tree: true       # rekursiver Sidebar-Baum
mermaid: true        # Mermaid Diagramme
sidebar: true
highlighter: true
auto_h1: true
```

### 2. Wikilinks — Vault-weite Auflösung (Ruby Patch)

**Problem:** Madness `shortlinks: true` löst `[[Note]]` nur im aktuellen
Verzeichnis auf → falsche Links bei Cross-Directory Wikilinks.

**Ziel:** `[[Note Name]]` → findet `Note Name.md` rekursiv im gesamten Vault
und gibt den korrekten relativen Pfad zurück.

**Wo:** `lib/madness/` — wahrscheinlich in der ShortLink-Klasse oder dem
Markdown-Renderer. Mit `grep -r "shortlink\|ShortLink\|\[\[" lib/` finden.

**Logik:**
1. `[[Note Name]]` extrahieren
2. Vault-Root rekursiv nach `Note Name.md` durchsuchen
3. Relativen Pfad von aktuellem File zu gefundenem File berechnen
4. Als normalen `[Note Name](../path/to/note)` Link rendern

### 3. Callout-Styling (CSS)

**Problem:** `> [!NOTE]`, `> [!WARNING]` etc. rendern als plain Blockquote.

Madness rendert `> [!NOTE]\n> Text` als:
```html
<blockquote><p>[!NOTE]<br>Text</p></blockquote>
```

**Lösung:** Kleines JS-Snippet beim Page-Load das:
1. Alle `<blockquote>` durchgeht
2. Prüft ob Inhalt mit `[!TYPE]` beginnt
3. CSS-Klassen setzt: `callout callout-note`, `callout callout-warning` etc.
4. `[!TYPE]` Text durch einen styled Header ersetzt

Dann CSS-Klassen für alle Obsidian Callout-Typen definieren:
`note`, `warning`, `danger`, `tip`, `info`, `success`, `question`, `bug`,
`example`, `quote`, `abstract`, `todo`, `failure`

**File:** `css/callouts.css` + `_callouts.js` im Vault-Root

### 4. Theme / UI (CSS)

**Stil:** Clean, minimal — inspiriert von Quartz, aber leichter.
Keine flashy Animationen. Robust und sauber.

Base-CSS holen mit:
```bash
docker run --rm dannyben/madness madness theme css > css/main.css
```

Oder ein eigenes vollständiges Theme:
```bash
docker run --rm dannyben/madness madness theme full my_theme
```

Wichtig für Mobile: Touch-Navigation, lesbare Schriftgrösse, kollapsierbare
Sidebar.

### 5. Graph-Seite (`/graph`)

**Konzept:** Separate HTML-Seite die bewusst aufgerufen wird.
Läuft nur wenn offen, verbraucht sonst null Ressourcen.

**Stack:**
- D3.js v7 Force-Directed Graph im Browser
- Python + NetworkX generiert `graph-data.json` (on-demand Script)
- Madness serviert `graph.html` und `graph-data.json` als statische Files

**graph-data.json Format:**
```json
{
  "generated_at": "2025-01-01T00:00:00",
  "stats": {
    "node_count": 637,
    "edge_count": 1240,
    "is_connected": false,
    "articulation_point_count": 12
  },
  "nodes": [
    {
      "id": "memory/person-x",
      "title": "Person X",
      "path": "memory/person-x.md",
      "eigenvector": 0.42,
      "betweenness": 0.18,
      "degree": 12,
      "is_articulation_point": true
    }
  ],
  "links": [
    { "source": "memory/person-x", "target": "memory/event-y" }
  ],
  "bridges": [
    { "source": "memory/person-x", "target": "memory/event-y" }
  ]
}
```

**Graph-Visualisierung:**
- Node-Grösse = Eigenvektorzentralität
- Node-Farbe = Betweenness (Heatmap cool→warm)
- Roter Ring = Artikulationspunkt
- Gestrichelte Kante = Bridge
- Klick auf Node → navigiert zur Note im Viewer
- Tooltip zeigt Metriken beim Hover
- Zoom + Pan mit Maus/Touch

**Python Generator (`scripts/generate_graph.py`):**
```python
import networkx as nx
import json, os, re

# 1. Walk vault, parse [[wikilinks]] aus jedem .md File
# 2. Build nx.DiGraph (gerichtet)
# 3. Compute:
#    - nx.eigenvector_centrality(G)
#    - nx.betweenness_centrality(G)
#    - list(nx.articulation_points(G.to_undirected()))
#    - list(nx.bridges(G.to_undirected()))
#    - G.degree()
# 4. Output → graph-data.json ins Vault-Root
```

---

## File-Struktur im Vault-Root

```
vault/
├── .madness.yml              ← Konfiguration
├── css/
│   ├── main.css              ← Komplettes Theme-Override
│   └── callouts.css          ← Obsidian Callout Styles
├── graph.html                ← Graph-Seite (statisch, von Madness serviert)
├── graph-data.json           ← Generiert vom Python-Script
└── scripts/
    └── generate_graph.py     ← NetworkX Graph-Generator
```

---

## Docker Setup

```yaml
# docker-compose.yml
services:
  vault:
    image: dannyben/madness
    volumes:
      - /pfad/zum/vault:/docs
    ports:
      - "3000:3000"
    command: server
    restart: unless-stopped
```

---

## Constraints & Entscheidungen

| Punkt | Entscheidung |
|-------|-------------|
| Read-only | User liest nur, Hermes schreibt |
| Kein Build-Step | Files sofort sichtbar nach Write |
| Kein Node.js/npm | Madness läuft in eigenem Docker Image |
| Graph on-demand | `/graph` Seite, nicht auf jeder Note-Seite |
| Graph-Metriken | Python/NetworkX (reifer als Go-Alternativen) |
| Sprache Backend | Ruby (Madness), kein Rewrite |
| Sprache Graph | Python (NetworkX), D3.js (Visualisierung) |
| Mobile | CSS-Priorität, Touch-Navigation |

---

## NetworkX Metriken Referenz

```python
G = nx.DiGraph()  # gerichtet (Wikilinks haben Richtung)
U = G.to_undirected()

nx.eigenvector_centrality(G)         # Wichtigkeit eines Nodes
nx.betweenness_centrality(G)         # Brückenknoten
list(nx.articulation_points(U))      # Single Points of Failure
list(nx.bridges(U))                  # Kanten die Graph zerschneiden
dict(G.degree())                     # Verbindungsanzahl pro Node
nx.is_connected(U)                   # Gesamtkonnektivität
nx.number_connected_components(U)    # Anzahl isolierter Cluster
```

**Rhizom-Analyse:** Ziel ist niedriger Anteil an Artikulationspunkten und
keine Bridges — das bedeutet ein gut vernetztes, robustes Netzwerk ohne
Single Points of Failure.

---

## Reihenfolge

1. Madness lokal testen mit `.madness.yml` Config
2. Wikilink-Patch implementieren (Ruby)
3. Callout CSS + JS schreiben
4. Theme/UI anpassen
5. `generate_graph.py` schreiben und testen
6. `graph.html` mit D3.js bauen
7. Docker-Setup finalisieren
