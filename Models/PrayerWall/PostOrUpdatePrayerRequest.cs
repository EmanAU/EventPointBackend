using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class PostOrUpdatePrayerRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public string MessageText { get; set; } = string.Empty;
    }
}
