using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class PrayerResponse
    {
        public string PrayerId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public string UserName { get; set; } = string.Empty;
        public string ProfileImageUrl { get; set; } = string.Empty;
        public string PrayerMessage { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public bool IsMyMessage { get; set; }
        public bool CanEdit { get; set; }
        public bool IsApproved { get; set; }
    }
}
