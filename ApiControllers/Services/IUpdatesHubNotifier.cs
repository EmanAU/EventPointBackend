namespace ApiControllers.Services;

/// <summary>
/// Notifies SignalR clients of update notifications (join requests, approvals).
/// </summary>
public interface IUpdatesHubNotifier
{
    /// <summary>
    /// Notify an admin that someone has requested to join their event.
    /// </summary>
    Task NotifyJoinRequestReceived(string adminUserId, object payload);

    /// <summary>
    /// Notify a user that their join request was approved.
    /// </summary>
    Task NotifyRequestApproved(string userId, object payload);

    /// <summary>
    /// Notify an event admin that a guest prayer is waiting for approval.
    /// </summary>
    Task NotifyPrayerNeedsApproval(string adminUserId, object payload);

    /// <summary>
    /// Notify the prayer author that their prayer was approved.
    /// </summary>
    Task NotifyPrayerWallApproved(string authorUserId, object payload);
}
