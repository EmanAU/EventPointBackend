using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ApiControllers.Hubs;

/// <summary>
/// SignalR hub for real-time prayer wall updates.
/// Clients join event groups to receive PrayerPosted, PrayerApproved, PrayerDeleted.
/// </summary>
[Authorize]
public class PrayerWallHub : Hub
{
    public const string HubPath = "/hubs/prayerwall";

    private readonly ILogger<PrayerWallHub> _logger;

    public PrayerWallHub(ILogger<PrayerWallHub> logger)
    {
        _logger = logger;
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation(
            "PrayerWallHub connected: ConnectionId={ConnectionId}, User={User}",
            Context.ConnectionId,
            Context.UserIdentifier ?? Context.User?.Identity?.Name ?? "(no id)");
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        if (exception != null)
        {
            _logger.LogWarning(
                exception,
                "PrayerWallHub disconnected with error: ConnectionId={ConnectionId}",
                Context.ConnectionId);
        }
        else
        {
            _logger.LogInformation(
                "PrayerWallHub disconnected: ConnectionId={ConnectionId}",
                Context.ConnectionId);
        }

        return base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Join the group for an event to receive real-time prayer updates.
    /// </summary>
    [HubMethodName("joinEventGroup")]
    public async Task JoinEventGroup(string eventId)
    {
        _logger.LogInformation(
            "joinEventGroup: ConnectionId={ConnectionId}, EventId={EventId}",
            Context.ConnectionId,
            eventId);
        await Groups.AddToGroupAsync(Context.ConnectionId, $"event_{eventId}");
    }

    /// <summary>
    /// Leave the event group when navigating away.
    /// </summary>
    [HubMethodName("leaveEventGroup")]
    public async Task LeaveEventGroup(string eventId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"event_{eventId}");
    }
}
