using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Reference
{
    public class ColorResponse
    {
        public int ColorId { get; set; }
        public string ColorName { get; set; } = string.Empty;
        public string ColorCode { get; set; } = string.Empty;
    }
}
