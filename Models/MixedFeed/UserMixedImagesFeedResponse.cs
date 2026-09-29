using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.MixedFeed
{
    public class UserMixedImagesFeedResponse
    {
        public string EventImageId { get; set; } = string.Empty;

        public string ImageUrl { get; set; } = string.Empty;

        public string Caption { get; set; } = string.Empty;

        public int LikesCount { get; set; }

        public DateTimeOffset ImageCreatedAt { get; set; }

        public string EventId { get; set; } = string.Empty;

        public string EventTitle { get; set; } = string.Empty;

        public string EventCoverImageUrl { get; set; } = string.Empty;
    }
}
