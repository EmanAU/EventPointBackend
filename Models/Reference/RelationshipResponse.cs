using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Reference
{
    public class RelationshipResponse
    {
        public int RelationshipId { get; set; }
        public int RelationshipTypeId { get; set; }
        public string RelationshipName { get; set; } = string.Empty;
    }
}
