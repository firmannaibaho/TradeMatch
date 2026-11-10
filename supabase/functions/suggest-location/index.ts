// supabase/functions/suggest-location/index.ts
// Handles location suggestion for meetups

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

        const {
            swap_id,
            location_lat,
            location_lon,
            location_name,
            location_address,
            meetup_at,     // ISO-8601 timestamp of the meetup (optional for backward compatibility)
            meetup_label,  // Human readable, client-localised date/time label (display only)
        } = await req.json()

        // Validate input
        if (!swap_id || location_lat === undefined || location_lon === undefined) {
            return new Response(JSON.stringify({ error: 'swap_id, location_lat, and location_lon are required' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Validate coordinate bounds
        if (location_lat < -90 || location_lat > 90 || location_lon < -180 || location_lon > 180) {
            return new Response(JSON.stringify({ error: 'Invalid coordinates' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Validate text lengths
        if (location_name && location_name.length > 255) {
            return new Response(JSON.stringify({ error: 'Location name too long (max 255 chars)' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        if (location_address && location_address.length > 500) {
            return new Response(JSON.stringify({ error: 'Location address too long (max 500 chars)' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Validate meetup date/time (must be a valid date, not in the past, within 1 year)
        let meetupAtIso: string | null = null
        if (meetup_at !== undefined && meetup_at !== null) {
            const meetupDate = new Date(meetup_at)
            if (isNaN(meetupDate.getTime())) {
                return new Response(JSON.stringify({ error: 'Invalid meetup_at' }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
            const now = Date.now()
            const graceMs = 15 * 60 * 1000 // tolerate small clock drift
            const maxAheadMs = 365 * 24 * 60 * 60 * 1000
            if (meetupDate.getTime() < now - graceMs || meetupDate.getTime() > now + maxAheadMs) {
                return new Response(JSON.stringify({ error: 'Meetup time must be in the future (max 1 year ahead)' }), {
                    status: 400,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
                })
            }
            meetupAtIso = meetupDate.toISOString()
        }

        if (meetup_label && String(meetup_label).length > 100) {
            return new Response(JSON.stringify({ error: 'meetup_label too long (max 100 chars)' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Get swap to verify participant
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

        // Verify user is a participant
        if (swap.user_a_id !== user.id && swap.user_b_id !== user.id) {
            return new Response(JSON.stringify({ error: 'You are not a participant in this swap' }), {
                status: 403,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Check valid status ('location_agreed' allowed so a meetup can be rescheduled)
        if (!['active', 'location_suggested', 'location_agreed'].includes(swap.status)) {
            return new Response(JSON.stringify({ error: 'Cannot suggest location in current status' }), {
                status: 400,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            })
        }

        // Update swap with location + meetup schedule
        const { data: updatedSwap, error: updateError } = await supabase
            .from('swaps')
            .update({
                status: 'location_suggested',
                suggested_location_lat: location_lat,
                suggested_location_lon: location_lon,
                suggested_location_name: location_name || null,
                suggested_location_address: location_address || null,
                location_suggested_at: new Date().toISOString(),
                location_suggested_by: user.id,
                location_agreed_at: null,
                meetup_at: meetupAtIso,
            })
            .eq('id', swap_id)
            .select()
            .single()

        if (updateError) throw updateError

        // A new/rescheduled proposal invalidates any running live-location sharing
        await supabase
            .from('meetup_live_locations')
            .update({ is_sharing: false })
            .eq('swap_id', swap_id)

        // Post the proposal into the chat so both users see it in the conversation
        const placeLabel = location_name || 'Lokasi pertemuan'
        const chatText = meetup_label
            ? `📅 Ajakan janji temu: ${placeLabel} • ${meetup_label}`
            : `Meeting location: ${placeLabel}`
        await supabase.from('messages').insert({
            swap_id: swap.id,
            sender_user_id: user.id,
            message_text: chatText.substring(0, 1000),
            type: 'location',
            location_lat,
            location_lon,
            location_name: location_name || null,
            location_address: location_address || null,
        })

        // Notify the other user
        const otherUserId = swap.user_a_id === user.id ? swap.user_b_id : swap.user_a_id

        await supabase.from('notifications').insert({
            user_id: otherUserId,
            type: 'location_suggested',
            title: meetup_label ? 'Ajakan Janji Temu' : 'Meeting Location Suggested',
            message: meetup_label
                ? `${placeLabel} • ${meetup_label}`
                : (location_name || 'A meeting location has been suggested for your trade'),
            data: { swap_id: swap.id, meetup_at: meetupAtIso }
        })

        return new Response(JSON.stringify({ success: true, swap: updatedSwap }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })

    } catch (error) {
        console.error('Error in suggest-location:', error)
        return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
    }
})
