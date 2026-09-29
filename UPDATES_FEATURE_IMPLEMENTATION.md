# Updates Feature - SignalR Real-Time Notifications

## Overview
Implemented a real-time notification system using SignalR for the EventPoint application. Users receive instant notifications for:
1. **Join Requests** - Admins are notified when someone requests to join their event
2. **Request Approvals** - Users are notified when their join request is accepted

## Backend Implementation

### Files Created

#### SignalR Hub & Notifier
1. **UpdatesHub.cs** (`ApiControllers/Hubs/UpdatesHub.cs`)
   - SignalR hub at `/hubs/updates`
   - Methods: `JoinUserGroup(userId)`, `LeaveUserGroup(userId)`
   - Requires JWT authorization

2. **IUpdatesHubNotifier.cs** (`ApiControllers/Services/IUpdatesHubNotifier.cs`)
   - Interface for sending notifications
   - Methods: `NotifyJoinRequestReceived`, `NotifyRequestApproved`

3. **UpdatesHubNotifier.cs** (`ApiControllers/Services/UpdatesHubNotifier.cs`)
   - Implementation of IUpdatesHubNotifier
   - Sends SignalR messages AND saves to database
   - Dual notification strategy (real-time + persistent)

#### Database Layer
4. **NotificationModel.cs** (`Models/Notification/NotificationModel.cs`)
   - Notification entity model

5. **GetNotificationsRequest.cs** (`Models/Notification/GetNotificationsRequest.cs`)
   - Request model with pagination

6. **MarkNotificationReadRequest.cs** (`Models/Notification/MarkNotificationReadRequest.cs`)
   - Request model for marking as read

7. **NotificationDAL.cs** (`DAL/NotificationDAL.cs`)
   - Data access layer for notifications
   - Methods: Create, Get, MarkRead, MarkAllRead, GetCount, Delete

8. **INotificationService.cs** (`IServices/INotificationService.cs`)
   - Service interface

9. **NotificationService.cs** (`Services/NotificationService.cs`)
   - Service implementation

#### API Controller
10. **NotificationController.cs** (`ApiControllers/Controllers/NotificationController.cs`)
    - REST API endpoints for notifications
    - GET /api/notification
    - GET /api/notification/unread-count
    - POST /api/notification/mark-read
    - POST /api/notification/mark-all-read
    - DELETE /api/notification/{id}

#### Database Migration
11. **add_notifications_table.sql** (`migrations/add_notifications_table.sql`)
    - Creates notifications table
    - Creates all database functions
    - Adds indexes for performance

12. **run_notifications_migration.sh** (`migrations/run_notifications_migration.sh`)
    - Bash script to run the migration

### Files Modified

13. **Program.cs** (`ApiControllers/Program.cs`)
    - Registered `INotificationService` as scoped
    - Registered `IUpdatesHubNotifier` as singleton
    - Mapped UpdatesHub to `/hubs/updates` route

14. **EventController.cs** (`ApiControllers/Controllers/EventController.cs`)
    - Modified `JoinEventAsync` endpoint
    - Sends notification when join request is created
    - Notification saved to DB and sent via SignalR

15. **GuestController.cs** (`ApiControllers/Controllers/GuestController.cs`)
    - Modified `ApproveGuestAsync` endpoint
    - Sends notification when guest is approved
    - Notification saved to DB and sent via SignalR

## SignalR Events

### JoinRequestReceived
**Sent to:** Admin (event creator/owner)
**Triggered when:** User submits join request via admin code
**Payload:**
```json
{
  "notificationId": "eventId_userId_timestamp",
  "eventId": "guid",
  "eventTitle": "Event Name",
  "requesterId": "guid",
  "requesterName": "User Name",
  "requesterImageUrl": "https://...",
  "createdAt": "2026-04-07T20:00:00Z"
}
```

### RequestApproved
**Sent to:** User who requested to join
**Triggered when:** Admin approves the join request
**Payload:**
```json
{
  "notificationId": "eventId_userId_timestamp",
  "eventId": "guid",
  "eventTitle": "Event Name",
  "eventImageUrl": "https://...",
  "approverId": "guid",
  "approverName": "Admin Name",
  "createdAt": "2026-04-07T20:00:00Z"
}
```

## Client Implementation (Flutter)

### Models
- `UpdateNotificationModel` - Represents a notification
- `UpdateType` enum - joinRequest, requestAccepted

### Services
- `UpdatesSignalRService` - Singleton service managing SignalR connection
  - Connects to `/hubs/updates`
  - Persists notifications to SharedPreferences
  - Provides ValueNotifiers for reactive UI
  - Auto-reconnect on connection loss

### UI
- `UpdatesPage` - Main notification list (Facebook/LinkedIn style)
- `UpdateTile` - Individual notification item with avatar, title, time, swipe-to-dismiss
- Badge on bottom navigation showing unread count

## Testing

### Manual Testing
1. **Build & Run Backend:**
   ```bash
   cd /Users/mac138/Documents/Code/ep/EventPointApi/ApiControllers
   dotnet run
   ```

2. **Test Join Request Flow:**
   - User A creates an event (receives admin code)
   - User B joins with admin code
   - User A should receive real-time notification in Updates tab

3. **Test Approval Flow:**
   - Admin approves User B's request
   - User B should receive real-time notification in Updates tab

### Debug Mode Features (Flutter)
- Connection status indicator (Live/Offline)
- Mock notification buttons for testing UI without backend
- Visible in debug builds only

## Database Migrations

### Migration Required: ✅ Yes

Run the migration to create the notifications table:

```bash
cd /Users/mac138/Documents/Code/ep/EventPointApi/migrations
./run_notifications_migration.sh
```

Or manually using psql:
```bash
psql "your_connection_string" -f add_notifications_table.sql
```

### Database Schema

**notifications table:**
- `notification_id` (UUID, PK) - Unique notification ID
- `user_id` (UUID, FK) - Recipient user ID
- `notification_type` (VARCHAR) - Type: JoinRequest, RequestApproved, etc.
- `event_id` (UUID, FK, nullable) - Related event ID
- `event_title` (VARCHAR) - Event title for display
- `image_url` (TEXT) - User or event image URL
- `title` (VARCHAR) - Notification title
- `subtitle` (VARCHAR) - Additional description
- `related_user_id` (UUID, FK, nullable) - User who triggered notification
- `related_user_name` (VARCHAR) - Name of related user
- `is_read` (BOOLEAN) - Read status
- `created_at` (TIMESTAMPTZ) - Creation timestamp
- `read_at` (TIMESTAMPTZ, nullable) - When marked as read

**Database Functions:**
- `create_notification()` - Insert new notification
- `get_user_notifications()` - Fetch with pagination
- `mark_notification_read()` - Mark single as read
- `mark_all_notifications_read()` - Mark all user's notifications as read
- `get_unread_notification_count()` - Count unread notifications
- `delete_notification()` - Delete single notification
- `delete_old_notifications()` - Cleanup old notifications (90+ days)

### REST API Endpoints

**GET /api/notification**
- Query params: userId, pageSize, pageNumber, unreadOnly
- Returns: List of notifications

**GET /api/notification/unread-count**
- Query param: userId
- Returns: { count: number }

**POST /api/notification/mark-read**
- Body: { notificationId, userId }
- Returns: Success message

**POST /api/notification/mark-all-read**
- Query param: userId
- Returns: { message, count }

**DELETE /api/notification/{notificationId}**
- Query param: userId
- Returns: Success message

## Security
- All SignalR connections require JWT authentication
- Notifications sent only to specific user groups (no broadcast)
- Payload data fetched from authenticated database calls

## Configuration
No additional configuration required. Uses existing:
- JWT authentication settings
- CORS policy (already allows /hubs endpoints)
- SignalR middleware (already configured)

## Future Enhancements
- ~~Store notifications in database for persistence across devices~~ ✅ **IMPLEMENTED**
- Add notification preferences (enable/disable types)
- Support for more notification types:
  - Prayer wall posts
  - Photo uploads
  - Event updates
  - RSVP changes
- Push notifications for mobile (FCM/APNs)
- ~~Mark as read sync across devices~~ ✅ **IMPLEMENTED**
- ~~Notification expiry/cleanup~~ ✅ **IMPLEMENTED** (90-day auto-cleanup function)
- Email/SMS notifications for offline users
- Notification grouping (e.g., "5 people joined your event")

## Notes
- Notifications are stored in **both** database (persistent) and Flutter SharedPreferences (cache)
- SignalR provides real-time delivery when user is online
- REST API provides notifications when user comes back online
- SignalR reconnects automatically on network changes
- Database stores unlimited notifications (with cleanup function for 90+ days old)
- Badge shows unread count (capped at 99+ in UI)
- Notifications survive app reinstalls and sync across devices
