#!/bin/bash

# Migration Script for Notifications Feature
# Run this script to add the notifications table and functions to the database

echo "===================="
echo "EventPoint - Add Notifications Table"
echo "===================="
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null
then
    echo "Error: psql command not found. Please install PostgreSQL client."
    exit 1
fi

# Get database connection string from appsettings.json or use default
DB_HOST="${DB_HOST:-ep-dry-butterfly-a4ndkt27.us-east-1.aws.neon.tech}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-verceldb}"
DB_USER="${DB_USER:-default}"
DB_PASSWORD="${DB_PASSWORD:-hfsveANi5k1K}"

echo "Database: $DB_NAME"
echo "Host: $DB_HOST"
echo ""

# Connection string
CONN_STRING="postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME?sslmode=require"

echo "Running migration: add_notifications_table.sql"
echo "----------------------------------------"

psql "$CONN_STRING" -f add_notifications_table.sql

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Migration completed successfully!"
    echo ""
    echo "Notifications table created with:"
    echo "  - notifications table"
    echo "  - create_notification() function"
    echo "  - get_user_notifications() function"
    echo "  - mark_notification_read() function"
    echo "  - mark_all_notifications_read() function"
    echo "  - get_unread_notification_count() function"
    echo "  - delete_notification() function"
    echo "  - delete_old_notifications() function"
else
    echo ""
    echo "❌ Migration failed!"
    echo "Check the error messages above for details."
    exit 1
fi
