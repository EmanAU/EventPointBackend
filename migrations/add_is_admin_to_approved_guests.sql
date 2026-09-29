-- Add IsAdmin to event_get_approved_guests so UI can show Admin badge instead of Make Admin
DROP FUNCTION IF EXISTS event_get_approved_guests(character varying, character varying);

CREATE FUNCTION event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying)
RETURNS TABLE(
    "GuestUserId" character varying,
    "GuestName" character varying,
    "GuestEmail" character varying,
    "ProfileImageUrl" text,
    "InvitedByUserId" character varying,
    "InviterName" character varying,
    "RelationshipName" character varying,
    "RelationshipTypeName" character varying,
    "ImagesUploaded" integer,
    "JoinedAt" timestamp with time zone,
    "IsAdmin" boolean
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId"
    ) AND NOT EXISTS (
        SELECT 1 FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId" AND fk_request_status_id = 2
    ) THEN
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to view this list.';
    END IF;

    RETURN QUERY
    SELECT
        u.pk_user_id AS "GuestUserId",
        u.name AS "GuestName",
        u.email AS "GuestEmail",
        u.profile_image_url AS "ProfileImageUrl",
        eg.fk_relation_to_user_id AS "InvitedByUserId",
        inviter.name AS "InviterName",
        r.relationship_name AS "RelationshipName",
        rt.relationship_type_name AS "RelationshipTypeName",
        eg.images_uploaded_number AS "ImagesUploaded",
        eg.updated_at AS "JoinedAt",
        EXISTS (SELECT 1 FROM event_admins ea WHERE ea.fk_event_id = "EventId" AND ea.fk_user_id = u.pk_user_id) AS "IsAdmin"
    FROM event_guests eg
    INNER JOIN users u ON eg.fk_user_id = u.pk_user_id
    LEFT JOIN users inviter ON eg.fk_relation_to_user_id = inviter.pk_user_id
    LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
    LEFT JOIN relationship_types rt ON eg.fk_relationship_type_id = rt.pk_relationship_type_id
    WHERE eg.fk_event_id = "EventId"
      AND eg.fk_request_status_id = 2
    ORDER BY eg.updated_at DESC;
END;
$$;
