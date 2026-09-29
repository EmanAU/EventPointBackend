using DAL;
using IServices;
using Models.Notification;

namespace Services
{
    public class NotificationService : INotificationService
    {
        public async Task<string> CreateNotificationAsync(
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
            return await NotificationDAL.CreateNotificationAsync(
                userId,
                notificationType,
                eventId,
                eventTitle,
                imageUrl,
                title,
                subtitle,
                relatedUserId,
                relatedUserName);
        }

        public async Task<List<NotificationModel>> GetUserNotificationsAsync(GetNotificationsRequest request)
        {
            return await NotificationDAL.GetUserNotificationsAsync(request);
        }

        public async Task<bool> MarkNotificationReadAsync(MarkNotificationReadRequest request)
        {
            return await NotificationDAL.MarkNotificationReadAsync(request);
        }

        public async Task<int> MarkAllNotificationsReadAsync(string userId)
        {
            return await NotificationDAL.MarkAllNotificationsReadAsync(userId);
        }

        public async Task<int> GetUnreadNotificationCountAsync(string userId)
        {
            return await NotificationDAL.GetUnreadNotificationCountAsync(userId);
        }

        public async Task<bool> DeleteNotificationAsync(string notificationId, string userId)
        {
            return await NotificationDAL.DeleteNotificationAsync(notificationId, userId);
        }
    }
}
