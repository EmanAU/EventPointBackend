using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Guest
{
    public class PromoteAdminRequest
    {
        public string CreatorUserId { get; set; } = string.Empty;
        public string TargetGuestUserId { get; set; } = string.Empty;
        public string EventId { get; set; } = string.Empty;
        public int ColorId { get; set; } = 1;
    }
}
