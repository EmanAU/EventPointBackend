-- Add ColorId to event_admin_promote so creator can assign admin color when promoting
-- Run after full_restore. Drops old 3-param version and creates 4-param version.

DROP FUNCTION IF EXISTS event_admin_promote(character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION event_admin_promote(
    "CreatorUserId" character varying,
    "TargetGuestUserId" character varying,
    "EventId" character varying,
    "ColorId" integer DEFAULT 1
)
RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
DECLARE
    v_admin_code VARCHAR;
    v_color_id INT := COALESCE("ColorId", 1);
BEGIN
    -- 1. Security: Only Creator can promote
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "CreatorUserId" AND is_creator = TRUE
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: Only the event creator can promote admins.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Target must be an accepted guest
    IF NOT EXISTS (
        SELECT 1 FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "TargetGuestUserId" AND fk_request_status_id = 2
    ) THEN
        RETURN QUERY SELECT FALSE, 'Target must be an accepted guest first.'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Already admin?
    IF EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "TargetGuestUserId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'User is already an admin.'::VARCHAR;
        RETURN;
    END IF;

    -- 4. Validate color exists
    IF NOT EXISTS (SELECT 1 FROM colors WHERE pk_color_id = v_color_id) THEN
        v_color_id := 1;
    END IF;

    -- 5. Generate admin code and insert
    v_admin_code := generate_random_id(6);
    INSERT INTO event_admins (fk_user_id, fk_event_id, admin_code, is_creator, fk_color_id, created_at)
    VALUES ("TargetGuestUserId", "EventId", v_admin_code, FALSE, v_color_id, NOW());

    RETURN QUERY SELECT TRUE, 'Admin promoted successfully.'::VARCHAR;
END;
$$;
