using Npgsql;
using NpgsqlTypes;
using Models.Notification;

namespace DAL
{
    public class NotificationDAL
    {
        /// <summary>
        /// Create a new notification in the database
        /// </summary>
        public static async Task<string> CreateNotificationAsync(
            string userId,
            string notificationType,
            string eventId,
            string eventTitle,
            string imageUrl,
            string title,
            string subtitle,
            string relatedUserId,
            string relatedUserName)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT create_notification(@p_user_id, @p_notification_type, @p_event_id, @p_event_title, @p_image_url, @p_title, @p_subtitle, @p_related_user_id, @p_related_user_name)",
                conn);

            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = userId;
            cmd.Parameters.Add("p_notification_type", NpgsqlDbType.Varchar).Value = notificationType;
            cmd.Parameters.Add("p_event_id", NpgsqlDbType.Varchar).Value =
                string.IsNullOrWhiteSpace(eventId) ? DBNull.Value : eventId;
            cmd.Parameters.Add("p_event_title", NpgsqlDbType.Varchar).Value = eventTitle ?? string.Empty;
            cmd.Parameters.Add("p_image_url", NpgsqlDbType.Text).Value = imageUrl ?? string.Empty;
            cmd.Parameters.Add("p_title", NpgsqlDbType.Varchar).Value = title;
            cmd.Parameters.Add("p_subtitle", NpgsqlDbType.Varchar).Value = subtitle ?? string.Empty;
            cmd.Parameters.Add("p_related_user_id", NpgsqlDbType.Varchar).Value =
                string.IsNullOrWhiteSpace(relatedUserId) ? DBNull.Value : relatedUserId;
            cmd.Parameters.Add("p_related_user_name", NpgsqlDbType.Varchar).Value = relatedUserName ?? string.Empty;

            var notificationId = await cmd.ExecuteScalarAsync();
            return notificationId?.ToString() ?? string.Empty;
        }

        /// <summary>
        /// Get notifications for a user with pagination
        /// </summary>
        public static async Task<List<NotificationModel>> GetUserNotificationsAsync(GetNotificationsRequest request)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT * FROM get_user_notifications(@p_user_id, @p_page_size, @p_page_number, @p_unread_only)",
                conn);

            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = request.UserId;
            cmd.Parameters.Add("p_page_size", NpgsqlDbType.Integer).Value = request.PageSize;
            cmd.Parameters.Add("p_page_number", NpgsqlDbType.Integer).Value = request.PageNumber;
            cmd.Parameters.Add("p_unread_only", NpgsqlDbType.Boolean).Value = request.UnreadOnly;

            var notifications = new List<NotificationModel>();
            await using var reader = await cmd.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                notifications.Add(new NotificationModel
                {
                    NotificationId = reader.GetString(0),
                    UserId = reader.GetString(1),
                    NotificationType = reader.GetString(2),
                    EventId = reader.IsDBNull(3) ? string.Empty : reader.GetString(3),
                    EventTitle = reader.IsDBNull(4) ? string.Empty : reader.GetString(4),
                    ImageUrl = reader.IsDBNull(5) ? string.Empty : reader.GetString(5),
                    Title = reader.GetString(6),
                    Subtitle = reader.IsDBNull(7) ? string.Empty : reader.GetString(7),
                    RelatedUserId = reader.IsDBNull(8) ? string.Empty : reader.GetString(8),
                    RelatedUserName = reader.IsDBNull(9) ? string.Empty : reader.GetString(9),
                    IsRead = reader.GetBoolean(10),
                    CreatedAt = reader.GetDateTime(11),
                    ReadAt = reader.IsDBNull(12) ? null : reader.GetDateTime(12)
                });
            }

            return notifications;
        }

        /// <summary>
        /// Mark a notification as read
        /// </summary>
        public static async Task<bool> MarkNotificationReadAsync(MarkNotificationReadRequest request)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT mark_notification_read(@p_notification_id, @p_user_id)",
                conn);

            cmd.Parameters.Add("p_notification_id", NpgsqlDbType.Varchar).Value = request.NotificationId;
            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = request.UserId;

            var result = await cmd.ExecuteScalarAsync();
            return result != null && (bool)result;
        }

        /// <summary>
        /// Mark all notifications as read for a user
        /// </summary>
        public static async Task<int> MarkAllNotificationsReadAsync(string userId)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT mark_all_notifications_read(@p_user_id)",
                conn);

            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = userId;

            var result = await cmd.ExecuteScalarAsync();
            return result != null ? Convert.ToInt32(result) : 0;
        }

        /// <summary>
        /// Get unread notification count for a user
        /// </summary>
        public static async Task<int> GetUnreadNotificationCountAsync(string userId)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT get_unread_notification_count(@p_user_id)",
                conn);

            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = userId;

            var result = await cmd.ExecuteScalarAsync();
            return result != null ? Convert.ToInt32(result) : 0;
        }

        /// <summary>
        /// Delete a notification
        /// </summary>
        public static async Task<bool> DeleteNotificationAsync(string notificationId, string userId)
        {
            var connString = DBHelper.GetConnection();
            await using var conn = new NpgsqlConnection(connString);
            await conn.OpenAsync();

            var cmd = new NpgsqlCommand(
                "SELECT delete_notification(@p_notification_id, @p_user_id)",
                conn);

            cmd.Parameters.Add("p_notification_id", NpgsqlDbType.Varchar).Value = notificationId;
            cmd.Parameters.Add("p_user_id", NpgsqlDbType.Varchar).Value = userId;

            var result = await cmd.ExecuteScalarAsync();
            return result != null && (bool)result;
        }
    }
}
