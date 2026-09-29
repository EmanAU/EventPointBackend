using DAL;
using IServices;
using Models.Event;
using Models.PublicFeed;
using System;
using System.Collections.Generic;
using System.Diagnostics.Tracing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class EventService : IEventService
    {
        public async Task<CreateEventResponse> CreateGroupAsync(CreateEventRequest request)
        {
            return await EventDAL.CreateGroupAsync(request);
        }

        public async Task<JoinEventResponse> JoinEventAsync(JoinEventRequest request)
        {
            return await EventDAL.JoinEventAsync(request);
        }

        public async Task<IEnumerable<EventResponse>> GetEventsByUserAsync(string userId)
        {
            return await EventDAL.GetEventsByUserAsync(userId);
        }

        public async Task<EventNotificationSummaryResponse?> GetEventNotificationSummaryAsync(string eventId)
        {
            return await EventDAL.GetEventNotificationSummaryAsync(eventId);
        }

        public async Task<List<string>> GetEventAdminUserIdsAsync(string eventId)
        {
            return await EventDAL.GetEventAdminUserIdsAsync(eventId);
        }

        public async Task<EventDetailResponse?> GetEventDetailAsync(string eventId, string userId)
        {
            return await EventDAL.GetEventByIdAsync(eventId, userId);
        }

        public async Task<bool> UpdateEventAsync(string eventId, string userId, UpdateEventRequest request)
        {
            return await EventDAL.UpdateEventAsync(eventId, userId, request);
        }

        public async Task<int> AddEventImageAsync(string eventId, string userId, string imageUrl)
        {
            return await EventDAL.AddEventImageAsync(eventId, userId, imageUrl);
        }

        public async Task<bool> UpdateInvitationCardAsync(string eventId, string userId, UpdateInvitationCardRequest request)
        {
            return await EventDAL.UpdateInvitationCardAsync(eventId, userId, request);
        }

        public async Task<IEnumerable<PendingRequestResponse>> GetPendingRequestsAsync(GetPendingRequestsRequest request)
        {
            return await EventDAL.GetPendingRequestsAsync(request);
        }

        public async Task<IEnumerable<PublicFeedEventResponse>> GetPublicFeedAsync(GetPublicFeedRequest request)
        {
            return await EventDAL.GetPublicFeedAsync(request);
        }

        public async Task<IEnumerable<EventScrollItemResponse>> GetEventsScrollFeedAsync(string userId)
        {
            return await EventDAL.GetEventsScrollFeedAsync(userId);
        }
    }
}
