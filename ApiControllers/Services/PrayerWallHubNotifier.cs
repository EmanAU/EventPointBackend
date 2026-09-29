using ApiControllers.Hubs;
using Microsoft.AspNetCore.SignalR;

namespace ApiControllers.Services;

public class PrayerWallHubNotifier : IPrayerWallHubNotifier
{
    private readonly IHubContext<PrayerWallHub> _hubContext;

    public PrayerWallHubNotifier(IHubContext<PrayerWallHub> hubContext)
    {
        _hubContext = hubContext;
    }

    public async Task NotifyPrayerPosted(string eventId)
    {
        await _hubContext.Clients
            .Group($"event_{eventId}")
            .SendAsync("PrayerPosted", eventId);
    }

    public async Task NotifyPrayerApproved(string eventId, string prayerId)
    {
        await _hubContext.Clients
            .Group($"event_{eventId}")
            .SendAsync("PrayerApproved", prayerId);
    }

    public async Task NotifyPrayerDeleted(string eventId, string prayerId)
    {
        await _hubContext.Clients
            .Group($"event_{eventId}")
            .SendAsync("PrayerDeleted", prayerId);
    }
}
