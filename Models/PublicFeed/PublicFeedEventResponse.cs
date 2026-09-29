using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PublicFeed
{
    public class PublicFeedEventResponse
    {
        public string EventId { get; set; } = string.Empty;
        public string EventTitle { get; set; } = string.Empty;
        public string CoverImageUrl { get; set; } = string.Empty;
        public string CategoryName { get; set; } = string.Empty;
        public string SubCategoryName { get; set; } = string.Empty;
        public string Venue { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
    }
}
