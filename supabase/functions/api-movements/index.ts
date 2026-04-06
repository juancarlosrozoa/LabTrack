// POST /api/movements
// Registers a product entry or exit from an external system.
// Auth: X-Api-Key header (scoped to lab)
//
// Body: {
//   product_id: string
//   lot_id?:    string
//   type:       'entry' | 'exit' | 'adjustment' | 'return'
//   quantity:   number
//   reason?:    string
//   area?:      string
//   project?:   string
// }

import { handleCors } from '../_shared/cors.ts'
import { authenticateApiKey, adminClient, errorResponse, jsonResponse } from '../_shared/auth.ts'
import { dispatchWebhook } from '../_shared/webhook.ts'

Deno.serve(async (req: Request) => {
  const cors = handleCors(req)
  if (cors) return cors

  if (req.method !== 'POST') return errorResponse('Method not allowed', 405)

  try {
    const labId = await authenticateApiKey(req)
    const body  = await req.json()

    const { product_id, lot_id, type, quantity, reason, area, project } = body

    if (!product_id || !type || quantity == null) {
      return errorResponse('product_id, type, and quantity are required', 400)
    }

    // Verify product belongs to this lab
    const { data: product, error: productError } = await adminClient
      .from('products')
      .select('id, name, lab_id')
      .eq('id', product_id)
      .eq('lab_id', labId)
      .single()

    if (productError || !product) return errorResponse('Product not found in this lab', 404)

    // Get the lab's first admin user_id to use as the movement author
    const { data: admin } = await adminClient
      .from('lab_members')
      .select('user_id')
      .eq('lab_id', labId)
      .eq('role', 'admin')
      .limit(1)
      .single()

    if (!admin) return errorResponse('No admin found for this lab', 500)

    const { data: movement, error: movError } = await adminClient
      .from('movements')
      .insert({
        lab_id: labId,
        product_id,
        lot_id: lot_id ?? null,
        type,
        quantity,
        reason: reason ?? null,
        area:    area    ?? null,
        project: project ?? null,
        user_id: admin.user_id,
      })
      .select()
      .single()

    if (movError) throw movError

    // Fire webhook for entry
    if (type === 'entry') {
      await dispatchWebhook(labId, 'entry_registered', {
        product_id,
        product_name: product.name,
        quantity,
        lot_id: lot_id ?? null,
      })
    }

    return jsonResponse(movement, 201)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unexpected error'
    if (message.includes('API key'))    return errorResponse(message, 401)
    if (message.includes('Insufficient')) return errorResponse(message, 422)
    return errorResponse(message, 500)
  }
})
