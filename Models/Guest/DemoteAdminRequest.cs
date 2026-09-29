using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Guest
{
    public class DemoteAdminRequest
    {
        public string CreatorUserId { get; set; } = string.Empty;
        public string TargetAdminUserId { get; set; } = string.Empty;
        public string EventId { get; set; } = string.Empty;
    }
}
