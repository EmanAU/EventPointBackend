-- Add InviterChain for "Creator's relative's relative" display (max 3 levels)
-- e.g. "Sophia Blake's Half-brother's Colleague" for a guest invited by creator's half-brother
DROP FUNCTION IF EXISTS event_get_approved_guests(character varying, character varying);

CREATE FUNCTION event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying)
RETURNS TABLE(
    "GuestUserId" character varying,
    "GuestName" character varying,
    "GuestEmail" character varying,
    "ProfileImageUrl" text,
    "InvitedByUserId" character varying,
    "InviterName" character varying,
    "InviterChain" character varying,
    "RelationshipName" character varying,
    "RelationshipTypeName" character varying,
    "ImagesUploaded" integer,
    "JoinedAt" timestamp with time zone,
    "IsAdmin" boolean,
    "IsCreator" boolean,
    "AdminCode" character varying,
    "ColorId" integer,
    "ColorCode" character varying,
    "InviterColorCode" character varying
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
    WITH creator_rows AS (
        SELECT
            u.pk_user_id AS "GuestUserId",
            u.name AS "GuestName",
            u.email AS "GuestEmail",
            u.profile_image_url AS "ProfileImageUrl",
            NULL::VARCHAR AS "InvitedByUserId",
            NULL::VARCHAR AS "InviterName",
            NULL::VARCHAR AS "InviterChain",
            'Creator'::VARCHAR AS "RelationshipName",
            ''::VARCHAR AS "RelationshipTypeName",
            0 AS "ImagesUploaded",
            ea.created_at AS "JoinedAt",
            TRUE AS "IsAdmin",
            ea.is_creator AS "IsCreator",
            ea.admin_code AS "AdminCode",
            ea.fk_color_id AS "ColorId",
            c.color_code AS "ColorCode",
            NULL::VARCHAR AS "InviterColorCode"
        FROM event_admins ea
        INNER JOIN users u ON ea.fk_user_id = u.pk_user_id
        LEFT JOIN colors c ON ea.fk_color_id = c.pk_color_id
        WHERE ea.fk_event_id = "EventId" AND ea.is_creator = TRUE
          AND NOT EXISTS (
              SELECT 1 FROM event_guests eg
              WHERE eg.fk_event_id = "EventId" AND eg.fk_user_id = ea.fk_user_id AND eg.fk_request_status_id = 2
          )
    ),
    guest_rows AS (
        SELECT
            u.pk_user_id AS "GuestUserId",
            u.name AS "GuestName",
            u.email AS "GuestEmail",
            u.profile_image_url AS "ProfileImageUrl",
            eg.fk_relation_to_user_id AS "InvitedByUserId",
            inviter.name AS "InviterName",
            -- InviterChain: Creator's relative OR Creator's relative's relative (max 3 levels)
            CASE
                WHEN inviter_admin.is_creator = TRUE THEN 'Creator'::VARCHAR
                WHEN inviter_eg.fk_relation_to_user_id IS NOT NULL AND inviter_of_inviter.name IS NOT NULL AND inviter_rel.relationship_name IS NOT NULL
                    THEN (inviter_of_inviter.name || '''s ' || inviter_rel.relationship_name)::VARCHAR
                ELSE inviter.name
            END AS "InviterChain",
            COALESCE(r.relationship_name, CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Member' END) AS "RelationshipName",
            COALESCE(rt.relationship_type_name, '') AS "RelationshipTypeName",
            eg.images_uploaded_number AS "ImagesUploaded",
            eg.updated_at AS "JoinedAt",
            (ea.pk_event_admin_id IS NOT NULL) AS "IsAdmin",
            COALESCE(ea.is_creator, FALSE) AS "IsCreator",
            ea.admin_code AS "AdminCode",
            ea.fk_color_id AS "ColorId",
            c.color_code AS "ColorCode",
            inviter_color.color_code AS "InviterColorCode"
        FROM event_guests eg
        INNER JOIN users u ON eg.fk_user_id = u.pk_user_id
        LEFT JOIN users inviter ON eg.fk_relation_to_user_id = inviter.pk_user_id
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        LEFT JOIN relationship_types rt ON eg.fk_relationship_type_id = rt.pk_relationship_type_id
        LEFT JOIN event_admins ea ON ea.fk_event_id = "EventId" AND ea.fk_user_id = u.pk_user_id
        LEFT JOIN colors c ON ea.fk_color_id = c.pk_color_id
        LEFT JOIN event_admins inviter_admin ON inviter_admin.fk_event_id = "EventId" AND inviter_admin.fk_user_id = eg.fk_relation_to_user_id
        LEFT JOIN colors inviter_color ON inviter_admin.fk_color_id = inviter_color.pk_color_id
        -- Inviter's own guest row (to get inviter's relation to creator/their inviter)
        LEFT JOIN event_guests inviter_eg ON inviter_eg.fk_event_id = "EventId" AND inviter_eg.fk_user_id = eg.fk_relation_to_user_id AND inviter_eg.fk_request_status_id = 2
        LEFT JOIN users inviter_of_inviter ON inviter_eg.fk_relation_to_user_id = inviter_of_inviter.pk_user_id
        LEFT JOIN relationships inviter_rel ON inviter_eg.fk_relationship_id = inviter_rel.pk_relationship_id
        WHERE eg.fk_event_id = "EventId" AND eg.fk_request_status_id = 2
    )
    SELECT * FROM creator_rows
    UNION ALL
    SELECT * FROM guest_rows
    ORDER BY "IsCreator" DESC, "IsAdmin" DESC, "JoinedAt" DESC;
END;
$$;
