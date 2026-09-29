namespace Models.Notification
{
    public class GetNotificationsRequest
    {
        public string UserId { get; set; } = string.Empty;
        public int PageSize { get; set; } = 20;
        public int PageNumber { get; set; } = 1;
        public bool UnreadOnly { get; set; } = false;
    }
}
