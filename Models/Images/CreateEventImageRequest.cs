using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class CreateEventImageRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string UserId { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string Caption { get; set; } = string.Empty;
        /// <summary>0 or null = Everyone (public within event). 1=Family, 2=Friend, 3=Professional = restrict to that guest category.</summary>
        public int? RelationshipTypeId { get; set; }
    }
}
