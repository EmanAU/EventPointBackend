using Models.PrayerWall;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IPrayerWallService
    {
        Task<PostOrUpdatePrayerResponse> PostOrUpdatePrayerAsync(PostOrUpdatePrayerRequest request);
        Task<DeletePrayerResponse> DeletePrayerAsync(DeletePrayerRequest request);
        Task<IEnumerable<PrayerResponse>> GetPrayersAsync(GetPrayersRequest request);
        Task<ApprovePrayerResponse> ApprovePrayerAsync(ApprovePrayerRequest request);
        Task<IEnumerable<PrayerParticipantResponse>> GetPrayerParticipantsAsync(string eventId);
        Task<string?> GetPrayerAuthorUserIdAsync(string eventId, string prayerId);
    }
}
