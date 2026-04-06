// GET /api/alerts/:lab_id
// Returns active alerts: critical stock, reorder needed, expiring lots.
// Auth: X-Api-Key header (scoped to lab)

import { handleCors } from '../_shared/cors.ts'
import { authenticateApiKey, adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  try {
    const labId = await authenticateApiKey(req)

    // Stock alerts: products at or below reorder/critical thresholds
    const { data: stockAlerts, error: stockError } = await adminClient
      .from('product_stock')
      .select('product_id, name, unit, total_quantity, reorder_point, minimum_stock, stock_status')
      .eq('lab_id', labId)
      .in('stock_status', ['critical', 'reorder', 'out_of_stock'])
      .order('stock_status')

    if (stockError) throw stockError

    // Expiry alerts: lots expiring within 90 days
    const { data: expiryAlerts, error: expiryError } = await adminClient
      .from('lots_expiring_soon')
      .select('id, product_id, product_name, lot_number, quantity, unit, expiration_date, days_until_expiry')
      .eq('lab_id', labId)
      .order('days_until_expiry')

    if (expiryError) throw expiryError

    return jsonResponse({
      lab_id: labId,
      stock_alerts:  stockAlerts  ?? [],
      expiry_alerts: expiryAlerts ?? [],
      total: (stockAlerts?.length ?? 0) + (expiryAlerts?.length ?? 0),
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    const status  = message.includes('API key') ? 401 : 500
    return errorResponse(message, status)
  }
})
