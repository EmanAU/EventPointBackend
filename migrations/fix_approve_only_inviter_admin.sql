-- Restrict approval: only the admin whose code the guest used can approve them
-- (each guest request entertained by the person whose code they came)
DROP FUNCTION IF EXISTS event_guest_approve(character varying, character varying, character varying, integer, integer);

CREATE FUNCTION event_guest_approve("AdminUserId" character varying, "TargetGuestId" character varying, "EventId" character varying, "RelationshipTypeId" integer, "RelationshipId" integer)
RETURNS TABLE("IsSuccess" boolean, "Message" character varying)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Security: Only Admins can approve
    IF NOT EXISTS (
        SELECT 1 FROM event_admins 
        WHERE fk_user_id = "AdminUserId" AND fk_event_id = "EventId"
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized: You are not an admin of this event.'::VARCHAR;
        RETURN;
    END IF;

    -- 2. Strict: Only the admin whose code the guest used can approve
    -- (fk_relation_to_user_id was set when guest joined via that admin's code)
    IF NOT EXISTS (
        SELECT 1 FROM event_guests 
        WHERE fk_user_id = "TargetGuestId" 
          AND fk_event_id = "EventId"
          AND fk_relation_to_user_id = "AdminUserId"
          AND fk_request_status_id = 1
    ) THEN
        RETURN QUERY SELECT FALSE, 'Request not found, or you cannot approve this guest (they used another admin''s code).'::VARCHAR;
        RETURN;
    END IF;

    -- 3. Update Guest Status to Accepted (2)
    UPDATE event_guests
    SET 
        fk_request_status_id = 2,
        fk_relationship_type_id = "RelationshipTypeId",
        fk_relationship_id = "RelationshipId",
        updated_at = NOW()
    WHERE fk_user_id = "TargetGuestId" 
      AND fk_event_id = "EventId"
      AND fk_relation_to_user_id = "AdminUserId";

    RETURN QUERY SELECT TRUE, 'Guest Approved Successfully'::VARCHAR;
END;
$$;
