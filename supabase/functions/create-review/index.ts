// supabase/functions/create-review/index.ts
// Handles review creation with business rule validation

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

        const { swap_id, rating, comment } = await req.json()

        // Validate input
        if (!swap_id || !rating) {
            return new Response(JSON.stringify({ error: 'swap_id and rating are required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (rating < 1 || rating > 5 || !Number.isInteger(rating)) {
            return new Response(JSON.stringify({ error: 'Rating must be an integer between 1 and 5' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (comment && comment.length > 500) {
            return new Response(JSON.stringify({ error: 'Comment too long (max 500 chars)' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Get swap to verify participant and status
        const { data: swap, error: swapError } = await supabase
            .from('swaps')
            .select('id, status, user_a_id, user_b_id')
            .eq('id', swap_id)
            .single()

        if (swapError || !swap) {
            return new Response(JSON.stringify({ error: 'Swap not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 1. Check swap is complete
        if (swap.status !== 'trade_complete') {
            return new Response(JSON.stringify({ error: 'Can only review completed trades' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 2. Check user is participant
        const isUserA = swap.user_a_id === user.id
        const isUserB = swap.user_b_id === user.id

        if (!isUserA && !isUserB) {
            return new Response(JSON.stringify({ error: 'You are not a participant in this swap' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // 3. Determine the other user (reviewed user)
        const reviewedUserId = isUserA ? swap.user_b_id : swap.user_a_id

        // 4. Check for existing review
        const { data: existingReview } = await supabase
            .from('reviews')
            .select('id')
            .eq('swap_id', swap_id)
            .eq('reviewer_user_id', user.id)
            .single()

        if (existingReview) {
            return new Response(JSON.stringify({ error: 'You have already reviewed this trade' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Create review
        const { data: review, error: insertError } = await supabase
            .from('reviews')
            .insert({
                swap_id,
                reviewer_user_id: user.id,
                reviewed_user_id: reviewedUserId,
                rating,
                comment: comment || null
            })
            .select(`
        *,
        reviewer:users!reviewer_user_id(id, name, profile_picture_url)
      `)
            .single()

        if (insertError) throw insertError

        // Rating average is updated by database trigger

        return new Response(JSON.stringify({ success: true, review }), {
            status: 201,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        console.error('Error in create-review:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
