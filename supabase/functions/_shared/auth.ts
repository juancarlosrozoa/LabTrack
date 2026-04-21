import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabaseUrl  = Deno.env.get('SUPABASE_URL')!
const serviceKey   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

/** Admin client — bypasses RLS. Use only inside Edge Functions. */
export const adminClient = createClient(supabaseUrl, serviceKey)

/**
 * Authenticates an external API request via the X-Api-Key header.
 * Returns the lab_id the key belongs to, or throws on failure.
 */
export async function authenticateApiKey(req: Request): Promise<string> {
  const rawKey = req.headers.get('x-api-key')
  if (!rawKey) throw new Error('Missing X-Api-Key header')

  const keyHash = await hashKey(rawKey)

  const { data, error } = await adminClient
    .from('api_keys')
    .select('lab_id')
    .eq('key_hash', keyHash)
    .eq('is_active', true)
    .maybeSingle()

  if (error) throw new Error(`DB error: ${error.message}`)
  if (!data) throw new Error('Invalid or inactive API key')

  // Update last_used_at in background
  adminClient
    .from('api_keys')
    .update({ last_used_at: new Date().toISOString() })
    .eq('key_hash', keyHash)
    .then(() => {})

  return data.lab_id as string
}

/** sha-256 hex of the raw API key */
async function hashKey(raw: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(raw),
  )
  return Array.from(new Uint8Array(buf))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('')
}

/** Standard JSON error response */
export function errorResponse(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

/** Standard JSON success response */
export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}
