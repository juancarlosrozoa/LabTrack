import { adminClient } from './auth.ts'

export type WebhookEvent =
  | 'critical_stock'
  | 'expiring_soon'
  | 'lot_expired'
  | 'entry_registered'
  | 'adjustment_approved'

/**
 * Dispatches a webhook event to all active subscribers for a given lab.
 * Signs the payload with the webhook secret using HMAC-SHA256.
 */
export async function dispatchWebhook(
  labId: string,
  event: WebhookEvent,
  payload: Record<string, unknown>,
): Promise<void> {
  const { data: hooks, error } = await adminClient
    .from('webhooks')
    .select('url, secret')
    .eq('lab_id', labId)
    .eq('is_active', true)
    .contains('events', [event])

  if (error || !hooks?.length) return

  const body = JSON.stringify({ event, data: payload, timestamp: new Date().toISOString() })

  await Promise.allSettled(
    hooks.map(async (hook: { url: string; secret: string | null }) => {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' }

      if (hook.secret) {
        headers['X-LabTrack-Signature'] = await hmacSignature(hook.secret, body)
      }

      await fetch(hook.url, { method: 'POST', headers, body })
    }),
  )
}

async function hmacSignature(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body))
  return 'sha256=' + Array.from(new Uint8Array(sig))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}
