// GET /api/inventory/:lab_id
// Returns current stock for all active products in the lab.
// Auth: X-Api-Key header (scoped to lab)

import { handleCors } from '../_shared/cors.ts'
import { authenticateApiKey, adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  try {
    const labId = await authenticateApiKey(req)

    const { data, error } = await adminClient
      .from('product_stock')       // uses the view from 001_schema.sql
      .select('*')
      .eq('lab_id', labId)
      .order('name')

    if (error) throw error

    return jsonResponse({ lab_id: labId, inventory: data })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    const status  = message.includes('API key') ? 401 : 500
    return errorResponse(message, status)
  }
})
