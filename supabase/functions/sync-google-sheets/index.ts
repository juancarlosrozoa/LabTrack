// sync-google-sheets
// Syncs current lab inventory to 4 Google Sheets tabs:
//   Stock | Expiring Soon | Movements | Restock Needed
//
// Required env vars:
//   GOOGLE_SERVICE_ACCOUNT_JSON       — service account JSON key
//   INTERNAL_FUNCTION_SECRET          — shared secret to authorize calls
//   SHEETS_ID_<lab_id_no_dashes>      — spreadsheet ID per lab

import { handleCors } from '../_shared/cors.ts'
import { adminClient, authenticateApiKey, errorResponse, jsonResponse } from '../_shared/auth.ts'

/** Accepts X-Api-Key (external REST) or Supabase JWT (Flutter app). */
async function authenticateRequest(req: Request): Promise<string> {
  if (req.headers.get('x-api-key')) {
    return await authenticateApiKey(req)
  }

  const auth = req.headers.get('authorization') ?? ''
  if (!auth.startsWith('Bearer ')) throw new Error('Unauthorized')

  const { data: { user }, error } = await adminClient.auth.getUser(
    auth.replace('Bearer ', ''),
  )
  if (error || !user) throw new Error('Unauthorized')

  const { data: membership } = await adminClient
    .from('lab_memberships')
    .select('lab_id')
    .eq('user_id', user.id)
    .maybeSingle()

  if (!membership) throw new Error('No lab membership found')
  return membership.lab_id as string
}

const SERVICE_ACCOUNT_JSON = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
const SHEETS_SCOPE         = 'https://www.googleapis.com/auth/spreadsheets'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  if (!SERVICE_ACCOUNT_JSON) {
    return errorResponse('Google service account not configured', 500)
  }

  try {
    const lab_id = await authenticateRequest(req)

    const { data: lab } = await adminClient
      .from('laboratories')
      .select('id, name')
      .eq('id', lab_id)
      .single()

    if (!lab) return errorResponse('Lab not found', 404)

    const spreadsheetId = Deno.env.get(
      `SHEETS_ID_${lab_id.replace(/-/g, '_')}`,
    )
    if (!spreadsheetId) {
      return errorResponse('No spreadsheet configured for this lab', 404)
    }

    const token = await getGoogleAccessToken()

    const [stock, expiring, movements, restock] = await Promise.all([
      fetchStock(lab_id),
      fetchExpiring(lab_id),
      fetchMovements(lab_id),
      fetchRestock(lab_id),
    ])

    await Promise.all([
      syncSheet(token, spreadsheetId, 'Stock',          buildStockRows(stock)),
      syncSheet(token, spreadsheetId, 'Expiring Soon',  buildExpiringRows(expiring)),
      syncSheet(token, spreadsheetId, 'Movements',      buildMovementRows(movements)),
      syncSheet(token, spreadsheetId, 'Restock Needed', buildRestockRows(restock)),
    ])

    return jsonResponse({ synced: true, lab_id, lab_name: lab.name })
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
    .select('id, type, quantity, reason, area, project, created_at, user_id, products(name)')
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
    .order('stock_status')
  return data ?? []
}

// ── Row builders ───────────────────────────────────────────

// deno-lint-ignore no-explicit-any
function buildStockRows(data: any[]): string[][] {
  return [
    ['Product', 'Unit', 'Total Qty', 'Reorder Point', 'Min Stock', 'Status'],
    ...data.map(r => [
      r.name, r.unit,
      String(r.total_quantity),
      String(r.reorder_point),
      String(r.minimum_stock),
      r.stock_status,
    ]),
  ]
}

// deno-lint-ignore no-explicit-any
function buildExpiringRows(data: any[]): string[][] {
  return [
    ['Product', 'Lot', 'Qty', 'Unit', 'Expiration Date', 'Days Remaining'],
    ...data.map(r => [
      r.product_name, r.lot_number,
      String(r.quantity), r.unit,
      r.expiration_date,
      String(r.days_until_expiry),
    ]),
  ]
}

// deno-lint-ignore no-explicit-any
function buildMovementRows(data: any[]): string[][] {
  return [
    ['Date', 'Type', 'Product', 'Qty', 'Reason', 'Area', 'Project', 'User ID'],
    ...data.map(r => [
      r.created_at, r.type,
      r.products?.name ?? '',
      String(r.quantity),
      r.reason ?? '', r.area ?? '', r.project ?? '',
      r.user_id,
    ]),
  ]
}

// deno-lint-ignore no-explicit-any
function buildRestockRows(data: any[]): string[][] {
  return [
    ['Product', 'Unit', 'Current Stock', 'Reorder Point', 'Status'],
    ...data.map(r => [
      r.name, r.unit,
      String(r.total_quantity),
      String(r.reorder_point),
      r.stock_status,
    ]),
  ]
}

// ── Google Sheets helpers ──────────────────────────────────

/** Clear the sheet then write all rows from A1. */
async function syncSheet(
  token: string,
  spreadsheetId: string,
  sheetName: string,
  values: string[][],
) {
  const base = `https://sheets.googleapis.com/v4/spreadsheets/${spreadsheetId}`
  const auth = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }

  // 1. Clear existing content
  await fetch(`${base}/values/${encodeURIComponent(sheetName)}:clear`, {
    method: 'POST',
    headers: auth,
  })

  // 2. Write new data
  const range = `${sheetName}!A1`
  const res = await fetch(
    `${base}/values/${encodeURIComponent(range)}?valueInputOption=RAW`,
    {
      method: 'PUT',
      headers: auth,
      body: JSON.stringify({ range, majorDimension: 'ROWS', values }),
    },
  )

  if (!res.ok) {
    const text = await res.text()
    throw new Error(`Sheets write error for "${sheetName}": ${text}`)
  }
}

// ── Google Service Account JWT auth ───────────────────────

async function getGoogleAccessToken(): Promise<string> {
  const sa  = JSON.parse(SERVICE_ACCOUNT_JSON!)
  const now = Math.floor(Date.now() / 1000)

  const header  = toBase64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const payload = toBase64Url(JSON.stringify({
    iss:   sa.client_email,
    scope: SHEETS_SCOPE,
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

  const sig = toBase64UrlBytes(new Uint8Array(sigBytes))
  const jwt = `${header}.${payload}.${sig}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  })

  const json = await res.json()
  if (!json.access_token) throw new Error(`Token error: ${JSON.stringify(json)}`)
  return json.access_token
}

/** Standard base64 → base64url (URL-safe, no padding). */
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
  const bin = atob(b64)
  return Uint8Array.from(bin, c => c.charCodeAt(0)).buffer
}
