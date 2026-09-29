using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class DeletePrayerRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string PrayerId { get; set; } = string.Empty;
        public string RequestingUserId { get; set; } = string.Empty;
    }
}
