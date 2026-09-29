using Models.Invitation;
using System;

namespace Models.Event
{
    /// <summary>
    /// One event card for the full-screen vertical scroll feed: joined/created + public discovery.
    /// </summary>
    public class EventScrollItemResponse
    {
        public string EventId { get; set; } = string.Empty;
        public string EventTitle { get; set; } = string.Empty;
        public string TagLine { get; set; } = string.Empty;
        public DateTime EventDateTime { get; set; }
        public string Venue { get; set; } = string.Empty;
        public string EventCoverImageUrl { get; set; } = string.Empty;
        /// <summary>Public or Private (member events can be either).</summary>
        public string EventType { get; set; } = "Private";
        /// <summary>Admin, Guest, or Viewer (public, not a member).</summary>
        public string Role { get; set; } = "Guest";
        public bool IsMember { get; set; }
        public InvitationCardResponse? InvitationCard { get; set; }
    }
}
