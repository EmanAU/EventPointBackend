-- =====================================================================
-- Pamphlet payment transactions (GoPayFast)
-- event_id and user_id are VARCHAR to match the rest of the codebase
-- (the DB uses character varying IDs, not UUID).
-- =====================================================================

-- Drop if it exists from a previous run so we can recreate cleanly.
DROP TABLE IF EXISTS pamphlet_payment_transactions CASCADE;

CREATE TABLE pamphlet_payment_transactions (
    payment_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id         VARCHAR(128) NOT NULL,
    user_id          VARCHAR(128) NOT NULL,
    basket_id        VARCHAR(64)  NOT NULL UNIQUE,
    amount           NUMERIC(10,2) NOT NULL,
    currency         VARCHAR(8)   NOT NULL DEFAULT 'PKR',
    gateway          VARCHAR(32)  NOT NULL DEFAULT 'gopayfast',
    status           VARCHAR(16)  NOT NULL DEFAULT 'pending',
    access_token     TEXT         NOT NULL DEFAULT '',
    transaction_id   VARCHAR(128) NOT NULL DEFAULT '',
    error_code       VARCHAR(32)  NOT NULL DEFAULT '',
    error_message    TEXT         NOT NULL DEFAULT '',
    customer_email   VARCHAR(255) NOT NULL DEFAULT '',
    customer_phone   VARCHAR(64)  NOT NULL DEFAULT '',
    customer_name    VARCHAR(255) NOT NULL DEFAULT '',
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at     TIMESTAMPTZ  NULL
);

CREATE INDEX IF NOT EXISTS idx_pamphlet_pay_event    ON pamphlet_payment_transactions(event_id);
CREATE INDEX IF NOT EXISTS idx_pamphlet_pay_user     ON pamphlet_payment_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_pamphlet_pay_status   ON pamphlet_payment_transactions(status);
CREATE INDEX IF NOT EXISTS idx_pamphlet_pay_basket   ON pamphlet_payment_transactions(basket_id);

-- =====================================================================
-- pamphlet_payment_create
-- =====================================================================
DROP FUNCTION IF EXISTS pamphlet_payment_create(VARCHAR, VARCHAR, VARCHAR, NUMERIC, VARCHAR, TEXT, VARCHAR, VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION pamphlet_payment_create(
    p_event_id       VARCHAR,
    p_user_id        VARCHAR,
    p_basket_id      VARCHAR,
    p_amount         NUMERIC,
    p_currency       VARCHAR,
    p_access_token   TEXT,
    p_customer_email VARCHAR,
    p_customer_phone VARCHAR,
    p_customer_name  VARCHAR
) RETURNS TABLE (
    "PaymentId"      UUID,
    "EventId"        VARCHAR,
    "UserId"         VARCHAR,
    "BasketId"       VARCHAR,
    "Amount"         NUMERIC,
    "Currency"       VARCHAR,
    "Gateway"        VARCHAR,
    "Status"         VARCHAR,
    "AccessToken"    TEXT,
    "TransactionId"  VARCHAR,
    "ErrorCode"      VARCHAR,
    "ErrorMessage"   TEXT,
    "CustomerEmail"  VARCHAR,
    "CustomerPhone"  VARCHAR,
    "CustomerName"   VARCHAR,
    "CreatedAt"      TIMESTAMPTZ,
    "UpdatedAt"      TIMESTAMPTZ,
    "CompletedAt"    TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    INSERT INTO pamphlet_payment_transactions (
        event_id, user_id, basket_id, amount, currency,
        access_token, customer_email, customer_phone, customer_name
    )
    VALUES (
        p_event_id, p_user_id, p_basket_id, p_amount, COALESCE(p_currency,'PKR'),
        COALESCE(p_access_token,''), COALESCE(p_customer_email,''),
        COALESCE(p_customer_phone,''), COALESCE(p_customer_name,'')
    )
    RETURNING
        payment_id, event_id, user_id, basket_id, amount, currency, gateway, status,
        access_token, transaction_id, error_code, error_message,
        customer_email, customer_phone, customer_name,
        created_at, updated_at, completed_at;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- pamphlet_payment_mark_completed
-- =====================================================================
DROP FUNCTION IF EXISTS pamphlet_payment_mark_completed(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION pamphlet_payment_mark_completed(
    p_basket_id      VARCHAR,
    p_transaction_id VARCHAR
) RETURNS TABLE (
    "PaymentId"      UUID,
    "EventId"        VARCHAR,
    "UserId"         VARCHAR,
    "BasketId"       VARCHAR,
    "Status"         VARCHAR,
    "TransactionId"  VARCHAR,
    "CompletedAt"    TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    UPDATE pamphlet_payment_transactions
       SET status         = 'completed',
           transaction_id = COALESCE(p_transaction_id,''),
           completed_at   = NOW(),
           updated_at     = NOW()
     WHERE basket_id = p_basket_id
       AND status IN ('pending','completed')
    RETURNING payment_id, event_id, user_id, basket_id, status, transaction_id, completed_at;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- pamphlet_payment_mark_failed
-- =====================================================================
DROP FUNCTION IF EXISTS pamphlet_payment_mark_failed(VARCHAR, VARCHAR, TEXT);

CREATE OR REPLACE FUNCTION pamphlet_payment_mark_failed(
    p_basket_id     VARCHAR,
    p_error_code    VARCHAR,
    p_error_message TEXT
) RETURNS TABLE (
    "PaymentId"     UUID,
    "BasketId"      VARCHAR,
    "Status"        VARCHAR,
    "ErrorCode"     VARCHAR,
    "ErrorMessage"  TEXT
) AS $$
BEGIN
    RETURN QUERY
    UPDATE pamphlet_payment_transactions
       SET status        = 'failed',
           error_code    = COALESCE(p_error_code,''),
           error_message = COALESCE(p_error_message,''),
           updated_at    = NOW()
     WHERE basket_id = p_basket_id
       AND status = 'pending'
    RETURNING payment_id, basket_id, status, error_code, error_message;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- pamphlet_payment_get_by_basket
-- =====================================================================
DROP FUNCTION IF EXISTS pamphlet_payment_get_by_basket(VARCHAR);

CREATE OR REPLACE FUNCTION pamphlet_payment_get_by_basket(
    p_basket_id VARCHAR
) RETURNS TABLE (
    "PaymentId"      UUID,
    "EventId"        VARCHAR,
    "UserId"         VARCHAR,
    "BasketId"       VARCHAR,
    "Amount"         NUMERIC,
    "Currency"       VARCHAR,
    "Gateway"        VARCHAR,
    "Status"         VARCHAR,
    "AccessToken"    TEXT,
    "TransactionId"  VARCHAR,
    "ErrorCode"      VARCHAR,
    "ErrorMessage"   TEXT,
    "CustomerEmail"  VARCHAR,
    "CustomerPhone"  VARCHAR,
    "CustomerName"   VARCHAR,
    "CreatedAt"      TIMESTAMPTZ,
    "UpdatedAt"      TIMESTAMPTZ,
    "CompletedAt"    TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        payment_id, event_id, user_id, basket_id, amount, currency, gateway, status,
        access_token, transaction_id, error_code, error_message,
        customer_email, customer_phone, customer_name,
        created_at, updated_at, completed_at
      FROM pamphlet_payment_transactions
     WHERE basket_id = p_basket_id
     LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- pamphlet_payment_is_unlocked
-- Returns one row with IsUnlocked=TRUE + details if payment exists,
-- or one row with IsUnlocked=FALSE otherwise.
-- =====================================================================
DROP FUNCTION IF EXISTS pamphlet_payment_is_unlocked(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION pamphlet_payment_is_unlocked(
    p_event_id VARCHAR,
    p_user_id  VARCHAR
) RETURNS TABLE (
    "IsUnlocked"   BOOLEAN,
    "PaymentId"    UUID,
    "BasketId"     VARCHAR,
    "CompletedAt"  TIMESTAMPTZ
) AS $$
DECLARE
    v_row pamphlet_payment_transactions%ROWTYPE;
BEGIN
    SELECT * INTO v_row
      FROM pamphlet_payment_transactions
     WHERE event_id = p_event_id
       AND user_id  = p_user_id
       AND status   = 'completed'
     ORDER BY completed_at DESC NULLS LAST
     LIMIT 1;

    IF FOUND THEN
        RETURN QUERY SELECT TRUE, v_row.payment_id, v_row.basket_id, v_row.completed_at;
    ELSE
        RETURN QUERY SELECT FALSE, NULL::UUID, NULL::VARCHAR, NULL::TIMESTAMPTZ;
    END IF;
END;
$$ LANGUAGE plpgsql;
