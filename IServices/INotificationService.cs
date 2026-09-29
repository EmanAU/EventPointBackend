using Models.Notification;

namespace IServices
{
    public interface INotificationService
    {
        Task<string> CreateNotificationAsync(
            string userId,
            string notificationType,
            string eventId,
            string eventTitle,
            string imageUrl,
            string title,
            string subtitle,
            string relatedUserId,
            string relatedUserName);

        Task<List<NotificationModel>> GetUserNotificationsAsync(GetNotificationsRequest request);
        Task<bool> MarkNotificationReadAsync(MarkNotificationReadRequest request);
        Task<int> MarkAllNotificationsReadAsync(string userId);
        Task<int> GetUnreadNotificationCountAsync(string userId);
        Task<bool> DeleteNotificationAsync(string notificationId, string userId);
    }
}
