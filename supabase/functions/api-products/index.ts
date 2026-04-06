// GET /api/products/:barcode
// Finds a product by barcode. Returns product + current stock.
// Auth: X-Api-Key header (scoped to lab)

import { handleCors } from '../_shared/cors.ts'
import { authenticateApiKey, adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  try {
    const labId   = await authenticateApiKey(req)
    const url     = new URL(req.url)
    const barcode = url.pathname.split('/').pop()

    if (!barcode) return errorResponse('Barcode is required', 400)

    const { data: product, error } = await adminClient
      .from('products')
      .select(`
        id, name, barcode, unit,
        reorder_point, minimum_stock, estimated_delivery_days,
        categories(name),
        locations(name),
        suppliers(name)
      `)
      .eq('lab_id', labId)
      .eq('barcode', barcode)
      .eq('is_active', true)
      .single()

    if (error || !product) return errorResponse('Product not found', 404)

    // Fetch current stock
    const { data: stock } = await adminClient
      .rpc('get_product_stock', { p_product_id: product.id })

    return jsonResponse({ ...product, current_stock: stock ?? 0 })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    const status  = message.includes('API key') ? 401 : 500
    return errorResponse(message, status)
  }
})
