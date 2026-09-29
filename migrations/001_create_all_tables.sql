-- EventPointApi - Full Schema Creation
-- Run: psql "Host=ep-dry-butterfly-a4ndkt27.us-east-1.aws.neon.tech;Port=5432;Database=verceldb;Username=default;Password=hfsveANi5k1K;SSL Mode=Require" -f 001_create_all_tables.sql

-- ============================================
-- ROLES (reference for user roles)
-- ============================================
CREATE TABLE IF NOT EXISTS roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO roles (role_name) VALUES ('User'), ('Admin') ON CONFLICT (role_name) DO NOTHING;

-- ============================================
-- USERS
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone_number VARCHAR(50) DEFAULT '',
    role_id INT NOT NULL DEFAULT 1 REFERENCES roles(role_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================
-- EVENT CATEGORIES
-- ============================================
CREATE TABLE IF NOT EXISTS event_categories (
    event_category_id SERIAL PRIMARY KEY,
    event_category_name VARCHAR(100) NOT NULL
);

-- ============================================
-- SUB CATEGORIES
-- ============================================
CREATE TABLE IF NOT EXISTS sub_categories (
    sub_category_id SERIAL PRIMARY KEY,
    event_category_id INT NOT NULL REFERENCES event_categories(event_category_id),
    sub_category_name VARCHAR(100) NOT NULL
);

-- ============================================
-- EVENTS
-- ============================================
CREATE TABLE IF NOT EXISTS events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_title VARCHAR(255) NOT NULL,
    tag_line TEXT DEFAULT '',
    event_date_time TIMESTAMPTZ NOT NULL,
    venue VARCHAR(255) DEFAULT '',
    location VARCHAR(255) DEFAULT '',
    event_code VARCHAR(20) UNIQUE,
    admin_code VARCHAR(20) UNIQUE NOT NULL,
    event_category_id INT NOT NULL REFERENCES event_categories(event_category_id),
    sub_category_id INT REFERENCES sub_categories(sub_category_id),
    expected_guest_number INT DEFAULT 0,
    event_cover_image_url TEXT DEFAULT '',
    creator_id UUID NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_creator ON events(creator_id);
CREATE INDEX IF NOT EXISTS idx_events_code ON events(event_code);
CREATE INDEX IF NOT EXISTS idx_events_admin_code ON events(admin_code);

-- ============================================
-- EVENT MEMBER ROLES
-- ============================================
CREATE TABLE IF NOT EXISTS event_member_roles (
    role_id SERIAL PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE
);

INSERT INTO event_member_roles (role_name) VALUES ('Admin'), ('Member'), ('Guest'), ('Pending') ON CONFLICT (role_name) DO NOTHING;

-- ============================================
-- EVENT MEMBERS (users in events with roles)
-- ============================================
CREATE TABLE IF NOT EXISTS event_members (
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'Member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_event_members_user ON event_members(user_id);

-- ============================================
-- EVENT JOIN REQUESTS (pending join requests)
-- ============================================
CREATE TABLE IF NOT EXISTS event_join_requests (
    request_id SERIAL PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_join_requests_event ON event_join_requests(event_id);

-- ============================================
-- RELATIONSHIP TYPES (for guest approval)
-- ============================================
CREATE TABLE IF NOT EXISTS relationship_types (
    relationship_type_id SERIAL PRIMARY KEY,
    relationship_type_name VARCHAR(100) NOT NULL
);

INSERT INTO relationship_types (relationship_type_name) VALUES ('Friend'), ('Family'), ('Colleague'), ('Other') ON CONFLICT DO NOTHING;

-- ============================================
-- RELATIONSHIPS (guest relationships to event)
-- ============================================
CREATE TABLE IF NOT EXISTS relationships (
    relationship_id SERIAL PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    relationship_type_id INT NOT NULL REFERENCES relationship_types(relationship_type_id),
    status VARCHAR(20) DEFAULT 'Pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(event_id, user_id)
);

-- ============================================
-- FUNCTIONS
-- ============================================

-- user_create (PascalCase return columns for Dapper)
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

-- user_check_if_exist
CREATE OR REPLACE FUNCTION user_check_if_exist(p_email VARCHAR)
RETURNS TABLE (user_id UUID, is_exist BOOLEAN)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT u.user_id, TRUE
    FROM users u
    WHERE u.email = p_email
    LIMIT 1;
END;
$$;

-- user_get_by_id (PascalCase for Dapper, UserId as TEXT for string mapping)
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

-- user_get_by_email (PascalCase for Dapper, UserId as TEXT for string mapping)
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

-- event_create (TEXT/TIMESTAMP params match Npgsql sent types; cast to UUID/TIMESTAMPTZ inside)
CREATE OR REPLACE FUNCTION event_create(
    p_event_category_id INT,
    p_event_title TEXT,
    p_creator_id TEXT,
    p_event_date_time TIMESTAMP,
    p_venue TEXT DEFAULT '',
    p_event_cover_image_url TEXT DEFAULT '',
    p_tag_line TEXT DEFAULT '',
    p_expected_guest_number INT DEFAULT 0,
    p_sub_category_id INT DEFAULT NULL,
    p_location TEXT DEFAULT ''
)
RETURNS TABLE ("EventId" TEXT, "AdminCode" TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id UUID;
    v_admin_code VARCHAR;
    v_event_code VARCHAR;
    v_creator_uuid UUID;
BEGIN
    IF TRIM(p_event_title) = '' THEN
        RAISE EXCEPTION 'Event title cannot be empty' USING ERRCODE = 'P0001';
    END IF;

    v_creator_uuid := p_creator_id::UUID;

    v_admin_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 8));
    v_event_code := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    INSERT INTO events (
        event_category_id, event_title, creator_id, event_date_time,
        venue, event_cover_image_url, tag_line, expected_guest_number,
        sub_category_id, location, admin_code, event_code
    )
    VALUES (
        p_event_category_id, p_event_title, v_creator_uuid, p_event_date_time::TIMESTAMPTZ,
        COALESCE(p_venue, ''), COALESCE(p_event_cover_image_url, ''),
        COALESCE(p_tag_line, ''), COALESCE(p_expected_guest_number, 0),
        p_sub_category_id, COALESCE(p_location, ''),
        v_admin_code, v_event_code
    )
    RETURNING events.event_id INTO v_event_id;

    INSERT INTO event_members (event_id, user_id, role)
    VALUES (v_event_id, v_creator_uuid, 'Admin');

    RETURN QUERY SELECT v_event_id::TEXT, v_admin_code::TEXT;
END;
$$;

-- event_join_request_by_code
CREATE OR REPLACE FUNCTION event_join_request_by_code(
    p_admin_code VARCHAR,
    p_user_id UUID
)
RETURNS TABLE (event_id UUID, status VARCHAR, message TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event_id UUID;
BEGIN
    SELECT e.event_id INTO v_event_id
    FROM events e
    WHERE e.admin_code = p_admin_code;

    IF v_event_id IS NULL THEN
        RAISE EXCEPTION 'Invalid Event Code provided.' USING ERRCODE = 'P0001';
    END IF;

    IF EXISTS (SELECT 1 FROM event_members em WHERE em.event_id = v_event_id AND em.user_id = p_user_id) THEN
        RETURN QUERY SELECT v_event_id, 'AlreadyMember'::VARCHAR, 'You are already a member.'::TEXT;
        RETURN;
    END IF;

    INSERT INTO event_join_requests (event_id, user_id, status)
    VALUES (v_event_id, p_user_id, 'Pending')
    ON CONFLICT (event_id, user_id) DO NOTHING;

    RETURN QUERY SELECT v_event_id, 'Pending'::VARCHAR, 'Join request submitted.'::TEXT;
END;
$$;

-- event_get_pending_requests
CREATE OR REPLACE FUNCTION event_get_pending_requests(
    p_admin_user_id UUID,
    p_event_id UUID
)
RETURNS TABLE (
    guest_user_id UUID,
    guest_name VARCHAR,
    request_time TIMESTAMPTZ,
    status VARCHAR,
    guest_email VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM event_members em
        WHERE em.event_id = p_event_id AND em.user_id = p_admin_user_id AND em.role = 'Admin'
    ) THEN
        RAISE EXCEPTION 'Unauthorized' USING ERRCODE = 'P0001';
    END IF;

    RETURN QUERY
    SELECT
        u.user_id AS guest_user_id,
        u.name AS guest_name,
        ejr.requested_at AS request_time,
        ejr.status,
        u.email AS guest_email
    FROM event_join_requests ejr
    JOIN users u ON u.user_id = ejr.user_id
    WHERE ejr.event_id = p_event_id AND ejr.status = 'Pending';
END;
$$;

-- event_guest_approve
CREATE OR REPLACE FUNCTION event_guest_approve(
    p_admin_user_id UUID,
    p_target_guest_id UUID,
    p_event_id UUID,
    p_relationship_type_id INT,
    p_relationship_id INT DEFAULT NULL
)
RETURNS TABLE (is_success BOOLEAN, message TEXT)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM event_members em
        WHERE em.event_id = p_event_id AND em.user_id = p_admin_user_id AND em.role = 'Admin'
    ) THEN
        RETURN QUERY SELECT FALSE, 'Unauthorized'::TEXT;
        RETURN;
    END IF;

    INSERT INTO event_members (event_id, user_id, role)
    VALUES (p_event_id, p_target_guest_id, 'Guest')
    ON CONFLICT (event_id, user_id) DO UPDATE SET role = 'Guest';

    DELETE FROM event_join_requests
    WHERE event_id = p_event_id AND user_id = p_target_guest_id;

    INSERT INTO relationships (event_id, user_id, relationship_type_id, status)
    VALUES (p_event_id, p_target_guest_id, p_relationship_type_id, 'Approved')
    ON CONFLICT (event_id, user_id) DO UPDATE SET status = 'Approved', relationship_type_id = p_relationship_type_id;

    RETURN QUERY SELECT TRUE, 'Guest approved successfully.'::TEXT;
END;
$$;

-- categories_get (column aliases for Dapper PascalCase mapping)
CREATE OR REPLACE FUNCTION categories_get()
RETURNS TABLE ("EventCategoryId" INT, "EventCategoryName" VARCHAR)
LANGUAGE sql
AS $$
    SELECT event_category_id, event_category_name FROM event_categories;
$$;

-- sub_category_get_by_category_id (column aliases for Dapper PascalCase mapping)
CREATE OR REPLACE FUNCTION sub_category_get_by_category_id(p_category_id INT)
RETURNS TABLE ("SubCategoryId" INT, "EventCategoryId" INT, "SubCategoryName" VARCHAR)
LANGUAGE sql
AS $$
    SELECT sub_category_id, event_category_id, sub_category_name
    FROM sub_categories
    WHERE event_category_id = p_category_id;
$$;

-- Seed sample categories and sub-categories (run only if empty)
INSERT INTO event_categories (event_category_name)
SELECT v FROM (VALUES ('Conference'), ('Wedding'), ('Birthday'), ('Corporate'), ('Social')) AS t(v)
WHERE NOT EXISTS (SELECT 1 FROM event_categories LIMIT 1);

INSERT INTO sub_categories (event_category_id, sub_category_name)
SELECT ec.event_category_id, 'General'
FROM event_categories ec
WHERE ec.event_category_name = 'Conference'
  AND NOT EXISTS (SELECT 1 FROM sub_categories WHERE event_category_id = ec.event_category_id LIMIT 1);
