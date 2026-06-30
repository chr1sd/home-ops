# FIFA World Cup 2026 Bracket — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy a shared knockout-bracket tracker for the 2026 FIFA World Cup, hosted at `fifa-bracket.dovis.me` in the home Kubernetes cluster.

**Architecture:** Single Node.js/Express container serves a static SPA and two API endpoints. Bracket state is stored in `/data/bracket.json` on a PersistentVolumeClaim. Deployed via Flux GitOps in the `games` namespace using the `app-template` helm chart.

**Tech Stack:** Node.js 22, Express 4, HTML5 Drag and Drop API (no external UI libraries), node:test + supertest, app-template v5.0.1 (bjw-s-labs), Ceph block storage.

## Global Constraints

- Image: `ghcr.io/chr1sd/fifa-bracket:latest`
- Namespace: `games`
- Route hostname: `fifa-bracket.dovis.me` via `envoy-internal` gateway
- Storage class: `ceph-block`, `ReadWriteOnce`, `1Gi`
- App-template version: `5.0.1` at `oci://ghcr.io/bjw-s-labs/helm/app-template`
- Node.js base image: `node:22-alpine`
- Data file path inside container: `/data/bracket.json`
- `"type": "module"` in package.json (ES modules throughout)
- Port: `3000`

---

## File Map

```
apps/fifa-bracket/
  package.json          — express dep + supertest dev dep, "type": "module"
  server.js             — Express app: static files + GET/POST /api/bracket
  server.test.js        — node:test integration tests using supertest
  Dockerfile            — node:22-alpine, non-root user, COPY server.js + public/
  public/
    index.html          — complete SPA: dark-theme bracket UI, pool of 48 teams,
                          drag-and-drop, auto-save, state restored on load

kubernetes/apps/games/fifa-bracket/
  ks.yaml               — Flux Kustomization pointing at ./app
  app/
    kustomization.yaml  — lists helmrelease.yaml + ocirepository.yaml + pvc.yaml
    ocirepository.yaml  — OCIRepository: app-template v5.0.1 named fifa-bracket
    helmrelease.yaml    — HelmRelease using the fifa-bracket OCIRepository
    pvc.yaml            — 1Gi ceph-block PVC named fifa-bracket
```

**Modify:** `kubernetes/apps/games/kustomization.yaml` — add `- ./fifa-bracket/ks.yaml`

---

### Task 1: Backend server with tests

**Files:**

- Create: `apps/fifa-bracket/package.json`
- Create: `apps/fifa-bracket/server.js`
- Create: `apps/fifa-bracket/server.test.js`

**Interfaces:**

- Produces: `GET /api/bracket → BracketState`; `POST /api/bracket → {ok: true}`

Where `BracketState` is:

```json
{
  "r32": [["", ""], ...],   // 16 pairs
  "r16": [["", ""], ...],   // 8 pairs
  "qf":  [["", ""], ...],   // 4 pairs
  "sf":  [["", ""], ...],   // 2 pairs
  "third": ["", ""],
  "final": ["", ""]
}
```

- [ ] **Step 1: Write the failing tests**

Create `apps/fifa-bracket/server.test.js`:

```javascript
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import supertest from "supertest";
import fs from "node:fs";
import { createApp } from "./server.js";

const TMP = "/tmp/bracket-test.json";
let request;

before(() => {
    if (fs.existsSync(TMP)) fs.unlinkSync(TMP);
    request = supertest(createApp(TMP));
});

after(() => {
    if (fs.existsSync(TMP)) fs.unlinkSync(TMP);
});

test("GET /api/bracket returns default state when no file exists", async () => {
    const res = await request.get("/api/bracket").expect(200);
    assert.equal(Array.isArray(res.body.r32), true);
    assert.equal(res.body.r32.length, 16);
    assert.deepEqual(res.body.r32[0], ["", ""]);
    assert.deepEqual(res.body.final, ["", ""]);
    assert.deepEqual(res.body.third, ["", ""]);
});

test("POST /api/bracket saves state and returns ok", async () => {
    const state = {
        r32: Array.from({ length: 16 }, (_, i) => [`TeamA${i}`, `TeamB${i}`]),
        r16: Array.from({ length: 8 }, () => ["", ""]),
        qf: Array.from({ length: 4 }, () => ["", ""]),
        sf: Array.from({ length: 2 }, () => ["", ""]),
        third: ["", ""],
        final: ["", ""],
    };
    await request.post("/api/bracket").send(state).expect(200, { ok: true });
});

test("GET /api/bracket returns saved state after POST", async () => {
    const res = await request.get("/api/bracket").expect(200);
    assert.equal(res.body.r32[0][0], "TeamA0");
    assert.equal(res.body.r32[15][1], "TeamB15");
});
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd apps/fifa-bracket
npm install   # will fail because package.json doesn't exist yet
```

Expected: `ENOENT: no such file or directory, open 'apps/fifa-bracket/package.json'`

- [ ] **Step 3: Create `apps/fifa-bracket/package.json`**

```json
{
    "name": "fifa-bracket",
    "version": "1.0.0",
    "type": "module",
    "scripts": {
        "start": "node server.js",
        "test": "node --test server.test.js"
    },
    "dependencies": {
        "express": "^4.21.0"
    },
    "devDependencies": {
        "supertest": "^7.0.0"
    }
}
```

- [ ] **Step 4: Install dependencies**

```bash
cd apps/fifa-bracket && npm install
```

Expected: `node_modules/` created with express and supertest.

- [ ] **Step 5: Run tests — verify they fail with meaningful error**

```bash
cd apps/fifa-bracket && npm test 2>&1 | head -20
```

Expected: `Error [ERR_MODULE_NOT_FOUND]: Cannot find module './server.js'`

- [ ] **Step 6: Create `apps/fifa-bracket/server.js`**

```javascript
import express from "express";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const DEFAULT_BRACKET = {
    r32: Array.from({ length: 16 }, () => ["", ""]),
    r16: Array.from({ length: 8 }, () => ["", ""]),
    qf: Array.from({ length: 4 }, () => ["", ""]),
    sf: Array.from({ length: 2 }, () => ["", ""]),
    third: ["", ""],
    final: ["", ""],
};

export function createApp(dataFile) {
    const app = express();
    app.use(express.json());
    app.use(express.static(path.join(__dirname, "public")));

    app.get("/api/bracket", (_req, res) => {
        try {
            res.json(JSON.parse(fs.readFileSync(dataFile, "utf8")));
        } catch {
            res.json(structuredClone(DEFAULT_BRACKET));
        }
    });

    app.post("/api/bracket", (req, res) => {
        fs.mkdirSync(path.dirname(dataFile), { recursive: true });
        fs.writeFileSync(dataFile, JSON.stringify(req.body));
        res.json({ ok: true });
    });

    return app;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
    const DATA_FILE = process.env.DATA_FILE || "/data/bracket.json";
    const PORT = Number(process.env.PORT) || 3000;
    createApp(DATA_FILE).listen(PORT, () => console.log(`fifa-bracket listening on :${PORT}`));
}
```

- [ ] **Step 7: Run tests — verify all pass**

```bash
cd apps/fifa-bracket && npm test
```

Expected output:

```
▶ GET /api/bracket returns default state when no file exists
  ✔ GET /api/bracket returns default state when no file exists (Xms)
▶ POST /api/bracket saves state and returns ok
  ✔ POST /api/bracket saves state and returns ok (Xms)
▶ GET /api/bracket returns saved state after POST
  ✔ GET /api/bracket returns saved state after POST (Xms)
ℹ tests 3
ℹ pass 3
ℹ fail 0
```

- [ ] **Step 8: Commit**

```bash
git add apps/fifa-bracket/package.json apps/fifa-bracket/package-lock.json \
        apps/fifa-bracket/server.js apps/fifa-bracket/server.test.js
git commit -m "feat(fifa-bracket): add Express server with bracket state API"
```

---

### Task 2: Frontend SPA

**Files:**

- Create: `apps/fifa-bracket/public/index.html`

**Interfaces:**

- Consumes: `GET /api/bracket` → `BracketState` (from Task 1)
- Consumes: `POST /api/bracket` with `BracketState` body (from Task 1)

- [ ] **Step 1: Create `apps/fifa-bracket/public/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>FIFA World Cup 2026</title>
        <style>
            :root {
                --bg: #071422;
                --surface: #0e2038;
                --surface2: #132840;
                --border: #1e3a5a;
                --accent: #c9a227;
                --accent-dim: rgba(201, 162, 39, 0.15);
                --text: #dde6f0;
                --muted: #6a88a8;
                --slot-empty: #112233;
                --slot-filled: #0d3566;
                --slot-border: #1e4080;
                --chip-bg: #0f2a40;
                --chip-border: #2a4a6a;
                --chip-hover: #1a3a58;
                --drag-over: rgba(201, 162, 39, 0.25);
            }

            * {
                box-sizing: border-box;
                margin: 0;
                padding: 0;
            }

            body {
                background: var(--bg);
                color: var(--text);
                font-family: "Segoe UI", system-ui, sans-serif;
                font-size: 13px;
                min-height: 100vh;
            }

            /* ── Header ── */
            header {
                display: flex;
                align-items: center;
                justify-content: center;
                gap: 16px;
                padding: 16px 24px;
                border-bottom: 1px solid var(--border);
                background: var(--surface);
            }

            header h1 {
                font-size: 1.4rem;
                font-weight: 700;
                letter-spacing: 3px;
                text-transform: uppercase;
                color: var(--accent);
            }

            header p {
                color: var(--muted);
                font-size: 0.75rem;
            }

            /* ── Team Pool ── */
            #pool {
                padding: 12px 20px;
                border-bottom: 2px solid var(--border);
                background: var(--surface);
            }

            #pool-heading {
                font-size: 0.65rem;
                text-transform: uppercase;
                letter-spacing: 2px;
                color: var(--muted);
                margin-bottom: 10px;
            }

            .pool-groups {
                display: flex;
                flex-wrap: wrap;
                gap: 10px;
            }

            .pool-group {
                display: flex;
                flex-direction: column;
                gap: 4px;
            }

            .pool-group-label {
                font-size: 0.6rem;
                text-transform: uppercase;
                letter-spacing: 1px;
                color: var(--accent);
            }

            .pool-chips {
                display: flex;
                flex-wrap: wrap;
                gap: 3px;
            }

            .chip {
                background: var(--chip-bg);
                border: 1px solid var(--chip-border);
                border-radius: 5px;
                padding: 3px 8px;
                font-size: 0.75rem;
                cursor: grab;
                user-select: none;
                white-space: nowrap;
                transition:
                    background 0.12s,
                    border-color 0.12s;
            }

            .chip:hover {
                background: var(--chip-hover);
                border-color: var(--accent);
            }
            .chip.dragging {
                opacity: 0.35;
            }

            /* ── Bracket ── */
            #bracket-scroll {
                overflow-x: auto;
                padding: 28px 20px 48px;
            }

            #bracket {
                display: flex;
                align-items: center;
                min-width: 1360px;
                gap: 0;
            }

            .half {
                display: flex;
                flex: 1;
                align-items: center;
            }

            /* ── Round column ── */
            .round-col {
                display: flex;
                flex-direction: column;
                min-width: 150px;
                flex: 1;
            }

            .round-heading {
                font-size: 0.6rem;
                text-transform: uppercase;
                letter-spacing: 1.5px;
                color: var(--muted);
                text-align: center;
                padding-bottom: 8px;
                white-space: nowrap;
            }

            .round-matches {
                display: flex;
                flex-direction: column;
                flex: 1;
                justify-content: space-around;
            }

            /* ── Match ── */
            .match {
                display: flex;
                flex-direction: column;
                margin: 3px 6px;
            }

            /* ── Slot ── */
            .slot {
                height: 34px;
                padding: 0 10px;
                display: flex;
                align-items: center;
                background: var(--slot-empty);
                border: 1px solid var(--border);
                font-size: 0.78rem;
                cursor: pointer;
                transition:
                    background 0.12s,
                    border-color 0.12s;
                overflow: hidden;
                text-overflow: ellipsis;
                white-space: nowrap;
            }

            .slot:first-child {
                border-radius: 4px 4px 0 0;
                border-bottom: none;
            }
            .slot:last-child {
                border-radius: 0 0 4px 4px;
            }

            .slot.filled {
                background: var(--slot-filled);
                border-color: var(--slot-border);
            }

            .slot.final-slot {
                background: var(--accent-dim);
                border-color: var(--accent);
                font-weight: 600;
            }

            .slot.dragover {
                background: var(--drag-over);
                border-color: var(--accent);
            }

            .slot:hover {
                border-color: #3a6aac;
            }
            .slot.filled:hover {
                border-color: var(--accent);
            }

            /* ── Center column ── */
            .center-col {
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 0 20px;
                gap: 28px;
            }

            .center-section {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 4px;
            }

            .center-heading {
                font-size: 0.65rem;
                text-transform: uppercase;
                letter-spacing: 2px;
                text-align: center;
                margin-bottom: 6px;
            }

            .center-heading.final {
                color: var(--accent);
                font-size: 0.85rem;
            }
            .center-heading.third {
                color: var(--muted);
            }

            .center-section .match {
                margin: 0;
            }
            .center-section .slot {
                min-width: 160px;
            }

            /* ── Champion banner ── */
            #champion {
                display: none;
                text-align: center;
                padding: 10px 20px;
                background: var(--accent-dim);
                border-top: 1px solid var(--accent);
                border-bottom: 1px solid var(--accent);
            }

            #champion.visible {
                display: block;
            }

            #champion-name {
                font-size: 1.1rem;
                font-weight: 700;
                color: var(--accent);
                letter-spacing: 2px;
            }

            #champion-label {
                font-size: 0.65rem;
                text-transform: uppercase;
                letter-spacing: 2px;
                color: var(--muted);
            }
        </style>
    </head>
    <body>
        <header>
            <div>
                <h1>⚽ FIFA World Cup 2026</h1>
                <p>Drag teams into the bracket &nbsp;·&nbsp; Click a filled slot to clear it</p>
            </div>
        </header>

        <div id="champion">
            <div id="champion-label">World Champion</div>
            <div id="champion-name"></div>
        </div>

        <div id="pool">
            <div id="pool-heading">Teams — drag into bracket</div>
            <div class="pool-groups" id="pool-groups"></div>
        </div>

        <div id="bracket-scroll">
            <div id="bracket"></div>
        </div>

        <script>
            const GROUPS = {
                A: ["🇲🇽 Mexico", "🇿🇦 South Africa", "🇰🇷 South Korea", "🇨🇿 Czech Republic"],
                B: ["🇨🇦 Canada", "🇨🇭 Switzerland", "🇶🇦 Qatar", "🇧🇦 Bosnia & Herz."],
                C: ["🇧🇷 Brazil", "🇲🇦 Morocco", "🏴󠁧󠁢󠁳󠁣󠁴󠁿 Scotland", "🇭🇹 Haiti"],
                D: ["🇺🇸 United States", "🇵🇾 Paraguay", "🇦🇺 Australia", "🇹🇷 Turkey"],
                E: ["🇩🇪 Germany", "🇨🇼 Curaçao", "🇨🇷 Costa Rica", "🇪🇨 Ecuador"],
                F: ["🇳🇱 Netherlands", "🇯🇵 Japan", "🇹🇳 Tunisia", "🇸🇪 Sweden"],
                G: ["🇧🇪 Belgium", "🇪🇬 Egypt", "🇮🇷 Iran", "🇳🇿 New Zealand"],
                H: ["🇪🇸 Spain", "🇨🇻 Cape Verde", "🇸🇦 Saudi Arabia", "🇺🇾 Uruguay"],
                I: ["🇫🇷 France", "🇸🇳 Senegal", "🇳🇴 Norway", "🇮🇶 Iraq"],
                J: ["🇦🇷 Argentina", "🇩🇿 Algeria", "🇦🇹 Austria", "🇯🇴 Jordan"],
                K: ["🇵🇹 Portugal", "🇨🇴 Colombia", "🇺🇿 Uzbekistan", "🇨🇩 DR Congo"],
                L: ["🏴󠁧󠁢󠁥󠁮󠁧󠁿 England", "🇭🇷 Croatia", "🇬🇭 Ghana", "🇵🇦 Panama"],
            };

            let bracket = null;

            // ── API ──────────────────────────────────────────────
            async function load() {
                const res = await fetch("/api/bracket");
                bracket = await res.json();
                renderPool();
                renderBracket();
                updateChampion();
            }

            async function save() {
                await fetch("/api/bracket", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(bracket),
                });
            }

            // ── State helpers ─────────────────────────────────────
            function getVal(round, matchIdx, slotIdx) {
                if (round === "final" || round === "third") return bracket[round][slotIdx];
                return bracket[round][matchIdx][slotIdx];
            }

            function setVal(round, matchIdx, slotIdx, value) {
                if (round === "final" || round === "third") {
                    bracket[round][slotIdx] = value;
                } else {
                    bracket[round][matchIdx][slotIdx] = value;
                }
            }

            function updateChampion() {
                const [t1, t2] = bracket.final;
                const el = document.getElementById("champion");
                if (t1 && t2) {
                    document.getElementById("champion-label").textContent = "🏆 World Cup Final";
                    document.getElementById("champion-name").textContent = `${t1}  vs  ${t2}`;
                    el.classList.add("visible");
                } else {
                    el.classList.remove("visible");
                }
            }

            // ── Slot element ──────────────────────────────────────
            function makeSlot(round, matchIdx, slotIdx, isFinalStyle) {
                const slot = document.createElement("div");
                slot.className = "slot" + (isFinalStyle ? " final-slot" : "");

                const val = getVal(round, matchIdx, slotIdx);
                if (val) {
                    slot.textContent = val;
                    slot.classList.add("filled");
                }

                slot.addEventListener("dragover", (e) => {
                    e.preventDefault();
                    slot.classList.add("dragover");
                });
                slot.addEventListener("dragleave", () => slot.classList.remove("dragover"));
                slot.addEventListener("drop", (e) => {
                    e.preventDefault();
                    slot.classList.remove("dragover");
                    const team = e.dataTransfer.getData("text/plain");
                    if (!team) return;
                    setVal(round, matchIdx, slotIdx, team);
                    slot.textContent = team;
                    slot.classList.add("filled");
                    if (round === "final") updateChampion();
                    save();
                });
                slot.addEventListener("click", () => {
                    if (!slot.classList.contains("filled")) return;
                    setVal(round, matchIdx, slotIdx, "");
                    slot.textContent = "";
                    slot.classList.remove("filled");
                    if (round === "final") updateChampion();
                    save();
                });

                return slot;
            }

            function makeMatch(round, matchIdx, isFinalStyle = false) {
                const div = document.createElement("div");
                div.className = "match";
                div.appendChild(makeSlot(round, matchIdx, 0, isFinalStyle));
                div.appendChild(makeSlot(round, matchIdx, 1, isFinalStyle));
                return div;
            }

            function makeRoundCol(heading, round, matchIndices, isFinalStyle = false) {
                const col = document.createElement("div");
                col.className = "round-col";
                const h = document.createElement("div");
                h.className = "round-heading";
                h.textContent = heading;
                col.appendChild(h);
                const matches = document.createElement("div");
                matches.className = "round-matches";
                for (const idx of matchIndices) {
                    matches.appendChild(makeMatch(round, idx, isFinalStyle));
                }
                col.appendChild(matches);
                return col;
            }

            // ── Pool ──────────────────────────────────────────────
            function renderPool() {
                const container = document.getElementById("pool-groups");
                container.innerHTML = "";
                for (const [name, teams] of Object.entries(GROUPS)) {
                    const groupEl = document.createElement("div");
                    groupEl.className = "pool-group";
                    const label = document.createElement("div");
                    label.className = "pool-group-label";
                    label.textContent = `Group ${name}`;
                    groupEl.appendChild(label);
                    const chips = document.createElement("div");
                    chips.className = "pool-chips";
                    for (const team of teams) {
                        const chip = document.createElement("div");
                        chip.className = "chip";
                        chip.textContent = team;
                        chip.draggable = true;
                        chip.addEventListener("dragstart", (e) => {
                            e.dataTransfer.setData("text/plain", team);
                            e.dataTransfer.effectAllowed = "copy";
                            chip.classList.add("dragging");
                        });
                        chip.addEventListener("dragend", () => chip.classList.remove("dragging"));
                        chips.appendChild(chip);
                    }
                    groupEl.appendChild(chips);
                    container.appendChild(groupEl);
                }
            }

            // ── Bracket ───────────────────────────────────────────
            function renderBracket() {
                const root = document.getElementById("bracket");
                root.innerHTML = "";

                // Left half: R32→R16→QF→SF (outer to inner)
                const leftHalf = document.createElement("div");
                leftHalf.className = "half";
                leftHalf.appendChild(makeRoundCol("Round of 32", "r32", [0, 1, 2, 3, 4, 5, 6, 7]));
                leftHalf.appendChild(makeRoundCol("Round of 16", "r16", [0, 1, 2, 3]));
                leftHalf.appendChild(makeRoundCol("Quarterfinals", "qf", [0, 1]));
                leftHalf.appendChild(makeRoundCol("Semifinals", "sf", [0]));
                root.appendChild(leftHalf);

                // Center: Final + 3rd place
                const center = document.createElement("div");
                center.className = "center-col";

                const finalSec = document.createElement("div");
                finalSec.className = "center-section";
                const finalH = document.createElement("div");
                finalH.className = "center-heading final";
                finalH.textContent = "⚽ Final";
                finalSec.appendChild(finalH);
                finalSec.appendChild(makeMatch("final", 0, true));
                center.appendChild(finalSec);

                const thirdSec = document.createElement("div");
                thirdSec.className = "center-section";
                const thirdH = document.createElement("div");
                thirdH.className = "center-heading third";
                thirdH.textContent = "3rd Place";
                thirdSec.appendChild(thirdH);
                thirdSec.appendChild(makeMatch("third", 0, false));
                center.appendChild(thirdSec);

                root.appendChild(center);

                // Right half: SF→QF→R16→R32 (inner to outer)
                const rightHalf = document.createElement("div");
                rightHalf.className = "half";
                rightHalf.appendChild(makeRoundCol("Semifinals", "sf", [1]));
                rightHalf.appendChild(makeRoundCol("Quarterfinals", "qf", [2, 3]));
                rightHalf.appendChild(makeRoundCol("Round of 16", "r16", [4, 5, 6, 7]));
                rightHalf.appendChild(
                    makeRoundCol("Round of 32", "r32", [8, 9, 10, 11, 12, 13, 14, 15]),
                );
                root.appendChild(rightHalf);
            }

            load();
        </script>
    </body>
</html>
```

- [ ] **Step 2: Start the server locally and verify the UI**

```bash
cd apps/fifa-bracket
DATA_FILE=/tmp/bracket-local.json node server.js
```

Open `http://localhost:3000` in a browser. Verify:

- Header shows "FIFA World Cup 2026"
- Team pool shows all 48 teams grouped by A–L with flag emojis
- Bracket shows 9 columns: R32 | R16 | QF | SF | Final | SF | QF | R16 | R32
- All slots are empty (dark background)
- No console errors

- [ ] **Step 3: Test drag-and-drop and persistence**

With the server still running:

1. Drag "🇧🇷 Brazil" from the pool into the first slot of the R32 left column
2. Verify the slot fills with "🇧🇷 Brazil"
3. Drag "🇦🇷 Argentina" into the second slot of the same match
4. Refresh the page — both teams should still be in their slots (state was saved)
5. Click "🇧🇷 Brazil" in the slot — verify it clears
6. Drag a team into the Final slot — verify the champion banner appears at the top

- [ ] **Step 4: Stop the server and commit**

```bash
# Stop server with Ctrl+C, then:
git add apps/fifa-bracket/public/index.html
git commit -m "feat(fifa-bracket): add bracket SPA with drag-and-drop"
```

---

### Task 3: Dockerfile

**Files:**

- Create: `apps/fifa-bracket/Dockerfile`
- Create: `apps/fifa-bracket/.dockerignore`

**Interfaces:**

- Consumes: `server.js`, `public/index.html`, `package.json`, `package-lock.json`
- Produces: image `ghcr.io/chr1sd/fifa-bracket:latest`

- [ ] **Step 1: Create `apps/fifa-bracket/.dockerignore`**

```
node_modules
*.test.js
.git
```

- [ ] **Step 2: Create `apps/fifa-bracket/Dockerfile`**

```dockerfile
FROM node:22-alpine AS base
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.js ./
COPY public ./public

EXPOSE 3000
USER node
CMD ["node", "server.js"]
```

- [ ] **Step 3: Build and smoke-test the image locally**

```bash
cd apps/fifa-bracket
docker build -t ghcr.io/chr1sd/fifa-bracket:latest .
docker run --rm -p 3000:3000 -e DATA_FILE=/tmp/b.json ghcr.io/chr1sd/fifa-bracket:latest
```

In another terminal:

```bash
curl -s http://localhost:3000/api/bracket | python3 -m json.tool | head -10
```

Expected: JSON with `r32`, `r16`, `qf`, `sf`, `third`, `final` keys.

- [ ] **Step 4: Stop the container and commit**

```bash
# Stop container with Ctrl+C, then:
git add apps/fifa-bracket/Dockerfile apps/fifa-bracket/.dockerignore
git commit -m "feat(fifa-bracket): add Dockerfile"
```

---

### Task 4: Kubernetes manifests

**Files:**

- Create: `kubernetes/apps/games/fifa-bracket/ks.yaml`
- Create: `kubernetes/apps/games/fifa-bracket/app/kustomization.yaml`
- Create: `kubernetes/apps/games/fifa-bracket/app/ocirepository.yaml`
- Create: `kubernetes/apps/games/fifa-bracket/app/helmrelease.yaml`
- Create: `kubernetes/apps/games/fifa-bracket/app/pvc.yaml`
- Modify: `kubernetes/apps/games/kustomization.yaml`

**Interfaces:**

- Consumes: image `ghcr.io/chr1sd/fifa-bracket:latest` (from Task 3)
- Produces: Flux-managed deployment at `fifa-bracket.dovis.me`

- [ ] **Step 1: Create `kubernetes/apps/games/fifa-bracket/ks.yaml`**

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/fluxcd-community/flux2-schemas/main/kustomization-kustomize-v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
    name: &app fifa-bracket
    namespace: &namespace games
spec:
    commonMetadata:
        labels:
            app.kubernetes.io/name: *app
    dependsOn:
        - name: rook-ceph-cluster
          namespace: rook-ceph
    interval: 1h
    path: ./kubernetes/apps/games/fifa-bracket/app
    postBuild:
        substitute:
            APP: *app
    prune: true
    retryInterval: 2m
    sourceRef:
        kind: GitRepository
        name: flux-system
        namespace: flux-system
    targetNamespace: *namespace
    timeout: 5m
    wait: false
```

- [ ] **Step 2: Create `kubernetes/apps/games/fifa-bracket/app/ocirepository.yaml`**

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
    name: fifa-bracket
spec:
    interval: 15m
    layerSelector:
        mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
        operation: copy
    ref:
        tag: 5.0.1
    url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

- [ ] **Step 3: Create `kubernetes/apps/games/fifa-bracket/app/pvc.yaml`**

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
    name: fifa-bracket
spec:
    accessModes: ["ReadWriteOnce"]
    resources:
        requests:
            storage: 1Gi
    storageClassName: ceph-block
```

- [ ] **Step 4: Create `kubernetes/apps/games/fifa-bracket/app/helmrelease.yaml`**

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
    name: fifa-bracket
spec:
    interval: 1h
    chartRef:
        kind: OCIRepository
        name: fifa-bracket
    install:
        remediation:
            retries: -1
    upgrade:
        cleanupOnFail: true
        remediation:
            retries: 3
    values:
        controllers:
            fifa-bracket:
                strategy: RollingUpdate
                containers:
                    app:
                        image:
                            repository: ghcr.io/chr1sd/fifa-bracket
                            tag: latest
                            pullPolicy: Always
                        env:
                            PORT: &port 3000
                            DATA_FILE: /data/bracket.json
                        probes:
                            liveness: &probes
                                enabled: true
                                custom: true
                                spec:
                                    httpGet:
                                        path: /api/bracket
                                        port: *port
                                    initialDelaySeconds: 5
                                    periodSeconds: 15
                                    timeoutSeconds: 3
                                    failureThreshold: 3
                            readiness: *probes
                        securityContext:
                            allowPrivilegeEscalation: false
                            readOnlyRootFilesystem: false
                            capabilities: { drop: ["ALL"] }
                        resources:
                            requests:
                                cpu: 10m
                            limits:
                                memory: 128Mi
        defaultPodOptions:
            securityContext:
                runAsNonRoot: true
                runAsUser: 1000
                runAsGroup: 1000
                fsGroup: 1000
                fsGroupChangePolicy: Always
        service:
            app:
                ports:
                    http:
                        port: *port
        route:
            app:
                hostnames: ["fifa-bracket.dovis.me"]
                parentRefs:
                    - name: envoy-internal
                      namespace: network
                rules:
                    - backendRefs:
                          - identifier: app
                            port: *port
        persistence:
            data:
                existingClaim: fifa-bracket
                globalMounts:
                    - path: /data
```

- [ ] **Step 5: Create `kubernetes/apps/games/fifa-bracket/app/kustomization.yaml`**

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
    - ./helmrelease.yaml
    - ./ocirepository.yaml
    - ./pvc.yaml
```

- [ ] **Step 6: Update `kubernetes/apps/games/kustomization.yaml`**

Current content:

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: games
components:
    - ../../components/common
resources:
    - ./minecraft/ks.yaml
```

Updated content (add the new resource):

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: games
components:
    - ../../components/common
resources:
    - ./minecraft/ks.yaml
    - ./fifa-bracket/ks.yaml
```

- [ ] **Step 7: Commit all manifests**

```bash
git add kubernetes/apps/games/fifa-bracket/ kubernetes/apps/games/kustomization.yaml
git commit -m "feat(fifa-bracket): add Kubernetes manifests for Flux deployment"
```

---

### Task 5: Build, push, and deploy

**Interfaces:**

- Consumes: image built in Task 3, manifests committed in Task 4
- Produces: live app at `http://fifa-bracket.dovis.me`

- [ ] **Step 1: Log in to GitHub Container Registry**

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u chr1sd --password-stdin
```

If `GITHUB_TOKEN` is not set, create a Personal Access Token with `write:packages` scope at GitHub → Settings → Developer settings → Personal access tokens, then:

```bash
export GITHUB_TOKEN=<your-token>
echo $GITHUB_TOKEN | docker login ghcr.io -u chr1sd --password-stdin
```

Expected: `Login Succeeded`

- [ ] **Step 2: Build and push the image**

```bash
cd apps/fifa-bracket
docker build -t ghcr.io/chr1sd/fifa-bracket:latest .
docker push ghcr.io/chr1sd/fifa-bracket:latest
```

Expected: Push completes, digest printed.

- [ ] **Step 3: Make the package public (first push only)**

Go to `https://github.com/users/chr1sd/packages/container/package/fifa-bracket`, click **Package settings** → **Change visibility** → **Public**. This lets the cluster pull without image pull secrets.

- [ ] **Step 4: Push the git commits to trigger Flux**

```bash
git push
```

- [ ] **Step 5: Watch Flux reconcile**

```bash
kubectl -n games get kustomization fifa-bracket -w
# Wait for READY=True, then:
kubectl -n games get helmrelease fifa-bracket -w
# Wait for READY=True
```

Expected:

```
NAME           AGE   READY   STATUS
fifa-bracket   Xs    True    Applied revision: main/...
```

- [ ] **Step 6: Verify the pod is running**

```bash
kubectl -n games get pods -l app.kubernetes.io/name=fifa-bracket
```

Expected: one pod, `Running`, `1/1` ready.

- [ ] **Step 7: Verify the app works**

```bash
curl -s http://fifa-bracket.dovis.me/api/bracket | python3 -m json.tool | head -10
```

Expected: bracket JSON with empty slots.

Open `http://fifa-bracket.dovis.me` in a browser on your home network. Drag a team into a bracket slot, refresh from another device — the team should still be there.
