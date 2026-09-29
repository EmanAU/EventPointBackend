-- Fix: Return UserId as TEXT so Dapper can map to string (avoids "Error parsing column 0 - Guid")

DROP FUNCTION IF EXISTS user_create(VARCHAR, VARCHAR, VARCHAR);
CREATE OR REPLACE FUNCTION user_create(
    p_name VARCHAR,
    p_email VARCHAR,
    p_phone_number VARCHAR DEFAULT ''
)
RETURNS TABLE ("UserId" TEXT, "RoleName" VARCHAR)
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

    RETURN QUERY SELECT v_user_id::TEXT, v_role_name;
END;
$$;

DROP FUNCTION IF EXISTS user_get_by_id(UUID);
CREATE OR REPLACE FUNCTION user_get_by_id(_user_id UUID)
RETURNS TABLE (
    "UserId" TEXT,
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
        u.user_id::TEXT,
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
    "UserId" TEXT,
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
        u.user_id::TEXT,
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
