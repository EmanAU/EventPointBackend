-- Adds "PendingApproval" to prayer_post_or_update result so API can notify admins when a guest prayer needs approval.
-- Aligns with remove_prayer_edit.sql (insert-only, no edit path).

-- Return type change requires drop first (PostgreSQL disallows CREATE OR REPLACE across different OUT shapes).
DROP FUNCTION IF EXISTS prayer_post_or_update(character varying, character varying, text);

CREATE OR REPLACE FUNCTION prayer_post_or_update(
    "EventId" character varying,
    "UserId" character varying,
    "MessageText" text
)
RETURNS TABLE(
    "PrayerId" character varying,
    "IsSuccess" boolean,
    "Message" character varying,
    "PendingApproval" boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_existing_id VARCHAR;
    v_guest_id VARCHAR := NULL;
    v_is_authorized BOOLEAN := FALSE;
    v_is_admin BOOLEAN := FALSE;
BEGIN
    IF EXISTS (SELECT 1 FROM event_admins WHERE fk_event_id = "EventId" AND fk_user_id = "UserId") THEN
        v_is_authorized := TRUE;
        v_is_admin := TRUE;
    ELSIF EXISTS (SELECT 1 FROM event_guests WHERE fk_event_id = "EventId" AND fk_user_id = "UserId" AND fk_request_status_id = 2) THEN
        v_is_authorized := TRUE;
        SELECT pk_event_guest_id INTO v_guest_id
        FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";
    END IF;

    IF NOT v_is_authorized THEN
        RETURN QUERY SELECT NULL::VARCHAR, FALSE, 'Unauthorized: You must be an admin or approved guest to post.'::VARCHAR, FALSE;
        RETURN;
    END IF;

    SELECT pk_event_prayer_id INTO v_existing_id
    FROM event_prayers
    WHERE fk_event_id = "EventId" AND fk_user_id = "UserId";

    IF v_existing_id IS NOT NULL THEN
        RETURN QUERY SELECT v_existing_id, FALSE, 'You already have a prayer. Delete it first to post a new one.'::VARCHAR, FALSE;
        RETURN;
    END IF;

    INSERT INTO event_prayers (
        fk_event_id,
        fk_user_id,
        fk_guest_id,
        prayer_message,
        is_approved,
        created_at
    )
    VALUES (
        "EventId",
        "UserId",
        v_guest_id,
        TRIM("MessageText"),
        v_is_admin,
        NOW()
    )
    RETURNING pk_event_prayer_id INTO v_existing_id;

    -- Guest posts need admin approval (is_approved = FALSE); admins auto-approved.
    RETURN QUERY SELECT v_existing_id, TRUE, 'Prayer posted successfully.'::VARCHAR, (NOT v_is_admin);
END;
$$;
