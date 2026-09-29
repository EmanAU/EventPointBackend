using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class GetPrivateFeedRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string ViewerUserId { get; set; } = string.Empty;
        public int PageSize { get; set; } = 20;
        public DateTime? CursorDate { get; set; }
        public string? CursorImageId { get; set; }
    }
}
