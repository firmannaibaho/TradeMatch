// supabase/functions/accept-location/index.ts
// Handles accepting a suggested location

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

        // Get swap to verify participant
        const { data: swap, error: swapError } = await supabase
            .from('swaps')
            .select('id, status, user_a_id, user_b_id, location_suggested_by, meetup_at, suggested_location_name')
            .eq('id', swap_id)
            .single()

        if (swapError || !swap) {
            return new Response(JSON.stringify({ error: 'Swap not found' }), {
                status: 404,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Verify user is a participant
        if (swap.user_a_id !== user.id && swap.user_b_id !== user.id) {
            return new Response(JSON.stringify({ error: 'You are not a participant in this swap' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Check valid status
        if (swap.status !== 'location_suggested') {
            return new Response(JSON.stringify({ error: 'No location has been suggested' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // The proposer cannot accept their own proposal
        if (swap.location_suggested_by && swap.location_suggested_by === user.id) {
            return new Response(JSON.stringify({ error: 'Waiting for your partner to accept this proposal' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Update swap status
        const { data: updatedSwap, error: updateError } = await supabase
            .from('swaps')
            .update({ status: 'location_agreed', location_agreed_at: new Date().toISOString() })
            .eq('id', swap_id)
            .select()
            .single()

        if (updateError) throw updateError

        // System message in chat (rendered as a green "agreement" pill by the app)
        await supabase.from('messages').insert({
            swap_id: swap.id,
            sender_user_id: user.id,
            message_text: swap.meetup_at
                ? 'Janji temu disepakati! Pelacakan lokasi aktif di hari H.'
                : 'Location agreed!',
            type: 'location_agreement',
        })

        // Notify the other user
        const otherUserId = swap.user_a_id === user.id ? swap.user_b_id : swap.user_a_id

        await supabase.from('notifications').insert({
            user_id: otherUserId,
            type: 'location_accepted',
            title: swap.meetup_at ? 'Janji Temu Disepakati' : 'Location Accepted',
            message: swap.meetup_at
                ? `Ajakan janji temu di ${swap.suggested_location_name || 'lokasi pilihanmu'} diterima!`
                : 'Your suggested meeting location has been accepted!',
            data: { swap_id: swap.id, meetup_at: swap.meetup_at }
        })

        return new Response(JSON.stringify({ success: true, swap: updatedSwap }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        console.error('Error in accept-location:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
