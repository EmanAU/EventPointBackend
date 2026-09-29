using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Guest
{
    public class ApprovedGuestResponse
    {
        public string GuestUserId { get; set; } = string.Empty;
        public string GuestName { get; set; } = string.Empty;
        public string GuestCity { get; set; } = string.Empty;
        public string GuestCountry { get; set; } = string.Empty;
        public string ProfileImageUrl { get; set; } = string.Empty;
        public string InvitedByUserId { get; set; } = string.Empty;
        public string InviterName { get; set; } = string.Empty;
        public string InviterChain { get; set; } = string.Empty;
        public string RelationshipName { get; set; } = string.Empty;
        public string RelationshipPath { get; set; } = string.Empty;
        public string RelationshipTypeName { get; set; } = string.Empty;
        public int ImagesUploaded { get; set; }
        public DateTime JoinedAt { get; set; }
        public bool IsAdmin { get; set; }
        public bool IsCreator { get; set; }
        public string AdminCode { get; set; } = string.Empty;
        public int? ColorId { get; set; }
        public string ColorCode { get; set; } = string.Empty;
        public string InviterColorCode { get; set; } = string.Empty;
    }
}
