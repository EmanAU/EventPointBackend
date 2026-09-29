using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class CreateEventImageResponse
    {
        public string ImageId { get; set; } = string.Empty;
        public bool IsApproved { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}
