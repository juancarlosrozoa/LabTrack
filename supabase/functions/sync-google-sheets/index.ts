// sync-google-sheets
// Syncs current lab inventory to 4 Google Sheets tabs:
//   Stock | Expiring Soon | Movements | Restock Needed
//
// Triggered by:
//   - Supabase pg_cron schedule (e.g. every hour)
//   - Manually from the app after a movement or count
//
// Required env vars:
//   GOOGLE_SERVICE_ACCOUNT_JSON  — service account JSON with Sheets access
//
// Body: { lab_id: string }

import { handleCors } from '../_shared/cors.ts'
import { adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

const INTERNAL_SECRET         = Deno.env.get('INTERNAL_FUNCTION_SECRET')
const SERVICE_ACCOUNT_JSON    = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
const SHEETS_SCOPE            = 'https://www.googleapis.com/auth/spreadsheets'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  const secret = req.headers.get('x-internal-secret')
  if (!INTERNAL_SECRET || secret !== INTERNAL_SECRET) {
    return errorResponse('Unauthorized', 401)
  }

  if (!SERVICE_ACCOUNT_JSON) return errorResponse('Google service account not configured', 500)

  try {
    const { lab_id } = await req.json()
    if (!lab_id) return errorResponse('lab_id is required', 400)

    // Fetch the spreadsheet ID stored for this lab (stored in alert_config or a dedicated table)
    const { data: lab } = await adminClient
      .from('laboratories')
      .select('id, name')
      .eq('id', lab_id)
      .single()

    if (!lab) return errorResponse('Lab not found', 404)

    // For now we read the sheet ID from an env var per lab.
    // In production this would be stored in a google_sheets_config table.
    const spreadsheetId = Deno.env.get(`SHEETS_ID_${lab_id.replace(/-/g, '_')}`)
    if (!spreadsheetId) return errorResponse('No spreadsheet configured for this lab', 404)

    const accessToken = await getGoogleAccessToken()

    // Fetch data in parallel
    const [stock, expiring, movements, restock] = await Promise.all([
      fetchStock(lab_id),
      fetchExpiring(lab_id),
      fetchMovements(lab_id),
      fetchRestock(lab_id),
    ])

    // Write each sheet
    await Promise.all([
      writeSheet(accessToken, spreadsheetId, 'Stock',           buildStockRows(stock)),
      writeSheet(accessToken, spreadsheetId, 'Expiring Soon',   buildExpiringRows(expiring)),
      writeSheet(accessToken, spreadsheetId, 'Movements',       buildMovementRows(movements)),
      writeSheet(accessToken, spreadsheetId, 'Restock Needed',  buildRestockRows(restock)),
    ])

    return jsonResponse({ synced: true, lab_id })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    return errorResponse(message, 500)
  }
})

// ── Data fetchers ──────────────────────────────────────────

async function fetchStock(labId: string) {
  const { data } = await adminClient
    .from('product_stock')
    .select('*')
    .eq('lab_id', labId)
    .order('name')
  return data ?? []
}

async function fetchExpiring(labId: string) {
  const { data } = await adminClient
    .from('lots_expiring_soon')
    .select('*')
    .eq('lab_id', labId)
    .order('days_until_expiry')
  return data ?? []
}

async function fetchMovements(labId: string) {
  const { data } = await adminClient
    .from('movements')
    .select('id, type, quantity, reason, area, project, created_at, products(name), auth.users(email)')
    .eq('lab_id', labId)
    .order('created_at', { ascending: false })
    .limit(500)
  return data ?? []
}

async function fetchRestock(labId: string) {
  const { data } = await adminClient
    .from('product_stock')
    .select('*')
    .eq('lab_id', labId)
    .in('stock_status', ['reorder', 'critical', 'out_of_stock'])
  return data ?? []
}

// ── Row builders ───────────────────────────────────────────

// deno-lint-ignore no-explicit-any
function buildStockRows(data: any[]): string[][] {
  const header = ['Product', 'Unit', 'Total Qty', 'Reorder Point', 'Min Stock', 'Status']
  const rows   = data.map(r => [r.name, r.unit, r.total_quantity, r.reorder_point, r.minimum_stock, r.stock_status])
  return [header, ...rows]
}

// deno-lint-ignore no-explicit-any
function buildExpiringRows(data: any[]): string[][] {
  const header = ['Product', 'Lot', 'Qty', 'Unit', 'Expiration Date', 'Days Remaining']
  const rows   = data.map(r => [r.product_name, r.lot_number, r.quantity, r.unit, r.expiration_date, r.days_until_expiry])
  return [header, ...rows]
}

// deno-lint-ignore no-explicit-any
function buildMovementRows(data: any[]): string[][] {
  const header = ['Date', 'Type', 'Product', 'Qty', 'Reason', 'Area', 'Project', 'User']
  const rows   = data.map(r => [
    r.created_at, r.type,
    r.products?.name ?? '',
    r.quantity, r.reason ?? '', r.area ?? '', r.project ?? '',
    r['auth.users']?.email ?? '',
  ])
  return [header, ...rows]
}

// deno-lint-ignore no-explicit-any
function buildRestockRows(data: any[]): string[][] {
  const header = ['Product', 'Unit', 'Current Stock', 'Reorder Point', 'Status']
  const rows   = data.map(r => [r.name, r.unit, r.total_quantity, r.reorder_point, r.stock_status])
  return [header, ...rows]
}

// ── Google Sheets API ──────────────────────────────────────

async function writeSheet(token: string, spreadsheetId: string, sheetName: string, values: string[][]) {
  const range = `${sheetName}!A1`
  const url   = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}/values/${encodeURIComponent(range)}?valueInputOption=RAW`

  const res = await fetch(url, {
    method: 'PUT',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ range, majorDimension: 'ROWS', values }),
  })

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Sheets write error for "${sheetName}": ${text}`)
  }
}

async function getGoogleAccessToken(): Promise<string> {
  const sa  = JSON.parse(SERVICE_ACCOUNT_JSON!)
  const now = Math.floor(Date.now() / 1000)

  const header  = btoa(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: SHEETS_SCOPE,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }))

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(`${header}.${payload}`),
  )

  const jwt = `${header}.${payload}.${btoa(String.fromCharCode(...new Uint8Array(sig)))}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const { access_token } = await tokenRes.json()
  return access_token
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '')
  const bin = atob(b64)
  return Uint8Array.from(bin, c => c.charCodeAt(0)).buffer
}
