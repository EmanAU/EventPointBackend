using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.User
{
    public class UserCheckResponse
    {
        public bool IsExist { get; set; }
        public string UserId { get; set; } = string.Empty;
    }
}
