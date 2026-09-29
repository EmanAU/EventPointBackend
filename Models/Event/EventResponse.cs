using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Event
{
    public class EventResponse
    {
        public string EventId { get; set; } = string.Empty;
        public string CreatorId { get; set; } = string.Empty;
        public string EventTitle { get; set; } = string.Empty;
        public string TagLine { get; set; } = string.Empty;
        public DateTime EventDateTime { get; set; }
        public string Venue { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public string EventCode { get; set; } = string.Empty;
        public string EventCategoryName { get; set; } = string.Empty;
        public string SubCategoryName { get; set; } = string.Empty;
        public int ExpectedGuestNumber { get; set; }
        public string Role { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public string EventCoverImageUrl { get; set; } = string.Empty;
    }
}
