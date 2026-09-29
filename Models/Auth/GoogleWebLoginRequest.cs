using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Auth
{
    public class GoogleWebLoginRequest
    {
        [Required(ErrorMessage = "Google access token is required")]
        public string AccessToken { get; set; } = string.Empty;
    }
}
