using Models.Event;
using Models.PublicFeed;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IEventService
    {
        Task<CreateEventResponse> CreateGroupAsync(CreateEventRequest request);
        Task<JoinEventResponse> JoinEventAsync(JoinEventRequest request);
        Task<IEnumerable<EventResponse>> GetEventsByUserAsync(string userId);
        Task<EventNotificationSummaryResponse?> GetEventNotificationSummaryAsync(string eventId);
        Task<List<string>> GetEventAdminUserIdsAsync(string eventId);
        Task<EventDetailResponse?> GetEventDetailAsync(string eventId, string userId);
        Task<bool> UpdateEventAsync(string eventId, string userId, UpdateEventRequest request);
        Task<int> AddEventImageAsync(string eventId, string userId, string imageUrl);
        Task<bool> UpdateInvitationCardAsync(string eventId, string userId, UpdateInvitationCardRequest request);
        Task<IEnumerable<PendingRequestResponse>> GetPendingRequestsAsync(GetPendingRequestsRequest request);
        Task<IEnumerable<PublicFeedEventResponse>> GetPublicFeedAsync(GetPublicFeedRequest request);
        Task<IEnumerable<EventScrollItemResponse>> GetEventsScrollFeedAsync(string userId);
    }
}
