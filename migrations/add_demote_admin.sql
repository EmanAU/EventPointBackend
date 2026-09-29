-- Demote an admin back to a regular guest (creator only).
-- Removes the row from event_admins but keeps the user in event_guests.
CREATE OR REPLACE FUNCTION event_admin_demote(
    "CreatorUserId" character varying,
    "TargetAdminUserId" character varying,
    "EventId" character varying
)
RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Only the creator can demote
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId"
          AND fk_user_id = "CreatorUserId"
          AND is_creator = TRUE
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: Only the event creator can demote admins.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Cannot demote yourself (the creator)
    IF "TargetAdminUserId" = "CreatorUserId" THEN
        RETURN QUERY SELECT FALSE, 'The creator cannot be demoted.'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Target must actually be an admin
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId"
          AND fk_user_id = "TargetAdminUserId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Target user is not an admin of this event.'::VARCHAR;
        RETURN;
    END IF;

    -- 4. Remove from admins only (keep in guests)
    DELETE FROM event_admins
    WHERE fk_user_id = "TargetAdminUserId"
      AND fk_event_id = "EventId";

    RETURN QUERY SELECT TRUE, 'Admin demoted successfully.'::VARCHAR;
END;
$$;
