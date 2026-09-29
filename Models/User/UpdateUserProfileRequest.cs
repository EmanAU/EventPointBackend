using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.User
{
    public class UpdateUserProfileRequest
    {
        public string UserId { get; set; } = string.Empty;
        public string NewName { get; set; } = string.Empty;
        public string NewProfileImageUrl { get; set; } = string.Empty;
        public string? NewCity { get; set; }
        public string? NewCountry { get; set; }
    }
}
