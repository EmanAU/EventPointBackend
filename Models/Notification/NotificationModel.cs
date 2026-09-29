namespace Models.Notification
{
    public class NotificationModel
    {
        public string NotificationId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public string NotificationType { get; set; } = string.Empty; // "JoinRequest", "RequestApproved"
        public string EventId { get; set; } = string.Empty;
        public string EventTitle { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty; // User or event image
        public string Title { get; set; } = string.Empty;
        public string Subtitle { get; set; } = string.Empty;
        public string RelatedUserId { get; set; } = string.Empty; // Requester or approver
        public string RelatedUserName { get; set; } = string.Empty;
        public bool IsRead { get; set; } = false;
        public DateTime CreatedAt { get; set; }
        public DateTime? ReadAt { get; set; }
    }
}
