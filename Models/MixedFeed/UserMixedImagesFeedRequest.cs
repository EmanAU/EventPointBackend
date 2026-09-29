using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.MixedFeed
{
    public class UserMixedImagesFeedRequest
    {
        // Required: The user requesting the feed
        public string ViewerId { get; set; } = string.Empty;

        // Optional: The timestamp of the last seen image for pagination
        public DateTimeOffset? CursorTime { get; set; }

        // Optional: The ID of the last seen image (tie-breaker for pagination)
        public string? CursorId { get; set; }

        // Optional: Number of records to fetch (Defaults to 20 in the DB function)
        public int? Limit { get; set; }
    }
}
