using ApiControllers.Hubs;
using IServices;
using Microsoft.AspNetCore.SignalR;
using System.Text.Json;

namespace ApiControllers.Services;

public class UpdatesHubNotifier : IUpdatesHubNotifier
{
    private readonly IHubContext<UpdatesHub> _hubContext;
    private readonly IServiceProvider _serviceProvider;

    private static string ReadPayloadString(Dictionary<string, JsonElement>? dict, string key)
    {
        if (dict == null || !dict.TryGetValue(key, out var el))
            return string.Empty;
        return el.ValueKind switch
        {
            JsonValueKind.String => el.GetString() ?? string.Empty,
            JsonValueKind.Null => string.Empty,
            JsonValueKind.Number => el.GetRawText(),
            _ => string.Empty
        };
    }

    public UpdatesHubNotifier(IHubContext<UpdatesHub> hubContext, IServiceProvider serviceProvider)
    {
        _hubContext = hubContext;
        _serviceProvider = serviceProvider;
    }

    public async Task NotifyJoinRequestReceived(string adminUserId, object payload)
    {
        // Send real-time notification via SignalR
        await _hubContext.Clients
            .Group($"user_{adminUserId}")
            .SendAsync("JoinRequestReceived", payload);

        // Save notification to database
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
            
            var payloadDict = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(
                JsonSerializer.Serialize(payload));
            
            if (payloadDict != null)
            {
                var requesterName = ReadPayloadString(payloadDict, "requesterName");
                var eventTitle = ReadPayloadString(payloadDict, "eventTitle");
                await notificationService.CreateNotificationAsync(
                    userId: adminUserId,
                    notificationType: "JoinRequest",
                    eventId: ReadPayloadString(payloadDict, "eventId"),
                    eventTitle: eventTitle,
                    imageUrl: ReadPayloadString(payloadDict, "requesterImageUrl"),
                    title: $"{(string.IsNullOrEmpty(requesterName) ? "Someone" : requesterName)} wants to join",
                    subtitle: eventTitle,
                    relatedUserId: ReadPayloadString(payloadDict, "requesterId"),
                    relatedUserName: requesterName);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to save join request notification to DB: {ex.Message}");
            // Don't fail - SignalR notification was already sent
        }
    }

    public async Task NotifyRequestApproved(string userId, object payload)
    {
        // Send real-time notification via SignalR
        await _hubContext.Clients
            .Group($"user_{userId}")
            .SendAsync("RequestApproved", payload);

        // Save notification to database
        try
        {
            using var scope = _serviceProvider.CreateScope();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
            
            var payloadDict = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(
                JsonSerializer.Serialize(payload));
            
            if (payloadDict != null)
            {
                var approvedEventTitle = ReadPayloadString(payloadDict, "eventTitle");
                var eventImage = ReadPayloadString(payloadDict, "eventImageUrl");
                if (string.IsNullOrEmpty(eventImage))
                    eventImage = ReadPayloadString(payloadDict, "eventCoverImageUrl");
                await notificationService.CreateNotificationAsync(
                    userId: userId,
                    notificationType: "RequestApproved",
                    eventId: ReadPayloadString(payloadDict, "eventId"),
                    eventTitle: approvedEventTitle,
                    imageUrl: eventImage,
                    title: "Request accepted",
                    subtitle: $"You can now view {approvedEventTitle}",
                    relatedUserId: ReadPayloadString(payloadDict, "approverId"),
                    relatedUserName: ReadPayloadString(payloadDict, "approverName"));
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to save approval notification to DB: {ex.Message}");
            // Don't fail - SignalR notification was already sent
        }
    }

    public async Task NotifyPrayerNeedsApproval(string adminUserId, object payload)
    {
        await _hubContext.Clients
            .Group($"user_{adminUserId}")
            .SendAsync("PrayerNeedsApproval", payload);

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

            var payloadDict = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(
                JsonSerializer.Serialize(payload));

            if (payloadDict != null)
            {
                var authorName = ReadPayloadString(payloadDict, "authorName");
                var eventTitle = ReadPayloadString(payloadDict, "eventTitle");
                await notificationService.CreateNotificationAsync(
                    userId: adminUserId,
                    notificationType: "PrayerNeedsApproval",
                    eventId: ReadPayloadString(payloadDict, "eventId"),
                    eventTitle: eventTitle,
                    imageUrl: ReadPayloadString(payloadDict, "authorImageUrl"),
                    title: $"{(string.IsNullOrEmpty(authorName) ? "Someone" : authorName)} posted a prayer",
                    subtitle: string.IsNullOrEmpty(eventTitle) ? "Pending your approval" : eventTitle,
                    relatedUserId: ReadPayloadString(payloadDict, "authorId"),
                    relatedUserName: authorName);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to save prayer-pending notification to DB: {ex.Message}");
        }
    }

    public async Task NotifyPrayerWallApproved(string authorUserId, object payload)
    {
        await _hubContext.Clients
            .Group($"user_{authorUserId}")
            .SendAsync("PrayerWallApproved", payload);

        try
        {
            using var scope = _serviceProvider.CreateScope();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();

            var payloadDict = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(
                JsonSerializer.Serialize(payload));

            if (payloadDict != null)
            {
                var eventTitle = ReadPayloadString(payloadDict, "eventTitle");
                var eventImage = ReadPayloadString(payloadDict, "eventImageUrl");
                if (string.IsNullOrEmpty(eventImage))
                    eventImage = ReadPayloadString(payloadDict, "eventCoverImageUrl");
                var approverName = ReadPayloadString(payloadDict, "approverName");
                await notificationService.CreateNotificationAsync(
                    userId: authorUserId,
                    notificationType: "PrayerWallApproved",
                    eventId: ReadPayloadString(payloadDict, "eventId"),
                    eventTitle: eventTitle,
                    imageUrl: eventImage,
                    title: "Prayer approved",
                    subtitle: string.IsNullOrEmpty(eventTitle) ? "Your prayer is now visible" : eventTitle,
                    relatedUserId: ReadPayloadString(payloadDict, "approverId"),
                    relatedUserName: approverName);
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Failed to save prayer-approved notification to DB: {ex.Message}");
        }
    }
}
