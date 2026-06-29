# FIFA World Cup 2026 Bracket — Design Spec

**Date:** 2026-06-29  
**Status:** Approved

## Summary

A locally-hosted web app that replaces a physical bracket poster for the FIFA World Cup 2026. Displays the knockout stage (Round of 32 onward) with draggable team chips and droppable bracket slots. State is shared across all devices on the home network via server-side persistence.

---

## Architecture

Single Node.js/Express container serving:

- Static frontend (`index.html`, inline CSS/JS)
- `GET /api/bracket` — returns current bracket state
- `POST /api/bracket` — saves new bracket state

State stored in `/data/bracket.json` on a PersistentVolumeClaim. No database required.

---

## Tournament Structure

FIFA World Cup 2026 uses 48 teams across 12 groups of 4. The top 2 from each group + 8 best third-place teams advance to the knockout stage (32 teams total).

**Knockout rounds displayed:**

- Round of 32 (16 matches)
- Round of 16 (8 matches)
- Quarter-finals (4 matches)
- Semi-finals (2 matches)
- 3rd Place match (1 match)
- Final (1 match)

---

## Data Model

`/data/bracket.json`:

```json
{
  "r32":   [["Team A", "Team B"], ...],  // 16 pairs
  "r16":   [["", ""], ...],              // 8 pairs
  "qf":    [["", ""], ...],              // 4 pairs
  "sf":    [["", ""], ...],              // 2 pairs
  "third": ["", ""],                     // 1 pair
  "final": ["", ""]                      // 1 pair
}
```

Empty string = unfilled slot. The 48 team names are baked into the frontend JS (not stored server-side).

---

## UI Design

**Two zones:**

### 1. Team Pool (top panel)

- All 48 teams displayed as draggable chips (flag emoji + country name)
- Chips are copyable (not consumed on drop) — the same team appears in the pool regardless of where it's been placed in the bracket
- Grouped by World Cup group (A–L) for easy reference

### 2. Bracket (main area)

- Classic left-right tournament tree converging at the center Final
- Left half: 8 matches in R32 → 4 in R16 → 2 QF → 1 SF → Final
- Right half: mirrors the left
- 3rd place match displayed below the Final
- Champion highlighted at the Final winner slot

**Interactions:**

- Drag a chip from the pool and drop it into a bracket slot to fill it
- Click a filled slot to clear it (correction flow)
- State auto-saves to the server after each change (no manual save button)
- On page load, state is fetched from `/api/bracket` and all slots are restored

---

## Teams (All 48, by Group)

| Group | Teams                                              |
| ----- | -------------------------------------------------- |
| A     | Mexico, South Africa, South Korea, Czech Republic  |
| B     | Canada, Switzerland, Qatar, Bosnia and Herzegovina |
| C     | Brazil, Morocco, Scotland, Haiti                   |
| D     | United States, Paraguay, Australia, Turkey         |
| E     | Germany, Curaçao, Costa Rica, Ecuador              |
| F     | Netherlands, Japan, Tunisia, Sweden                |
| G     | Belgium, Egypt, Iran, New Zealand                  |
| H     | Spain, Cape Verde, Saudi Arabia, Uruguay           |
| I     | France, Senegal, Norway, Iraq                      |
| J     | Argentina, Algeria, Austria, Jordan                |
| K     | Portugal, Colombia, Uzbekistan, DR Congo           |
| L     | England, Croatia, Ghana, Panama                    |

---

## Deployment

**Namespace:** `games`  
**Path:** `kubernetes/apps/games/fifa-bracket/`  
**Route:** `fifa-bracket.dovis.me` (internal only, via `envoy-internal`)  
**Image:** `ghcr.io/chr1sd/fifa-bracket:latest`

**Files:**

- `ks.yaml` — Flux Kustomization
- `app/helmrelease.yaml` — app-template HelmRelease
- `Dockerfile` — node:22-alpine, copies server.js + public/
- `server.js` — Express app
- `public/index.html` — full bracket UI (HTML + inline CSS + JS)

**Resources:** 10m CPU request, 128Mi memory limit  
**Storage:** 1Gi PVC at `/data` for bracket.json  
**Security:** read/write root filesystem (needed to write bracket.json via mounted PVC)

---

## Out of Scope

- Group stage display
- Score entry / automatic standings calculation
- Authentication
- External (internet) access
- Real-time push updates (page refresh fetches latest state)
