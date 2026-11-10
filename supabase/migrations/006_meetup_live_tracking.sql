-- ================================================================
-- 006: MEETUP SCHEDULE + LIVE LOCATION TRACKING
--
-- Flow:
--   1. One participant proposes a meetup (place + date/time) via the
--      `suggest-location` edge function  -> status 'location_suggested'
--   2. The other participant accepts via `accept-location`
--                                           -> status 'location_agreed'
--   3. On the meetup DATE, both participants may share their live GPS
--      position into `meetup_live_locations`. The partner receives the
--      updates in real time (Supabase Realtime) and sees them on a map.
--
-- The server enforces a +/-24h window around `meetup_at` (a superset of
-- "the meetup calendar day" in any timezone). The app additionally
-- restricts sharing to the meetup's local calendar day.
-- Safe to re-run (idempotent).
-- ================================================================

-- ---------------------------------------------------------------
-- SWAPS: meetup schedule
-- ---------------------------------------------------------------
ALTER TABLE public.swaps ADD COLUMN IF NOT EXISTS meetup_at TIMESTAMPTZ;
ALTER TABLE public.swaps ADD COLUMN IF NOT EXISTS location_suggested_by UUID REFERENCES public.users(id);
ALTER TABLE public.swaps ADD COLUMN IF NOT EXISTS location_agreed_at TIMESTAMPTZ;

-- ---------------------------------------------------------------
-- LIVE LOCATIONS (one row per participant per swap, upserted)
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.meetup_live_locations (
  swap_id    BIGINT NOT NULL REFERENCES public.swaps(id) ON DELETE CASCADE,
  user_id    UUID   NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  lat        DOUBLE PRECISION NOT NULL CHECK (lat BETWEEN -90 AND 90),
  lon        DOUBLE PRECISION NOT NULL CHECK (lon BETWEEN -180 AND 180),
  accuracy   DOUBLE PRECISION,
  heading    DOUBLE PRECISION,
  speed      DOUBLE PRECISION,
  is_sharing BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (swap_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_meetup_live_locations_swap ON public.meetup_live_locations(swap_id);

-- Always stamp updated_at server-side
CREATE OR REPLACE FUNCTION public.touch_meetup_live_location()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS touch_meetup_live_location ON public.meetup_live_locations;
CREATE TRIGGER touch_meetup_live_location
  BEFORE INSERT OR UPDATE ON public.meetup_live_locations
  FOR EACH ROW EXECUTE FUNCTION public.touch_meetup_live_location();

-- ---------------------------------------------------------------
-- HELPERS (SECURITY DEFINER so they can read swaps regardless of RLS)
-- ---------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_swap_participant(p_swap_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM swaps s
    WHERE s.id = p_swap_id
      AND (s.user_a_id = auth.uid() OR s.user_b_id = auth.uid())
  );
$$;

CREATE OR REPLACE FUNCTION public.can_share_meetup_location(p_swap_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM swaps s
    WHERE s.id = p_swap_id
      AND (s.user_a_id = auth.uid() OR s.user_b_id = auth.uid())
      AND s.status = 'location_agreed'
      AND s.meetup_at IS NOT NULL
      AND NOW() BETWEEN s.meetup_at - INTERVAL '24 hours'
                    AND s.meetup_at + INTERVAL '24 hours'
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_swap_participant(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_share_meetup_location(BIGINT) TO authenticated;

-- ---------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------
ALTER TABLE public.meetup_live_locations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Participants can view meetup locations" ON public.meetup_live_locations;
CREATE POLICY "Participants can view meetup locations" ON public.meetup_live_locations
  FOR SELECT USING (public.is_swap_participant(swap_id));

DROP POLICY IF EXISTS "Users share own location on meetup day" ON public.meetup_live_locations;
CREATE POLICY "Users share own location on meetup day" ON public.meetup_live_locations
  FOR INSERT
  WITH CHECK (user_id = auth.uid() AND public.can_share_meetup_location(swap_id));

-- Updating position requires the meetup window; turning sharing OFF is always allowed.
DROP POLICY IF EXISTS "Users update own location" ON public.meetup_live_locations;
CREATE POLICY "Users update own location" ON public.meetup_live_locations
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND (is_sharing = FALSE OR public.can_share_meetup_location(swap_id))
  );

DROP POLICY IF EXISTS "Users delete own location" ON public.meetup_live_locations;
CREATE POLICY "Users delete own location" ON public.meetup_live_locations
  FOR DELETE USING (user_id = auth.uid());

-- ---------------------------------------------------------------
-- REALTIME
-- ---------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'meetup_live_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.meetup_live_locations;
  END IF;
END $$;
