namespace Models.Dtos;

public class InvitationCardResponse
{
    public string Headline { get; set; } = string.Empty;
    public string CoupleNames { get; set; } = string.Empty;
    public string InvitationText { get; set; } = string.Empty;
    public string EventDate { get; set; } = string.Empty;
    public string EventTime { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Address { get; set; } = string.Empty;
    public int TemplateId { get; set; }
}
