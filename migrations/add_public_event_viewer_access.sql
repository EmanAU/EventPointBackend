-- Allow public event viewers to access:
-- 1. event_get_approved_guests: Allow when event is public (fk_event_privacy_id = 1)
-- 2. GetEventDetail: Handled in EventDAL.cs - returns public events for non-members with Role='Viewer'

-- event_get_approved_guests: Allow public event viewers
DROP FUNCTION IF EXISTS event_get_approved_guests(character varying, character varying);

CREATE FUNCTION event_get_approved_guests("EventId" character varying, "RequestingUserId" character varying)
RETURNS TABLE(
    "GuestUserId" character varying,
    "GuestName" character varying,
    "GuestCity" character varying,
    "GuestCountry" character varying,
    "ProfileImageUrl" text,
    "InvitedByUserId" character varying,
    "InviterName" character varying,
    "InviterChain" character varying,
    "RelationshipName" character varying,
    "RelationshipPath" character varying,
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
DECLARE
    v_creator_id VARCHAR;
    v_creator_name VARCHAR;
    v_event_privacy_id INT;
    v_is_member BOOLEAN := FALSE;
BEGIN
    SELECT e.fk_event_privacy_id INTO v_event_privacy_id
    FROM events e WHERE e.pk_event_id = "EventId";

    IF EXISTS (
        SELECT 1 FROM event_admins
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId"
    ) OR EXISTS (
        SELECT 1 FROM event_guests
        WHERE fk_event_id = "EventId" AND fk_user_id = "RequestingUserId" AND fk_request_status_id = 2
    ) THEN
        v_is_member := TRUE;
    END IF;

    -- Allow: member OR (public event)
    IF NOT v_is_member AND (v_event_privacy_id IS NULL OR v_event_privacy_id != 1) THEN
        RAISE EXCEPTION 'Unauthorized: You must be an admin or an approved guest to view this list.';
    END IF;

    SELECT e.fk_creator_id, u.name
    INTO v_creator_id, v_creator_name
    FROM events e
    INNER JOIN users u ON u.pk_user_id = e.fk_creator_id
    WHERE e.pk_event_id = "EventId";

    RETURN QUERY
    WITH RECURSIVE relationship_paths AS (
        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            ARRAY[eg.fk_user_id]::VARCHAR[] AS visited_user_ids,
            COALESCE(r.relationship_name, '')::VARCHAR AS direct_relationship_name,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (v_creator_name || '''s ' || r.relationship_name)::VARCHAR
                ELSE v_creator_name::VARCHAR
            END AS relationship_path
        FROM event_guests eg
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND eg.fk_relation_to_user_id = v_creator_id

        UNION ALL

        SELECT
            eg.fk_user_id AS user_id,
            eg.fk_relation_to_user_id AS inviter_user_id,
            rp.visited_user_ids || eg.fk_user_id,
            COALESCE(r.relationship_name, '')::VARCHAR AS direct_relationship_name,
            CASE
                WHEN COALESCE(r.relationship_name, '') <> ''
                    THEN (rp.relationship_path || '''s ' || r.relationship_name)::VARCHAR
                ELSE rp.relationship_path
            END AS relationship_path
        FROM event_guests eg
        INNER JOIN relationship_paths rp ON rp.user_id = eg.fk_relation_to_user_id
        LEFT JOIN relationships r ON eg.fk_relationship_id = r.pk_relationship_id
        WHERE eg.fk_event_id = "EventId"
          AND eg.fk_request_status_id = 2
          AND NOT eg.fk_user_id = ANY(rp.visited_user_ids)
    ),
    creator_rows AS (
        SELECT
            u.pk_user_id AS "GuestUserId",
            u.name AS "GuestName",
            COALESCE(u.city, '')::VARCHAR AS "GuestCity",
            COALESCE(u.country, '')::VARCHAR AS "GuestCountry",
            u.profile_image_url AS "ProfileImageUrl",
            NULL::VARCHAR AS "InvitedByUserId",
            NULL::VARCHAR AS "InviterName",
            NULL::VARCHAR AS "InviterChain",
            'Creator'::VARCHAR AS "RelationshipName",
            ''::VARCHAR AS "RelationshipPath",
            ''::VARCHAR AS "RelationshipTypeName",
            0 AS "ImagesUploaded",
            ea.created_at AS "JoinedAt",
            TRUE AS "IsAdmin",
            ea.is_creator AS "IsCreator",
            CASE WHEN v_is_member THEN ea.admin_code ELSE ''::VARCHAR END AS "AdminCode",
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
            COALESCE(u.city, '')::VARCHAR AS "GuestCity",
            COALESCE(u.country, '')::VARCHAR AS "GuestCountry",
            u.profile_image_url AS "ProfileImageUrl",
            eg.fk_relation_to_user_id AS "InvitedByUserId",
            inviter.name AS "InviterName",
            COALESCE(
                inviter_path.relationship_path,
                CASE
                    WHEN inviter_admin.is_creator = TRUE THEN inviter.name::VARCHAR
                    ELSE inviter.name::VARCHAR
                END
            ) AS "InviterChain",
            COALESCE(r.relationship_name, CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Member' END) AS "RelationshipName",
            COALESCE(
                guest_path.relationship_path,
                CASE
                    WHEN inviter.name IS NOT NULL AND COALESCE(r.relationship_name, '') <> ''
                        THEN (inviter.name || '''s ' || r.relationship_name)::VARCHAR
                    ELSE COALESCE(r.relationship_name, CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Member' END)
                END
            ) AS "RelationshipPath",
            COALESCE(rt.relationship_type_name, '') AS "RelationshipTypeName",
            eg.images_uploaded_number AS "ImagesUploaded",
            eg.updated_at AS "JoinedAt",
            (ea.pk_event_admin_id IS NOT NULL) AS "IsAdmin",
            COALESCE(ea.is_creator, FALSE) AS "IsCreator",
            CASE WHEN v_is_member THEN ea.admin_code ELSE ''::VARCHAR END AS "AdminCode",
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
        LEFT JOIN relationship_paths guest_path ON guest_path.user_id = eg.fk_user_id
        LEFT JOIN relationship_paths inviter_path ON inviter_path.user_id = eg.fk_relation_to_user_id
        WHERE eg.fk_event_id = "EventId" AND eg.fk_request_status_id = 2
    )
    SELECT * FROM creator_rows
    UNION ALL
    SELECT * FROM guest_rows
    ORDER BY "IsCreator" DESC, "IsAdmin" DESC, "JoinedAt" DESC;
END;
$$;
