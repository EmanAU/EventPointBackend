using System;

namespace Models.Payment
{
    /// <summary>Returned by GET /api/payment/pamphlet-status?eventId=..&userId=..</summary>
    public class PaymentUnlockStatusResponse
    {
        public bool IsUnlocked { get; set; }
        public Guid? PaymentId { get; set; }
        public string BasketId { get; set; } = string.Empty;
        public DateTime? CompletedAt { get; set; }
    }
}
