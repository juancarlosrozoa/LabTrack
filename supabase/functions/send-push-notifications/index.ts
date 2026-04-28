// send-push-notifications
// Sends FCM v1 push notifications to all devices of lab members.
//
// Body: { lab_id: string, title: string, body: string, data?: Record<string,string> }
//
// Required env vars:
//   GOOGLE_SERVICE_ACCOUNT_JSON  — same service account used for Sheets
//   INTERNAL_FUNCTION_SECRET     — shared secret for internal calls

import { handleCors } from '../_shared/cors.ts'
import { adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

const INTERNAL_SECRET       = Deno.env.get('INTERNAL_FUNCTION_SECRET')
const SERVICE_ACCOUNT_JSON  = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
const FCM_SCOPE             = 'https://www.googleapis.com/auth/firebase.messaging'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  const secret = req.headers.get('x-internal-secret')
  if (!INTERNAL_SECRET || secret !== INTERNAL_SECRET) {
    return errorResponse('Unauthorized', 401)
  }

  if (!SERVICE_ACCOUNT_JSON) {
    return errorResponse('Google service account not configured', 500)
  }

  try {
    const { lab_id, title, body, data } = await req.json()
    if (!lab_id || !title || !body) {
      return errorResponse('lab_id, title, and body are required', 400)
    }

    // Get all member user_ids for this lab
    const { data: members, error: membersError } = await adminClient
      .from('lab_memberships')
      .select('user_id')
      .eq('lab_id', lab_id)

    if (membersError) throw membersError
    if (!members?.length) return jsonResponse({ sent: 0 })

    const userIds = members.map((m: { user_id: string }) => m.user_id)

    // Get FCM tokens for all these users
    const { data: tokens, error: tokensError } = await adminClient
      .from('fcm_tokens')
      .select('token')
      .in('user_id', userIds)

    if (tokensError) throw tokensError
    if (!tokens?.length) return jsonResponse({ sent: 0 })

    const accessToken = await getGoogleAccessToken()
    const sa          = JSON.parse(SERVICE_ACCOUNT_JSON)
    const projectId   = sa.project_id

    // FCM v1: send one message per token (in parallel)
    const results = await Promise.allSettled(
      tokens.map((t: { token: string }) =>
        sendFcmV1(accessToken, projectId, t.token, title, body, data ?? {}),
      ),
    )

    const sent   = results.filter((r: PromiseSettledResult<unknown>) => r.status === 'fulfilled').length
    const failed = results.length - sent

    return jsonResponse({ sent, failed })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    return errorResponse(message, 500)
  }
})

async function sendFcmV1(
  accessToken: string,
  projectId:   string,
  token:       string,
  title:       string,
  body:        string,
  data:        Record<string, string>,
) {
  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
  const res = await fetch(url, {
    method:  'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type':  'application/json',
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        apns:    { payload: { aps: { sound: 'default' } } },
      },
    }),
  })

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`FCM error for token ${token.slice(0, 10)}…: ${text}`)
  }
}

// ── Google Service Account JWT auth ───────────────────────

async function getGoogleAccessToken(): Promise<string> {
  const sa  = JSON.parse(SERVICE_ACCOUNT_JSON!)
  const now = Math.floor(Date.now() / 1000)

  const header  = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = toBase64Url(JSON.stringify({
    iss:   sa.client_email,
    scope: FCM_SCOPE,
    aud:   'https://oauth2.googleapis.com/token',
    iat:   now,
    exp:   now + 3600,
  }))

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const sigBytes = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )

  const jwt = `${header}.${payload}.${toBase64UrlBytes(new Uint8Array(sigBytes))}`

  const res  = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const json = await res.json()
  if (!json.access_token) throw new Error(`Token error: ${JSON.stringify(json)}`)
  return json.access_token
}

function toBase64Url(str: string): string {
  return btoa(unescape(encodeURIComponent(str)))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function toBase64UrlBytes(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')
  return Uint8Array.from(atob(b64), c => c.charCodeAt(0)).buffer
}
