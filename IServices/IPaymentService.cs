using System.Threading.Tasks;
using Models.Payment;

namespace IServices
{
    public interface IPaymentService
    {
        Task<PaymentTransactionResponse> CreateAsync(CreatePaymentTransactionRequest request);
        Task<PaymentTransactionResponse?> GetByBasketAsync(string basketId);
        Task<PaymentTransactionResponse?> MarkCompletedAsync(MarkPaymentCompletedRequest request);
        Task<PaymentTransactionResponse?> MarkFailedAsync(MarkPaymentFailedRequest request);
        Task<PaymentUnlockStatusResponse> IsUnlockedAsync(string eventId, string userId);
    }
}
