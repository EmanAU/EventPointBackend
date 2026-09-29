using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Guest
{
    public class RemoveGuestRequest
    {
        public string AdminUserId { get; set; } = string.Empty;
        public string TargetUserId { get; set; } = string.Empty;
        public string EventId { get; set; } = string.Empty;
    }
}
