import assert from "node:assert/strict";
import test from "node:test";
import { Simulator, request } from "../client.mjs";

const state = (id) => ({ meta: { last_event_id: id } });
const gift = (id) => ({ id, type: "gift", effect: "food_drop" });

function harness(transport) {
  const visible = { states: [], events: [], gifts: [], resets: 0 };
  const client = new Simulator({
    transport,
    onState: (value) => visible.states.push(value),
    onEvents: (values) => visible.events.push(...values),
    onGift: (value) => visible.gifts.push(value),
    onReset: () => { visible.events = []; visible.resets++; },
  });
  return { client, visible };
}

test("polling sorts events, deduplicates them, and uses an exclusive cursor", async () => {
  const paths = [];
  const { client, visible } = harness(async (path) => {
    paths.push(path);
    return path === "/state" ? state(3) : [gift(3), gift(1), gift(2), gift(2)];
  });
  await client.refresh();
  await client.refresh();
  assert.deepEqual(visible.events.map((event) => event.id), [1, 2, 3]);
  assert.deepEqual(paths, ["/state", "/events?after=0", "/state", "/events?after=3"]);
  assert.deepEqual(visible.gifts, [], "historical gifts do not replay notifications");
});

test("a POST updates state immediately without skipping earlier unseen events", async () => {
  const paths = [];
  let current = 1;
  const { client, visible } = harness(async (path, payload) => {
    paths.push(path);
    if (path === "/state") return state(current);
    if (path === "/event/gift") {
      assert.deepEqual(payload, { tier: "small" });
      current = 3;
      return { state: state(3), event: gift(3) };
    }
    return current === 1 ? [gift(1)] : [gift(2), gift(3)];
  });
  await client.refresh();
  await client.send("gift", { tier: "small" });
  assert.equal(visible.states.at(-1).meta.last_event_id, 3);
  assert.equal(client.cursor, 1);
  await client.refresh();
  assert.equal(paths.at(-1), "/events?after=1");
  assert.deepEqual(visible.events.map((event) => event.id), [1, 2, 3]);
  assert.equal(visible.gifts.filter((event) => event.id === 3).length, 1);
});

test("new externally submitted gifts trigger feedback once", async () => {
  let current = 0;
  const { client, visible } = harness(async (path) =>
    path === "/state" ? state(current) : current ? [gift(1)] : []);
  await client.refresh();
  current = 1;
  await client.refresh();
  await client.refresh();
  assert.deepEqual(visible.gifts, [gift(1)]);
});

test("a lower backend event ID resets the feed and reloads from zero", async () => {
  let current = 5;
  const paths = [];
  const { client, visible } = harness(async (path) => {
    paths.push(path);
    return path === "/state" ? state(current) : [gift(current)];
  });
  await client.refresh();
  current = 1;
  await client.refresh();
  assert.equal(visible.resets, 1);
  assert.equal(paths.at(-1), "/events?after=0");
  assert.deepEqual(visible.events, [gift(1)]);
});

test("events arriving between state and feed requests trigger a state refresh", async () => {
  let stateCalls = 0;
  const { client, visible } = harness(async (path) => {
    if (path === "/state") return state(stateCalls++);
    return [gift(1)];
  });
  await client.refresh();
  assert.equal(visible.states.at(-1).meta.last_event_id, 1);
});

test("a failed poll retains the cursor and later polling recovers", async () => {
  let failing = true;
  const { client, visible } = harness(async (path) => {
    if (path === "/state") return state(1);
    if (failing) throw new Error("offline");
    assert.equal(path, "/events?after=0");
    return [gift(1)];
  });
  await assert.rejects(client.refresh(), /offline/);
  assert.equal(client.cursor, 0);
  failing = false;
  await client.refresh();
  assert.deepEqual(visible.events, [gift(1)]);
});

test("failed submissions do not mutate displayed state or automatically retry", async () => {
  let calls = 0;
  const { client, visible } = harness(async () => { calls++; throw new Error("HTTP 422"); });
  await assert.rejects(client.send("comment", { text: "" }), /422/);
  assert.equal(calls, 1);
  assert.deepEqual(visible.states, []);
  assert.deepEqual(visible.gifts, []);
});

test("polling and submissions execute serially to prevent stale responses", async () => {
  let release;
  const blocked = new Promise((resolve) => { release = resolve; });
  const calls = [];
  const { client } = harness(async (path) => {
    calls.push(path);
    if (path === "/state") { await blocked; return state(0); }
    if (path.startsWith("/events?")) return [];
    return { state: state(1), event: gift(1) };
  });
  const refresh = client.refresh();
  const send = client.send("gift", { tier: "small" });
  await Promise.resolve();
  assert.deepEqual(calls, ["/state"]);
  release();
  await Promise.all([refresh, send]);
  assert.deepEqual(calls, ["/state", "/events?after=0", "/event/gift"]);
});

test("transport uses the existing same-origin endpoints and JSON payloads", async (t) => {
  t.mock.method(globalThis, "fetch", async (path, options) => {
    assert.equal(path, "/event/comment");
    assert.equal(options.method, "POST");
    assert.equal(options.headers["Content-Type"], "application/json");
    assert.equal(options.body, JSON.stringify({ text: "sleep" }));
    assert.equal(options.cache, "no-store");
    assert.ok(options.signal instanceof AbortSignal);
    return { ok: true, json: async () => ({ accepted: true }) };
  });
  assert.deepEqual(await request("/event/comment", { text: "sleep" }), { accepted: true });
});

test("transport rejects HTTP errors instead of treating them as accepted events", async (t) => {
  t.mock.method(globalThis, "fetch", async () => ({ ok: false, status: 422 }));
  await assert.rejects(request("/event/gift", { tier: "invalid" }), /HTTP 422/);
});
