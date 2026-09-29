using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Reference
{
    public class SubCategoryResponse
    {
        public int SubCategoryId { get; set; }
        public int EventCategoryId { get; set; }
        public string SubCategoryName { get; set; } = string.Empty;
    }
}
