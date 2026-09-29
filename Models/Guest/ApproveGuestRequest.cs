using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Guest
{
    public class ApproveGuestRequest
    {
        public string AdminUserId { get; set; } = string.Empty;
        public string TargetGuestId { get; set; } = string.Empty;
        public string EventId { get; set; } = string.Empty;
        public int RelationshipTypeId { get; set; }
        public int RelationshipId { get; set; }
    }
}
