import { verifyDeeplinkToken } from '../_shared/deeplink_jwt.ts'

// ─────────────────────────────────────────────────────────────────────────────
// resolve-deeplink  (public — no JWT auth required)
//
// Resolves an opaque deep-link token into its action + target (+ optional userId).
// The token itself is the proof of authenticity (HS256-signed JWT).
//
// Request: POST  { "token": "<jwt>" }
//    or:   GET   ?token=<jwt>
// Response 200:  { "action": "...", "target": "...", "userId": "..." }
// Response 401:  { "error": "invalid or expired link" }
//
// Never reveals whether a token was invalid vs. expired — uniform 401.
//
// Required env: DEEPLINK_JWT_SECRET  (min 32 chars, random)
// Generate once per project:  openssl rand -hex 32
// ─────────────────────────────────────────────────────────────────────────────

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: cors })
  }

  try {
    let token: string | null = null

    if (req.method === 'POST') {
      const body = await req.json().catch(() => null)
      token = typeof body?.token === 'string' ? body.token : null
    } else if (req.method === 'GET') {
      token = new URL(req.url).searchParams.get('token')
    }

    if (!token) {
      return new Response(JSON.stringify({ error: 'token required' }), {
        status: 400,
        headers: { ...cors, 'Content-Type': 'application/json' },
      })
    }

    const payload = await verifyDeeplinkToken(token)

    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  } catch (_err) {
    // Intentionally uniform — do not leak whether token was expired vs. tampered.
    return new Response(JSON.stringify({ error: 'invalid or expired link' }), {
      status: 401,
      headers: { ...cors, 'Content-Type': 'application/json' },
    })
  }
})
