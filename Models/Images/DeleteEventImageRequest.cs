using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class DeleteEventImageRequest
    {
        public string EventId { get; set; } = string.Empty;
        public string ImageId { get; set; } = string.Empty;
        public string RequestingUserId { get; set; } = string.Empty;
    }
}
