// supabase/functions/get-explore-feed/index.ts
// Returns items for the explore/swipe feed, filtering out user's own items and already swiped items

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

        // Parse query params
        const url = new URL(req.url)
        const categoryId = url.searchParams.get('category_id')
        const limit = parseInt(url.searchParams.get('limit') || '20')

        // Get user's item IDs to use as swiper_item_id reference
        const { data: userItems } = await supabase
            .from('items')
            .select('id')
            .eq('user_id', user.id)
            .eq('status', 'available')

        const userItemIds = userItems?.map(i => i.id) || []

        // Get IDs of items already swiped on
        const { data: swipedItems } = await supabase
            .from('swipes')
            .select('swiped_on_item_id')
            .in('swiper_item_id', userItemIds)

        const swipedItemIds = swipedItems?.map(s => s.swiped_on_item_id) || []

        // Build query for explore items
        let query = supabase
            .from('items')
            .select(`
        id,
        title,
        description,
        condition,
        estimated_value,
        currency,
        location_city,
        location_lat,
        location_lon,
        wants_description,
        status,
        created_at,
        updated_at,
        category:categories(id, name, icon),
        images:item_images(id, image_url, display_order),
        wants:item_wants(id, item_id, category_id, category:categories(id, name, icon)),
        user:users(id, name, profile_picture_url, rating)
      `)
            .eq('status', 'available')
            .neq('user_id', user.id) // Exclude user's own items

        // Filter by category if provided
        if (categoryId) {
            query = query.eq('category_id', parseInt(categoryId))
        }

        // Exclude already swiped items
        if (swipedItemIds.length > 0) {
            query = query.not('id', 'in', `(${swipedItemIds.join(',')})`)
        }

        // Order by newest and limit
        query = query.order('created_at', { ascending: false }).limit(limit)

        const { data: items, error: queryError } = await query

        if (queryError) throw queryError

        // SECURITY: Fuzzy location (3 decimals = ~100m precision)
        const sanitizedItems = items?.map(item => ({
            ...item,
            location_lat: item.location_lat ? Math.round(item.location_lat * 1000) / 1000 : null,
            location_lon: item.location_lon ? Math.round(item.location_lon * 1000) / 1000 : null,
            user: item.user ? {
                id: item.user.id,
                name: item.user.name,
                profile_picture_url: item.user.profile_picture_url,
                rating: item.user.rating
                // SECURITY: email, phone, google_id removed
            } : null
        })) || []

        return new Response(JSON.stringify({ items: sanitizedItems }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        console.error('Error in get-explore-feed:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
