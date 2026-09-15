"use strict";
// Creates an anonymous sender identity: an ASSIGNED handle + an API token.
// Dependency-free on purpose - no bundler, no npm install, drag-and-drop safe.
// Talks to Supabase over PostgREST with the service role key.

const crypto = require("crypto");

const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/+$/, "");
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(body)
});

// Handle format matches the existing rows: ASSIGNED + 6 uppercase alphanumerics.
const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
function makeHandle() {
  const bytes = crypto.randomBytes(6);
  let suffix = "";
  for (let i = 0; i < 6; i++) suffix += ALPHABET[bytes[i] % ALPHABET.length];
  return "ASSIGNED" + suffix;
}

// Opaque bearer token. Hex keeps it safe in an Authorization header.
function makeToken() {
  return crypto.randomBytes(16).toString("hex");
}

async function insertUser(username, api_token) {
  return fetch(`${SUPABASE_URL}/rest/v1/users`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      Authorization: `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal"
    },
    body: JSON.stringify({ username, api_token, tier: "free" })
  });
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { error: "method_not_allowed" });
  if (!SUPABASE_URL || !SERVICE_KEY) {
    return json(500, { error: "signup_failed", detail: "supabase_env_missing" });
  }

  try {
    // Retry only on a handle collision; 6 chars over 36 symbols makes this rare.
    for (let attempt = 0; attempt < 5; attempt++) {
      const username = makeHandle();
      const api_token = makeToken();
      const res = await insertUser(username, api_token);

      if (res.status === 201 || res.status === 200) {
        return json(200, { username, api_token, tier: "free" });
      }

      const detail = await res.text().catch(() => "");
      if (res.status === 409 && /username/i.test(detail)) continue;

      return json(500, {
        error: "signup_failed",
        detail: `db_${res.status}: ${detail.slice(0, 200)}`
      });
    }
    return json(500, { error: "signup_failed", detail: "handle_collision_retries_exhausted" });
  } catch (err) {
    return json(500, { error: "signup_failed", detail: String((err && err.message) || err) });
  }
};
