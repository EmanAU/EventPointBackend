-- Create invitation_cards table if it doesn't exist.
-- Matches events.pk_event_id type (varchar).
CREATE TABLE IF NOT EXISTS invitation_cards (
    event_id VARCHAR(8) PRIMARY KEY REFERENCES events(pk_event_id) ON DELETE CASCADE,
    headline TEXT DEFAULT 'TOGETHER WITH THEIR FAMILIES',
    couple_names TEXT DEFAULT '',
    invitation_text TEXT DEFAULT 'INVITE YOU TO CELEBRATE THEIR WEDDING',
    event_date TEXT DEFAULT '',
    event_time TEXT DEFAULT '',
    description TEXT DEFAULT '',
    address TEXT DEFAULT '',
    template_id INT DEFAULT 1,
    invitation_card_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
