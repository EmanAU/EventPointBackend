using System;

namespace Models.Payment
{
    /// <summary>Full row returned by pamphlet_payment_* Postgres functions.</summary>
    public class PaymentTransactionResponse
    {
        public Guid PaymentId { get; set; }
        /// <summary>Matches the character-varying event_id used throughout the app.</summary>
        public string EventId { get; set; } = string.Empty;
        /// <summary>Matches the character-varying user_id / JWT name claim.</summary>
        public string UserId { get; set; } = string.Empty;
        public string BasketId { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "PKR";
        public string Gateway { get; set; } = "gopayfast";
        public string Status { get; set; } = "pending";
        public string AccessToken { get; set; } = string.Empty;
        public string TransactionId { get; set; } = string.Empty;
        public string ErrorCode { get; set; } = string.Empty;
        public string ErrorMessage { get; set; } = string.Empty;
        public string CustomerEmail { get; set; } = string.Empty;
        public string CustomerPhone { get; set; } = string.Empty;
        public string CustomerName { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public DateTime? CompletedAt { get; set; }
    }
}
