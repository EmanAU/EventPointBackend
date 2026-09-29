using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Event
{
    public class UpdateEventRequest
    {
        public string EventTitle { get; set; } = string.Empty;
        public string TagLine { get; set; } = string.Empty;
        public DateTime EventDateTime { get; set; }
        public string Venue { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public int ExpectedGuestNumber { get; set; }
        public string EventCoverImageUrl { get; set; } = string.Empty;
    }
}
