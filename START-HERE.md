# Unassigned

Anonymous link sharing over SMS. A sender gets an anonymous handle, enters a
recipient's number and a link; the link is held, the recipient is asked for
permission, and it is released only after they reply Y.

## Layout

    site/                       static pages (Netlify publish dir)
      index.html                sender page
      consent.html              public SMS consent, privacy policy and terms
    netlify/functions/          Netlify Functions
      signup.js                 mints an ASSIGNED handle + api_token
      seal-and-send.js          holds the link, sends the permission request
      twilio-webhook.js         handles inbound Y / STOP / HELP
    netlify.toml                publish + functions dirs, /api/* redirects
    schema.sql                  Postgres schema and the bump_send_count function

## Environment variables (set in Netlify, not in this repo)

    SUPABASE_URL
    SUPABASE_SERVICE_ROLE_KEY   service_role, not anon
    TWILIO_ACCOUNT_SID
    TWILIO_AUTH_TOKEN
    TWILIO_FROM_NUMBER          +18662847320
    PUBLIC_WEBHOOK_URL          must include the https:// prefix
    SITE_URL

## SMS flow

1. Recipient gets one permission request. It contains no link.
2. Recipient replies Y.
3. One message delivers the confirmation and the link together.

STOP opts a number out permanently and deletes any held link. HELP returns
support information. The exact strings live in the function source and are
mirrored on site/consent.html - keep the two in sync.

## Notes

seal-and-send.js and twilio-webhook.js are pre-bundled with dependencies
inlined, so no build step or npm install is needed. signup.js is dependency-free
and calls Supabase over PostgREST.

The Supabase project is on the free plan and pauses after about a week of
inactivity. While paused every function fails and the app reports
"unauthorized" - resume the project in the Supabase dashboard.
