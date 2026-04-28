// check-stock-alerts
// Checks stock levels for all labs and sends push notifications
// to members when items are critical, out of stock, or expiring soon.
//
// Called by pg_cron every hour.
//
// Required env vars:
//   INTERNAL_FUNCTION_SECRET  — to call send-push-notifications
//   SUPABASE_URL              — to build the function URL

import { adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

const INTERNAL_SECRET = Deno.env.get('INTERNAL_FUNCTION_SECRET')
const SUPABASE_URL    = Deno.env.get('SUPABASE_URL')

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  // Only callable internally (pg_cron uses service role key)
  const authHeader = req.headers.get('authorization') ?? ''
  if (!authHeader.includes(Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '___')) {
    const secret = req.headers.get('x-internal-secret')
    if (!INTERNAL_SECRET || secret !== INTERNAL_SECRET) {
      return errorResponse('Unauthorized', 401)
    }
  }

  try {
    // Get all labs
    const { data: labs, error: labsError } = await adminClient
      .from('laboratories')
      .select('id, name')

    if (labsError) throw labsError
    if (!labs?.length) return jsonResponse({ checked: 0 })

    const results = await Promise.allSettled(
      labs.map((lab: { id: string; name: string }) => checkLab(lab)),
    )

    const sent  = results.filter(r => r.status === 'fulfilled').length
    const errors = results
      .filter((r): r is PromiseRejectedResult => r.status === 'rejected')
      .map(r => r.reason?.message ?? 'Unknown error')

    return jsonResponse({ checked: labs.length, notified: sent, errors })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    return errorResponse(message, 500)
  }
})

async function checkLab(lab: { id: string; name: string }) {
  const alerts: string[] = []

  // Check out-of-stock and critical items
  const { data: stockIssues } = await adminClient
    .from('product_stock')
    .select('name, stock_status')
    .eq('lab_id', lab.id)
    .in('stock_status', ['out_of_stock', 'critical'])
    .order('stock_status')

  if (stockIssues?.length) {
    const outOfStock = stockIssues.filter(p => p.stock_status === 'out_of_stock')
    const critical   = stockIssues.filter(p => p.stock_status === 'critical')

    if (outOfStock.length) {
      alerts.push(`Out of stock: ${outOfStock.map(p => p.name).join(', ')}`)
    }
    if (critical.length) {
      alerts.push(`Critical stock: ${critical.map(p => p.name).join(', ')}`)
    }
  }

  // Check expiring soon (≤30 days)
  const { data: expiring } = await adminClient
    .from('lots_expiring_soon')
    .select('product_name, days_until_expiry')
    .eq('lab_id', lab.id)
    .lte('days_until_expiry', 30)
    .order('days_until_expiry')
    .limit(5)

  if (expiring?.length) {
    alerts.push(
      `Expiring soon: ${expiring.map(l => `${l.product_name} (${l.days_until_expiry}d)`).join(', ')}`,
    )
  }

  if (!alerts.length) return

  await sendNotification({
    lab_id: lab.id,
    title:  `LabTrack — ${lab.name}`,
    body:   alerts[0],
    data:   { type: 'stock_alert', lab_id: lab.id },
  })
}

async function sendNotification(payload: {
  lab_id: string
  title:  string
  body:   string
  data:   Record<string, string>
}) {
  const url = `${SUPABASE_URL}/functions/v1/send-push-notifications`
  const res = await fetch(url, {
    method:  'POST',
    headers: {
      'Content-Type':       'application/json',
      'x-internal-secret':  INTERNAL_SECRET ?? '',
    },
    body: JSON.stringify(payload),
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error(`send-push-notifications failed: ${text}`)
  }
}
