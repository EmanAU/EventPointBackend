namespace Models.Event
{
    public class EventNotificationSummaryResponse
    {
        public string EventId { get; set; } = string.Empty;
        public string CreatorId { get; set; } = string.Empty;
        public string EventTitle { get; set; } = string.Empty;
        public string EventCoverImageUrl { get; set; } = string.Empty;
    }
}