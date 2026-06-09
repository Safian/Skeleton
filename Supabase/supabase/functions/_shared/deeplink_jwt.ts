import { SignJWT, jwtVerify } from 'npm:jose'

// ─────────────────────────────────────────────────────────────────────────────
// Deep Link JWT utility
//
// Creates and verifies short-lived signed tokens that encode the action and
// target payload.  Stateless — no DB lookup required on resolution.
//
// Token payload shape:
//   {
//     action  : string   // e.g. 'open_item', 'reset_password', …
//     target  : string   // itemId, userId, or any opaque ID
//     userId? : string   // optional — the intended recipient user
//   }
//
// Required env: DEEPLINK_JWT_SECRET  (min 32 chars, random)
// Generate once per project:  openssl rand -hex 32
// ─────────────────────────────────────────────────────────────────────────────

export interface DeeplinkPayload {
  action: string
  target: string
  userId?: string
}

function getKey(): Uint8Array {
  const secret = Deno.env.get('DEEPLINK_JWT_SECRET')
  if (!secret || secret.length < 16) {
    throw new Error('DEEPLINK_JWT_SECRET env var is missing or too short')
  }
  return new TextEncoder().encode(secret)
}

/**
 * Creates a signed HS256 JWT token encoding the deep link payload.
 * @param payload  The action + target (+ optional userId) to encode.
 * @param expiresInDays  Token lifetime in days (default 7).
 */
export async function createDeeplinkToken(
  payload: DeeplinkPayload,
  expiresInDays = 7,
): Promise<string> {
  return new SignJWT({ ...payload })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(`${expiresInDays}d`)
    .sign(getKey())
}

/**
 * Verifies and decodes a deep link token.
 * Throws on invalid signature, malformed payload, or expiry.
 */
export async function verifyDeeplinkToken(token: string): Promise<DeeplinkPayload> {
  const { payload } = await jwtVerify(token, getKey(), { algorithms: ['HS256'] })

  const { action, target, userId } = payload as Record<string, unknown>

  if (typeof action !== 'string' || typeof target !== 'string') {
    throw new Error('invalid deeplink token payload shape')
  }

  return {
    action,
    target,
    userId: typeof userId === 'string' ? userId : undefined,
  }
}
