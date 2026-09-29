namespace Models.Dtos;

public class GetPendingRequestsRequest
{
    public string AdminUserId { get; set; } = string.Empty;
    public string EventId { get; set; } = string.Empty;
}
