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
