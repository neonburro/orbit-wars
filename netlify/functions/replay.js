// netlify/functions/replay.js
// Live-fetches an Orbit Wars episode replay JSON from Kaggle on demand.
// The replay download is an internal KaggleSDK RPC, not a stable public REST GET,
// so this tries the known SDK endpoints in order and returns a clear error if the
// shape has changed. Kept lean so it streams the (large) JSON straight back.

function authHeader() {
  const user = process.env.KAGGLE_USERNAME;
  const key = process.env.KAGGLE_KEY;
  if (!user || !key) return null;
  return "Basic " + Buffer.from(user + ":" + key).toString("base64");
}

async function tryEndpoint(url, method, body, auth) {
  const opts = { method: method, headers: { Authorization: auth } };
  if (body) {
    opts.headers["Content-Type"] = "application/json";
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(url, opts);
  if (!res.ok) return { ok: false, status: res.status };
  const text = await res.text();
  // Some endpoints wrap the replay; try to find the replay JSON.
  let parsed;
  try { parsed = JSON.parse(text); } catch (e) { return { ok: false, status: 0, note: "non-json" }; }
  // Unwrap common shapes: { replay: "<json string>" } or { replay: {...} } or direct
  let replay = parsed.replay != null ? parsed.replay : parsed;
  if (typeof replay === "string") {
    try { replay = JSON.parse(replay); } catch (e) { /* leave as-is */ }
  }
  if (replay && replay.steps) return { ok: true, replay: replay };
  if (parsed && parsed.steps) return { ok: true, replay: parsed };
  return { ok: false, status: res.status, note: "no steps in payload" };
}

exports.handler = async function (event) {
  const auth = authHeader();
  if (!auth) {
    return { statusCode: 500, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Missing KAGGLE_USERNAME or KAGGLE_KEY env vars" }) };
  }
  const id = event.queryStringParameters && event.queryStringParameters.id;
  if (!id) {
    return { statusCode: 400, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ error: "Missing episode id" }) };
  }

  const attempts = [
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/GetEpisodeReplay", method: "POST", body: { EpisodeId: Number(id) } },
    { url: "https://www.kaggle.com/api/i/competitions.EpisodeService/GetEpisodeReplay", method: "POST", body: { episodeId: Number(id) } },
    { url: "https://www.kaggle.com/api/v1/competitions/episodes/" + encodeURIComponent(id) + "/replay", method: "GET", body: null }
  ];

  const tried = [];
  for (let i = 0; i < attempts.length; i++) {
    try {
      const a = attempts[i];
      const r = await tryEndpoint(a.url, a.method, a.body, auth);
      tried.push({ url: a.url, method: a.method, status: r.status, note: r.note });
      if (r.ok) {
        return {
          statusCode: 200,
          headers: { "Content-Type": "application/json", "Cache-Control": "public, max-age=3600" },
          body: JSON.stringify(r.replay)
        };
      }
    } catch (e) {
      tried.push({ error: String(e.message || e) });
    }
  }

  return {
    statusCode: 502,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ error: "Could not fetch replay from Kaggle", episode: id, tried: tried })
  };
};
