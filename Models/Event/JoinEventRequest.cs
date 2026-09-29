using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Event
{
    public class JoinEventRequest
    {
        public string UserId { get; set; } = string.Empty;
        public string AdminCode { get; set; } = string.Empty;
    }
}
