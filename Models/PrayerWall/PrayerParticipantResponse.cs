using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class PrayerParticipantResponse
    {
        public string UserId { get; set; } = string.Empty;
        public string UserName { get; set; } = string.Empty;
        public string ProfileImageUrl { get; set; } = string.Empty;
        public long TotalCount { get; set; }
    }
}
