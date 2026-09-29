-- Fix return column names for Dapper (PascalCase) so UserId/CreatorId/EventId etc. map correctly

DROP FUNCTION IF EXISTS user_create(VARCHAR, VARCHAR, VARCHAR);
CREATE OR REPLACE FUNCTION user_create(
    p_name VARCHAR,
    p_email VARCHAR,
    p_phone_number VARCHAR DEFAULT ''
)
RETURNS TABLE ("UserId" UUID, "RoleName" VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID;
    v_role_name VARCHAR;
BEGIN
    INSERT INTO users (name, email, phone_number)
    VALUES (p_name, p_email, COALESCE(p_phone_number, ''))
    RETURNING users.user_id INTO v_user_id;

    SELECT r.role_name INTO v_role_name FROM roles r
    JOIN users u ON u.role_id = r.role_id WHERE u.user_id = v_user_id;

    RETURN QUERY SELECT v_user_id, v_role_name;
END;
$$;

DROP FUNCTION IF EXISTS user_get_by_id(UUID);
CREATE OR REPLACE FUNCTION user_get_by_id(_user_id UUID)
RETURNS TABLE (
    "UserId" UUID,
    "Name" VARCHAR,
    "Email" VARCHAR,
    "RoleName" VARCHAR,
    "AccessToken" TEXT,
    "ExpiresIn" INT,
    "CreatedAt" TIMESTAMPTZ,
    "UpdatedAt" TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        u.name,
        u.email,
        r.role_name,
        ''::TEXT,
        0::INT,
        u.created_at,
        u.updated_at
    FROM users u
    JOIN roles r ON r.role_id = u.role_id
    WHERE u.user_id = _user_id;
END;
$$;

DROP FUNCTION IF EXISTS user_get_by_email(VARCHAR);
CREATE OR REPLACE FUNCTION user_get_by_email(p_user_email VARCHAR)
RETURNS TABLE (
    "UserId" UUID,
    "Name" VARCHAR,
    "Email" VARCHAR,
    "RoleName" VARCHAR,
    "AccessToken" TEXT,
    "ExpiresIn" INT,
    "CreatedAt" TIMESTAMPTZ,
    "UpdatedAt" TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.user_id,
        u.name,
        u.email,
        r.role_name,
        ''::TEXT,
        0::INT,
        u.created_at,
        u.updated_at
    FROM users u
    JOIN roles r ON r.role_id = u.role_id
    WHERE u.email = p_user_email;
END;
$$;

DROP FUNCTION IF EXISTS event_create(INT, VARCHAR, UUID, TIMESTAMPTZ, VARCHAR, TEXT, TEXT, INT, INT, VARCHAR);
CREATE OR REPLACE FUNCTION event_create(
    p_event_category_id INT,
    p_event_title VARCHAR,
    p_creator_id UUID,
    p_event_date_time TIMESTAMPTZ,
    p_venue VARCHAR DEFAULT '',
    p_event_cover_image_url TEXT DEFAULT '',
    p_tag_line TEXT DEFAULT '',
    p_expected_guest_number INT DEFAULT 0,
    p_sub_category_id INT DEFAULT NULL,
    p_location VARCHAR DEFAULT ''
)
RETURNS TABLE ("EventId" UUID, "AdminCode" VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id UUID;
    v_admin_code VARCHAR;
    v_event_code VARCHAR;
BEGIN
    IF TRIM(p_event_title) = '' THEN
        RAISE EXCEPTION 'Event title cannot be empty' USING ERRCODE = 'P0001';
    END IF;

    v_admin_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 8));
    v_event_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    INSERT INTO events (
        event_category_id, event_title, creator_id, event_date_time,
        venue, event_cover_image_url, tag_line, expected_guest_number,
        sub_category_id, location, admin_code, event_code
    )
    VALUES (
        p_event_category_id, p_event_title, p_creator_id, p_event_date_time,
        COALESCE(p_venue, ''), COALESCE(p_event_cover_image_url, ''),
        COALESCE(p_tag_line, ''), COALESCE(p_expected_guest_number, 0),
        p_sub_category_id, COALESCE(p_location, ''),
        v_admin_code, v_event_code
    )
    RETURNING events.event_id INTO v_event_id;

    INSERT INTO event_members (event_id, user_id, role)
    VALUES (v_event_id, p_creator_id, 'Admin');

    RETURN QUERY SELECT v_event_id, v_admin_code;
END;
$$;
