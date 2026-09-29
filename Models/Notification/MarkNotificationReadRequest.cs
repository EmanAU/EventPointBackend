namespace Models.Notification
{
    public class MarkNotificationReadRequest
    {
        public string NotificationId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
    }
}
