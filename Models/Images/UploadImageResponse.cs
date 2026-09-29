using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.Json.Serialization;
using System.Threading.Tasks;

namespace Models.Images
{
    public class UploadImageResponse
    {
        [JsonPropertyName("url")]
        public string Url { get; set; } = string.Empty;
    }
}
