// dispatch-webhooks
// Called internally (via Supabase Database Webhook or another Edge Function)
// to fan-out an event to all active webhook subscribers for a lab.
//
// Body: {
//   lab_id:  string
//   event:   WebhookEvent
//   payload: Record<string, unknown>
// }

import { handleCors } from '../_shared/cors.ts'
import { errorResponse, jsonResponse } from '../_shared/auth.ts'
import { dispatchWebhook, WebhookEvent } from '../_shared/webhook.ts'

const INTERNAL_SECRET = Deno.env.get('INTERNAL_FUNCTION_SECRET')

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  // Protect from public calls — only allow internal invocations
  const secret = req.headers.get('x-internal-secret')
  if (!INTERNAL_SECRET || secret !== INTERNAL_SECRET) {
    return errorResponse('Unauthorized', 401)
  }

  try {
    const { lab_id, event, payload } = await req.json()

    if (!lab_id || !event || !payload) {
      return errorResponse('lab_id, event, and payload are required', 400)
    }

    await dispatchWebhook(lab_id, event as WebhookEvent, payload)

    return jsonResponse({ dispatched: true })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    return errorResponse(message, 500)
  }
})
