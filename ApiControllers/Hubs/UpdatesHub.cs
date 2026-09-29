using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ApiControllers.Hubs;

/// <summary>
/// SignalR hub for real-time update notifications.
/// Users join their own group to receive join requests and approval notifications.
/// </summary>
[Authorize]
public class UpdatesHub : Hub
{
    public const string HubPath = "/hubs/updates";

    private readonly ILogger<UpdatesHub> _logger;

    public UpdatesHub(ILogger<UpdatesHub> logger)
    {
        _logger = logger;
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation(
            "UpdatesHub connected: ConnectionId={ConnectionId}, User={User}",
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
                "UpdatesHub disconnected with error: ConnectionId={ConnectionId}",
                Context.ConnectionId);
        }
        else
        {
            _logger.LogInformation(
                "UpdatesHub disconnected: ConnectionId={ConnectionId}",
                Context.ConnectionId);
        }

        return base.OnDisconnectedAsync(exception);
    }

    /// <summary>
    /// Join the user's personal notification group.
    /// Wire name must be camelCase for JSON hub protocol (matches official clients and signalr_netcore).
    /// </summary>
    [HubMethodName("joinUserGroup")]
    public async Task JoinUserGroup(string userId)
    {
        _logger.LogInformation(
            "joinUserGroup: ConnectionId={ConnectionId}, Group=user_{UserId}, Caller={Caller}",
            Context.ConnectionId,
            userId,
            Context.UserIdentifier ?? Context.User?.Identity?.Name ?? "?");
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user_{userId}");
    }

    /// <summary>
    /// Leave the user's personal notification group.
    /// </summary>
    [HubMethodName("leaveUserGroup")]
    public async Task LeaveUserGroup(string userId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"user_{userId}");
    }
}
