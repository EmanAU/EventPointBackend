namespace ApiControllers.Services;

/// <summary>
/// Notifies SignalR clients of prayer wall changes.
/// </summary>
public interface IPrayerWallHubNotifier
{
    Task NotifyPrayerPosted(string eventId);
    Task NotifyPrayerApproved(string eventId, string prayerId);
    Task NotifyPrayerDeleted(string eventId, string prayerId);
}
