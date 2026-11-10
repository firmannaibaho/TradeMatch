-- Add columns to swaps table to store item snapshots for history
-- Run this in Supabase SQL Editor before deploying updated confirm-trade function

-- Add snapshot columns for item A
ALTER TABLE public.swaps ADD COLUMN IF NOT EXISTS item_a_snapshot JSONB;

-- Add snapshot columns for item B  
ALTER TABLE public.swaps ADD COLUMN IF NOT EXISTS item_b_snapshot JSONB;

-- These columns will store the item data (title, description, images, etc.)
-- so that history can display items even after they are deleted
