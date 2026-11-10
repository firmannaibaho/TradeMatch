-- Allow setting item IDs to NULL in swaps table
-- This enables deleting items from the database while keeping the swap record (with snapshots)
-- Run this in Supabase SQL Editor

ALTER TABLE public.swaps ALTER COLUMN item_a_id DROP NOT NULL;
ALTER TABLE public.swaps ALTER COLUMN item_b_id DROP NOT NULL;
