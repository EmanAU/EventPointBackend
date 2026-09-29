using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class GetPrayersRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string ViewerUserId { get; set; } = string.Empty;
    }
}
