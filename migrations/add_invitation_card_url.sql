-- Add invitation_card_url to invitation_cards table
-- Stores URL of uploaded invitation card image
ALTER TABLE invitation_cards ADD COLUMN IF NOT EXISTS invitation_card_url TEXT DEFAULT '';
