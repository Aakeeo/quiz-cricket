import { writeFileSync } from "node:fs";
const out = process.argv[2];
const list = await (await fetch("http://127.0.0.1:9222/json")).json();
const ws = new WebSocket(list.find(t => t.type === "page").webSocketDebuggerUrl);
await new Promise(r => ws.onopen = r);
let id = 0; const pending = new Map();
ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); } };
const send = (method, params = {}) => new Promise(r => { ws.send(JSON.stringify({ id: ++id, method, params })); pending.set(id, r); });
const sleep = ms => new Promise(r => setTimeout(r, ms));
await send("Runtime.enable"); await send("Page.enable");
await send("Page.navigate", { url: "http://localhost:8767/export.html" });
for (let i = 0; i < 60; i++) {
  await sleep(1000);
  const r = await send("Runtime.evaluate", { expression: "window.__glb ? 'ok' : (window.__err || '')", returnByValue: true });
  const v = r.result.value;
  if (v === "ok") break;
  if (v) { console.log("PAGE ERROR:", v); process.exit(1); }
}
const r = await send("Runtime.evaluate", { expression: "window.__glb", returnByValue: true });
if (!r.result.value) { console.log("timed out waiting for export"); process.exit(1); }
writeFileSync(out, Buffer.from(r.result.value, "base64"));
console.log("wrote", out, Buffer.from(r.result.value, "base64").length, "bytes");
ws.close(); process.exit(0);
