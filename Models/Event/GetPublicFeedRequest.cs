namespace Models.Dtos;

public class GetPublicFeedRequest
{
    public int PageSize { get; set; } = 5;
    public DateTime? CursorDate { get; set; }
    public string? CursorEventId { get; set; }
    public string? Search { get; set; }
}
