using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Event
{
    public class PendingRequestResponse
    {
        public string GuestUserId { get; set; } = string.Empty;
        public string GuestName { get; set; } = string.Empty;
        public DateTime RequestTime { get; set; }
        public string Status { get; set; } = string.Empty;
        public string GuestCity { get; set; } = string.Empty;
        public string GuestCountry { get; set; } = string.Empty;
    }
}
