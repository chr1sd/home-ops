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
