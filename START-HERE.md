# Unassigned — deploy by DRAG AND DROP (no GitHub, no build)

The functions in here are pre-bundled: every dependency is already inside each
file. That means Netlify does NOT need to run a build or npm install — so plain
drag-and-drop works. This is why the earlier attempts failed and this one won't.

---

## STEP 1 — Database (2 min)  [skip if you already ran it]
1. supabase.com -> your project -> **SQL Editor** -> **New query**
2. Open `schema.sql` from this folder, copy ALL of it, paste, **Run**.
   (If it warns "destructive operation", that's normal — click Run query.)
3. **Project Settings (gear) -> API** -> copy your **Project URL** and the
   **service_role** secret key. You need both in Step 3.

## STEP 2 — Deploy (2 min)
1. Go to **app.netlify.com** -> **Add new site** -> **Deploy manually**
2. Drag the whole **`unassigned-deploy` folder** into the drop zone.
   (Drag the FOLDER — the one containing netlify.toml, site/, netlify/.)
3. Wait ~1 min. You get a URL like `https://something.netlify.app`. Copy it.

## STEP 3 — Add your 7 keys
Netlify -> **Site configuration -> Environment variables** -> Add a variable
(choose "Same value for all deploy contexts") for each:

| Key | Value |
|-----|-------|
| SUPABASE_URL | your Supabase Project URL |
| SUPABASE_SERVICE_ROLE_KEY | your service_role secret key |
| TWILIO_ACCOUNT_SID | your AC... value |
| TWILIO_AUTH_TOKEN | your Twilio auth token |
| TWILIO_FROM_NUMBER | +18662847320 |
| SITE_URL | your Netlify URL |
| PUBLIC_WEBHOOK_URL | your Netlify URL + /api/twilio-webhook |

Then **Deploys -> Trigger deploy -> Deploy site**.

## STEP 4 — Twilio webhook
Twilio Console -> **Phone Numbers -> Manage -> Active numbers** -> your number ->
**Messaging Configuration** -> "A message comes in":
- **Webhook**, **HTTP POST**, `https://YOUR-SITE.netlify.app/api/twilio-webhook`
- Save.

---

## CHECK IT WORKED
Open `https://YOUR-SITE.netlify.app/api/signup` in a browser.
- You should see: `{"error":"method_not_allowed"}`
- That JSON means the backend is LIVE (the endpoint wants a POST, not a browser visit).
- If you see "Page not found" instead, the functions didn't deploy — check that you
  dragged the folder containing `netlify.toml`.

Your homepage `https://YOUR-SITE.netlify.app` should show the dark "UA" page.

## TRY THE REAL FLOW (no terminal needed — use reqbin.com)
1. POST to `https://YOUR-SITE.netlify.app/api/signup`
   Body: `{}`  -> returns your `username` (ASSIGNED######) and `api_token`.
2. POST to `https://YOUR-SITE.netlify.app/api/seal-and-send`
   Header: `Authorization: Bearer <that api_token>`
   Header: `Content-Type: application/json`
   Body: `{"recipient_phone":"+1YOURPHONE","link":"https://tiktok.com/x","note":"test"}`
3. You get a text: "You have a link from ASSIGNED###### ... Reply Y"
4. Reply **Y** -> the link arrives. Reply **STOP** -> blocked.

## IMPORTANT — Twilio trial limits
On a trial account you can ONLY text numbers you have verified in Twilio
(Console -> Phone Numbers -> Verified Caller IDs). Add your own phone first, or
sends will fail with "unverified" — that's the trial, not the code.
Toll-free verification + adding funds removes this.

## How it works
- Signup gives each user a permanent anonymous name (ASSIGNED######).
- First text to any new number is the consent request ONLY — the link is held
  in the database, never sent, until they reply Y.
- Reply Y -> held links released "from ASSIGNED######". Real identity never shown.
- Reply STOP -> opted out; future sends silently do nothing.
- Free tier = 1 send/day (enforced atomically, no race conditions).
