using Models.Images;
using Models.MixedFeed;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IEventImageService
    {
        Task<CreateEventImageResponse> CreateEventImageAsync(CreateEventImageRequest request);
        Task<ApproveEventImageResponse> ApproveEventImageAsync(ApproveEventImageRequest request);
        Task<ToggleImageLikeResponse> ToggleImageLikeAsync(ToggleImageLikeRequest request);
        Task<IEnumerable<PrivateFeedImageResponse>> GetPrivateFeedAsync(GetPrivateFeedRequest request);
        Task<IEnumerable<PublicImageFeedResponse>> GetPublicImageFeedAsync(GetPublicImageFeedRequest request);
        Task<DeleteEventImageResponse> DeleteEventImageAsync(DeleteEventImageRequest request);
        Task<IEnumerable<UserMixedImagesFeedResponse>> GetUserMixedFeedAsync(UserMixedImagesFeedRequest request);
    }
}
