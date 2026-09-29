using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PublicFeed
{
    public class GetPublicFeedRequest
    {
        public int PageSize { get; set; } = 5;
        public DateTime? CursorDate { get; set; }
        public string? CursorEventId { get; set; }
        /// <summary>Optional substring filter (title, venue, category, subcategory).</summary>
        public string? Search { get; set; }
    }
}
