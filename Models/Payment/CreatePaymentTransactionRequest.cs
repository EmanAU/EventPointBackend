namespace Models.Payment
{
    public class CreatePaymentTransactionRequest
    {
        /// <summary>Character-varying event id (matches the app's event_id format).</summary>
        public string EventId { get; set; } = string.Empty;
        /// <summary>Character-varying user id / JWT name claim value.</summary>
        public string UserId { get; set; } = string.Empty;
        public string BasketId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "PKR";
        public string AccessToken { get; set; } = string.Empty;
        public string CustomerEmail { get; set; } = string.Empty;
        public string CustomerPhone { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
    }
}
