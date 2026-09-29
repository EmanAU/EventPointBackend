namespace Models.Payment
{
    public class MarkPaymentFailedRequest
    {
        public string BasketId { get; set; } = string.Empty;
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
    }
}
