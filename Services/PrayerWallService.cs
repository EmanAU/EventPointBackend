using DAL;
using IServices;

using Models.PrayerWall;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class PrayerWallService : IPrayerWallService
    {
        public async Task<PostOrUpdatePrayerResponse> PostOrUpdatePrayerAsync(PostOrUpdatePrayerRequest request)
        {
            return await PrayerWallDAL.PostOrUpdatePrayerAsync(request);
        }

        public async Task<DeletePrayerResponse> DeletePrayerAsync(DeletePrayerRequest request)
        {
            return await PrayerWallDAL.DeletePrayerAsync(request);
        }

        public async Task<IEnumerable<PrayerResponse>> GetPrayersAsync(GetPrayersRequest request)
        {
            return await PrayerWallDAL.GetPrayersAsync(request);
        }

        public async Task<ApprovePrayerResponse> ApprovePrayerAsync(ApprovePrayerRequest request)
        {
            return await PrayerWallDAL.ApprovePrayerAsync(request);
        }

        public async Task<IEnumerable<PrayerParticipantResponse>> GetPrayerParticipantsAsync(string eventId)
        {
            return await PrayerWallDAL.GetPrayerParticipantsAsync(eventId);
        }

        public async Task<string?> GetPrayerAuthorUserIdAsync(string eventId, string prayerId)
        {
            return await PrayerWallDAL.GetPrayerAuthorUserIdAsync(eventId, prayerId);
        }
    }
}
