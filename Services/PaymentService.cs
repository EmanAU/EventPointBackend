using System.Threading.Tasks;
using DAL;
using IServices;
using Models.Payment;

namespace Services
{
    public class PaymentService : IPaymentService
    {
        public Task<PaymentTransactionResponse> CreateAsync(CreatePaymentTransactionRequest request)
            => PaymentDAL.CreateAsync(request);

        public Task<PaymentTransactionResponse?> GetByBasketAsync(string basketId)
            => PaymentDAL.GetByBasketAsync(basketId);

        public Task<PaymentTransactionResponse?> MarkCompletedAsync(MarkPaymentCompletedRequest request)
            => PaymentDAL.MarkCompletedAsync(request);

        public Task<PaymentTransactionResponse?> MarkFailedAsync(MarkPaymentFailedRequest request)
            => PaymentDAL.MarkFailedAsync(request);

        public Task<PaymentUnlockStatusResponse> IsUnlockedAsync(string eventId, string userId)
            => PaymentDAL.IsUnlockedAsync(eventId, userId);
    }
}
