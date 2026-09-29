using DAL;
using IServices;
using Models.Images;
using Models.MixedFeed;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class EventImageService : IEventImageService
    {
        public async Task<CreateEventImageResponse> CreateEventImageAsync(CreateEventImageRequest request)
        {
            return await EventImagesDAL.CreateEventImageAsync(request);
        }

        public async Task<ApproveEventImageResponse> ApproveEventImageAsync(ApproveEventImageRequest request)
        {
            return await EventImagesDAL.ApproveEventImageAsync(request);
        }

        public async Task<ToggleImageLikeResponse> ToggleImageLikeAsync(ToggleImageLikeRequest request)
        {
            return await EventImagesDAL.ToggleImageLikeAsync(request);
        }

        public async Task<IEnumerable<PrivateFeedImageResponse>> GetPrivateFeedAsync(GetPrivateFeedRequest request)
        {
            return await EventImagesDAL.GetPrivateFeedAsync(request);
        }

        public async Task<IEnumerable<PublicImageFeedResponse>> GetPublicImageFeedAsync(GetPublicImageFeedRequest request)
        {
            return await EventImagesDAL.GetPublicImageFeedAsync(request);
        }

        public async Task<DeleteEventImageResponse> DeleteEventImageAsync(DeleteEventImageRequest request)
        {
            return await EventImagesDAL.DeleteEventImageAsync(request);
        }

        public async Task<IEnumerable<UserMixedImagesFeedResponse>> GetUserMixedFeedAsync(UserMixedImagesFeedRequest request)
        {
            return await EventImagesDAL.GetUserMixedFeedAsync(request);
        }
    }
}
