using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Images
{
    public class PrivateFeedImageResponse
    {
        public string ImageId { get; set; } = string.Empty;
        public string ImageUrl { get; set; } = string.Empty;
        public string Caption { get; set; } = string.Empty;
        public string UploaderId { get; set; } = string.Empty;
        public string UploaderName { get; set; } = string.Empty;
        public string UploaderProfileImageUrl { get; set; } = string.Empty;
        public string UploaderRelation { get; set; } = string.Empty;
        public string UploaderRelationshipName { get; set; } = string.Empty;
        public string UploaderRelationshipPath { get; set; } = string.Empty;
        public bool IsCreator { get; set; }
        public int LikesCount { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public bool IsLikedByMe { get; set; }
        public bool IsApproved { get; set; }
        public int ImagePrivacyTypeId { get; set; }
    }
}
