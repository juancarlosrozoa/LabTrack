// send-push-notifications
// Sends Firebase Cloud Messaging push notifications to all
// devices of lab members who have alert notifications enabled.
//
// Called internally after stock/expiry events.
//
// Body: {
//   lab_id:  string
//   title:   string
//   body:    string
//   data?:   Record<string, string>
// }

import { handleCors } from '../_shared/cors.ts'
import { adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

const INTERNAL_SECRET  = Deno.env.get('INTERNAL_FUNCTION_SECRET')
const FCM_SERVER_KEY   = Deno.env.get('FCM_SERVER_KEY')        // Firebase server key
const FCM_API_URL      = 'https://fcm.googleapis.com/fcm/send'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  const secret = req.headers.get('x-internal-secret')
  if (!INTERNAL_SECRET || secret !== INTERNAL_SECRET) {
    return errorResponse('Unauthorized', 401)
  }

  if (!FCM_SERVER_KEY) return errorResponse('FCM not configured', 500)

  try {
    const { lab_id, title, body, data } = await req.json()

    if (!lab_id || !title || !body) {
      return errorResponse('lab_id, title, and body are required', 400)
    }

    // Get all member user_ids for this lab
    const { data: members, error: membersError } = await adminClient
      .from('lab_members')
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

    const registrationTokens = tokens.map((t: { token: string }) => t.token)

    // Send via FCM Legacy API (batch)
    const fcmPayload = {
      registration_ids: registrationTokens,
      notification: { title, body },
      data: data ?? {},
      priority: 'high',
    }

    const fcmRes = await fetch(FCM_API_URL, {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fcmPayload),
    })

    if (!fcmRes.ok) {
      const text = await fcmRes.text()
      throw new Error(`FCM error ${fcmRes.status}: ${text}`)
    }

    const result = await fcmRes.json()
    return jsonResponse({ sent: registrationTokens.length, fcm_result: result })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    return errorResponse(message, 500)
  }
})
