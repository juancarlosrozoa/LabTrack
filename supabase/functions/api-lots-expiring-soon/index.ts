// GET /api/lots/expiring-soon/:lab_id
// Returns lots expiring within `days` query param (default 90).
// Auth: X-Api-Key header (scoped to lab)

import { handleCors } from '../_shared/cors.ts'
import { authenticateApiKey, adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  try {
    const labId = await authenticateApiKey(req)
    const url   = new URL(req.url)
    const days  = parseInt(url.searchParams.get('days') ?? '90', 10)

    if (isNaN(days) || days < 1 || days > 365) {
      return errorResponse('days must be between 1 and 365', 400)
    }

    const { data, error } = await adminClient
      .from('lots_expiring_soon')
      .select('*')
      .eq('lab_id', labId)
      .lte('days_until_expiry', days)
      .order('days_until_expiry')

    if (error) throw error

    return jsonResponse({
      lab_id:          labId,
      within_days:     days,
      lots:            data ?? [],
      total:           data?.length ?? 0,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    const status  = message.includes('API key') ? 401 : 500
    return errorResponse(message, status)
  }
})
