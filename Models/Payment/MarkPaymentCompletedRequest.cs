namespace Models.Payment
{
    public class MarkPaymentCompletedRequest
    {
        public string BasketId { get; set; } = string.Empty;
        public string TransactionId { get; set; } = string.Empty;
    }
}
