using Microsoft.AspNetCore.SignalR;

namespace ApiControllers.Hubs;

/// <summary>
/// Logs hub invocation failures with full exception detail (works with EnableDetailedErrors for clients).
/// </summary>
public sealed class SignalRHubExceptionLoggingFilter : IHubFilter
{
    private readonly ILogger<SignalRHubExceptionLoggingFilter> _logger;

    public SignalRHubExceptionLoggingFilter(ILogger<SignalRHubExceptionLoggingFilter> logger)
    {
        _logger = logger;
    }

    public async ValueTask<object?> InvokeMethodAsync(
        HubInvocationContext invocationContext,
        Func<HubInvocationContext, ValueTask<object?>> next)
    {
        var hub = invocationContext.Hub.GetType().Name;
        var method = invocationContext.HubMethodName;
        try
        {
            return await next(invocationContext);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "SignalR hub invocation failed: Hub={Hub}, Method={Method}, ConnectionId={ConnectionId}, User={User}",
                hub,
                method,
                invocationContext.Context.ConnectionId,
                invocationContext.Context.User?.Identity?.Name ?? "(anonymous)");
            throw;
        }
    }
}
