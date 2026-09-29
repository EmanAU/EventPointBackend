-- Migration: Add Notifications Table
-- Purpose: Store real-time notifications for users (join requests, approvals, etc.)
-- Run after existing migrations

-- NOTE:
-- Existing EventPoint production schema uses string IDs (pk_user_id / pk_event_id),
-- not UUID columns (user_id / event_id). This migration aligns notifications with that schema.

DROP FUNCTION IF EXISTS create_notification(UUID, VARCHAR, UUID, VARCHAR, TEXT, VARCHAR, VARCHAR, UUID, VARCHAR);
DROP FUNCTION IF EXISTS get_user_notifications(UUID, INT, INT, BOOLEAN);
DROP FUNCTION IF EXISTS mark_notification_read(UUID, UUID);
DROP FUNCTION IF EXISTS mark_all_notifications_read(UUID);
DROP FUNCTION IF EXISTS get_unread_notification_count(UUID);
DROP FUNCTION IF EXISTS delete_notification(UUID, UUID);

DROP TABLE IF EXISTS notifications CASCADE;

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    notification_id VARCHAR(32) PRIMARY KEY,
    user_id VARCHAR(8) NOT NULL REFERENCES users(pk_user_id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL, -- 'JoinRequest', 'RequestApproved', etc.
    event_id VARCHAR(8) REFERENCES events(pk_event_id) ON DELETE CASCADE,
    event_title VARCHAR(255) DEFAULT '',
    image_url TEXT DEFAULT '', -- User or event image
    title VARCHAR(255) NOT NULL,
    subtitle VARCHAR(500) DEFAULT '',
    related_user_id VARCHAR(8) REFERENCES users(pk_user_id) ON DELETE CASCADE, -- Requester or approver
    related_user_name VARCHAR(255) DEFAULT '',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notifications_event_id ON notifications(event_id);

-- ============================================
-- FUNCTION: Create Notification
-- ============================================
CREATE OR REPLACE FUNCTION create_notification(
    p_user_id VARCHAR,
    p_notification_type VARCHAR,
    p_event_id VARCHAR,
    p_event_title VARCHAR,
    p_image_url TEXT,
    p_title VARCHAR,
    p_subtitle VARCHAR,
    p_related_user_id VARCHAR,
    p_related_user_name VARCHAR
)
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    v_notification_id VARCHAR(32);
BEGIN
    v_notification_id := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || CLOCK_TIMESTAMP()::TEXT) FROM 1 FOR 16));

    INSERT INTO notifications (
        notification_id,
        user_id,
        notification_type,
        event_id,
        event_title,
        image_url,
        title,
        subtitle,
        related_user_id,
        related_user_name,
        created_at
    ) VALUES (
        v_notification_id,
        p_user_id,
        p_notification_type,
        p_event_id,
        p_event_title,
        p_image_url,
        p_title,
        p_subtitle,
        p_related_user_id,
        p_related_user_name,
        NOW()
    )
    RETURNING notification_id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

-- ============================================
-- FUNCTION: Get User Notifications (with pagination)
-- ============================================
CREATE OR REPLACE FUNCTION get_user_notifications(
    p_user_id VARCHAR,
    p_page_size INT DEFAULT 20,
    p_page_number INT DEFAULT 1,
    p_unread_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    notification_id VARCHAR,
    user_id VARCHAR,
    notification_type VARCHAR,
    event_id VARCHAR,
    event_title VARCHAR,
    image_url TEXT,
    title VARCHAR,
    subtitle VARCHAR,
    related_user_id VARCHAR,
    related_user_name VARCHAR,
    is_read BOOLEAN,
    created_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_offset INT;
BEGIN
    v_offset := (p_page_number - 1) * p_page_size;
    
    RETURN QUERY
    SELECT 
        n.notification_id,
        n.user_id,
        n.notification_type,
        n.event_id,
        n.event_title,
        n.image_url,
        n.title,
        n.subtitle,
        n.related_user_id,
        n.related_user_name,
        n.is_read,
        n.created_at,
        n.read_at
    FROM notifications n
    WHERE n.user_id = p_user_id
        AND (NOT p_unread_only OR n.is_read = FALSE)
    ORDER BY n.created_at DESC
    LIMIT p_page_size
    OFFSET v_offset;
END;
$$;

-- ============================================
-- FUNCTION: Mark Notification as Read
-- ============================================
CREATE OR REPLACE FUNCTION mark_notification_read(
    p_notification_id VARCHAR,
    p_user_id VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE notifications
    SET is_read = TRUE,
        read_at = NOW()
    WHERE notification_id = p_notification_id
        AND user_id = p_user_id
        AND is_read = FALSE;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

-- ============================================
-- FUNCTION: Mark All Notifications as Read
-- ============================================
CREATE OR REPLACE FUNCTION mark_all_notifications_read(
    p_user_id VARCHAR
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INT;
BEGIN
    UPDATE notifications
    SET is_read = TRUE,
        read_at = NOW()
    WHERE user_id = p_user_id
        AND is_read = FALSE;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

-- ============================================
-- FUNCTION: Get Unread Notification Count
-- ============================================
CREATE OR REPLACE FUNCTION get_unread_notification_count(
    p_user_id VARCHAR
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM notifications
    WHERE user_id = p_user_id
        AND is_read = FALSE;
    
    RETURN v_count;
END;
$$;

-- ============================================
-- FUNCTION: Delete Old Notifications (Cleanup)
-- ============================================
CREATE OR REPLACE FUNCTION delete_old_notifications(
    p_days_old INT DEFAULT 90
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM notifications
    WHERE created_at < NOW() - (p_days_old || ' days')::INTERVAL;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

-- ============================================
-- FUNCTION: Delete Notification
-- ============================================
CREATE OR REPLACE FUNCTION delete_notification(
    p_notification_id VARCHAR,
    p_user_id VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted INT;
BEGIN
    DELETE FROM notifications
    WHERE notification_id = p_notification_id
        AND user_id = p_user_id;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE notifications IS 'Stores user notifications for real-time updates (join requests, approvals, etc.)';
COMMENT ON COLUMN notifications.notification_type IS 'Type: JoinRequest, RequestApproved, PrayerPosted, etc.';
COMMENT ON COLUMN notifications.image_url IS 'URL of user profile image or event cover image';
COMMENT ON COLUMN notifications.related_user_id IS 'ID of user who triggered the notification (requester, approver, etc.)';
