using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Auth
{
    public class GoogleLoginRequest
    {
        [Required(ErrorMessage = "Google ID token is required")]
        public string IdToken { get; set; } = string.Empty;
    }
}
