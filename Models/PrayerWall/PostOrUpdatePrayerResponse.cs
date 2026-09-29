using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PrayerWall
{
    public class PostOrUpdatePrayerResponse
    {
        public string PrayerId { get; set; } = string.Empty;
        public bool IsSuccess { get; set; }
        public string Message { get; set; } = string.Empty;
        /// <summary>True when a guest posted a prayer that awaits admin approval (is_approved = false).</summary>
        public bool PendingApproval { get; set; }
    }
}
