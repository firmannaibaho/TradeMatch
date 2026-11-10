// supabase/functions/confirm-trade/index.ts
// Handles trade confirmation logic for swaps

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const supabase = createClient(
            Deno.env.get('SUPABASE_URL')!,
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
        )

        // Verify JWT
        const authHeader = req.headers.get('Authorization')
        if (!authHeader) {
            return new Response(JSON.stringify({ error: 'Missing authorization header' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const token = authHeader.replace('Bearer ', '')
        const { data: { user }, error: authError } = await supabase.auth.getUser(token)

        if (authError || !user) {
            return new Response(JSON.stringify({ error: 'Unauthorized' }), {
                status: 401,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        const { swap_id } = await req.json()

        if (!swap_id) {
            return new Response(JSON.stringify({ error: 'swap_id is required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Get swap with items to verify participant
        const { data: swap, error: swapError } = await supabase
            .from('swaps')
            .select(`
        id, 
        status,
        user_a_id, 
        user_b_id, 
        item_a_id, 
        item_b_id,
        item_a_owner_confirmed,
        item_b_owner_confirmed,
        itemA:items!item_a_id(user_id),
        itemB:items!item_b_id(user_id)
      `)
            .eq('id', swap_id)
            .single()

        if (swapError || !swap) {
            return new Response(JSON.stringify({ error: 'Swap not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Verify user is a participant
        const isUserA = swap.user_a_id === user.id
        const isUserB = swap.user_b_id === user.id

        if (!isUserA && !isUserB) {
            return new Response(JSON.stringify({ error: 'You are not a participant in this swap' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Check valid status for confirmation
        if (!['active', 'location_agreed'].includes(swap.status)) {
            return new Response(JSON.stringify({ error: 'Swap cannot be confirmed in current status' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Update confirmation for the appropriate user
        const updateData = isUserA
            ? { item_a_owner_confirmed: true }
            : { item_b_owner_confirmed: true }

        const { data: updatedSwap, error: updateError } = await supabase
            .from('swaps')
            .update(updateData)
            .eq('id', swap_id)
            .select()
            .single()

        if (updateError) throw updateError

        // Check if both confirmed (trigger will handle status update, but we return info)
        const bothConfirmed = (isUserA && swap.item_b_owner_confirmed) ||
            (isUserB && swap.item_a_owner_confirmed)

        // If trade is now complete, save snapshots and delete items
        if (bothConfirmed) {
            console.log(`Both users confirmed! Processing trade completion for swap ${swap_id}`)

            // 1. Fetch full item data for snapshots
            const { data: itemsData } = await supabase
                .from('items')
                .select(`
                    id, title, description, condition, estimated_value, currency,
                    location_city, user_id,
                    images:item_images(image_url, display_order),
                    user:users(id, name, profile_picture_url)
                `)
                .in('id', [swap.item_a_id, swap.item_b_id])

            const itemA = itemsData?.find((i: any) => i.id === swap.item_a_id)
            const itemB = itemsData?.find((i: any) => i.id === swap.item_b_id)

            // 2. Save snapshots to swap and update status
            await supabase
                .from('swaps')
                .update({
                    status: 'trade_complete',
                    item_a_snapshot: itemA || null,
                    item_b_snapshot: itemB || null,
                    item_a_id: null,
                    item_b_id: null
                })
                .eq('id', swap_id)

            console.log(`Saved item snapshots for swap ${swap_id}`)

            // 3. Delete related records first (swipes, images, wants)
            await supabase.from('swipes').delete().eq('swiper_item_id', swap.item_a_id)
            await supabase.from('swipes').delete().eq('swiped_on_item_id', swap.item_a_id)
            await supabase.from('swipes').delete().eq('swiper_item_id', swap.item_b_id)
            await supabase.from('swipes').delete().eq('swiped_on_item_id', swap.item_b_id)

            await supabase.from('item_images').delete().in('item_id', [swap.item_a_id, swap.item_b_id])
            await supabase.from('item_wants').delete().in('item_id', [swap.item_a_id, swap.item_b_id])

            // 4. Delete items from database
            await supabase
                .from('items')
                .delete()
                .in('id', [swap.item_a_id, swap.item_b_id])

            console.log(`Trade ${swap_id} completed! Items ${swap.item_a_id} and ${swap.item_b_id} deleted from database.`)

            // CRITICAL FIX: Send notifications to BOTH users, not just the "other" user
            // This ensures both parties get the trade complete popup simultaneously
            await supabase.from('notifications').insert([
                {
                    user_id: swap.user_a_id,
                    type: 'trade_complete',
                    title: 'Trade Completed!',
                    message: 'Both parties have confirmed the trade. You can now leave a review.',
                    data: { swap_id: swap.id }
                },
                {
                    user_id: swap.user_b_id,
                    type: 'trade_complete',
                    title: 'Trade Completed!',
                    message: 'Both parties have confirmed the trade. You can now leave a review.',
                    data: { swap_id: swap.id }
                }
            ])
        }

        return new Response(JSON.stringify({
            success: true,
            swap: updatedSwap,
            trade_complete: bothConfirmed
        }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        console.error('Error in confirm-trade:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
