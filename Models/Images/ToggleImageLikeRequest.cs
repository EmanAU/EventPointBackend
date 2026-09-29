using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class ToggleImageLikeRequest
    {
        public string UserId { get; set; } = string.Empty;
        public string ImageId { get; set; } = string.Empty;
    }
}
