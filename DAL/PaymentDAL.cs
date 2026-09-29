using Dapper;
using Models.Payment;
using Npgsql;
using System;
using System.Threading.Tasks;

namespace DAL
{
    /// <summary>
    /// Data-access for pamphlet payment transactions. EventId and UserId are
    /// VARCHAR strings throughout (the app uses character varying IDs, never UUID
    /// for those two fields).
    /// </summary>
    public static class PaymentDAL
    {
        public static async Task<PaymentTransactionResponse> CreateAsync(CreatePaymentTransactionRequest request)
        {
            await using var conn = new NpgsqlConnection(DBHelper.GetConnection());
            await conn.OpenAsync();
            const string sql = @"
                SELECT * FROM pamphlet_payment_create(
                    @EventId, @UserId, @BasketId, @Amount, @Currency,
                    @AccessToken, @CustomerEmail, @CustomerPhone, @CustomerName
                )";
            return await conn.QuerySingleAsync<PaymentTransactionResponse>(sql, request);
        }

        public static async Task<PaymentTransactionResponse?> GetByBasketAsync(string basketId)
        {
            await using var conn = new NpgsqlConnection(DBHelper.GetConnection());
            await conn.OpenAsync();
            const string sql = "SELECT * FROM pamphlet_payment_get_by_basket(@BasketId)";
            return await conn.QuerySingleOrDefaultAsync<PaymentTransactionResponse>(sql, new { BasketId = basketId });
        }

        public static async Task<PaymentTransactionResponse?> MarkCompletedAsync(MarkPaymentCompletedRequest request)
        {
            await using var conn = new NpgsqlConnection(DBHelper.GetConnection());
            await conn.OpenAsync();
            const string sql = "SELECT * FROM pamphlet_payment_mark_completed(@BasketId, @TransactionId)";
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>(sql, request);
            if (row == null) return null;
            return await GetByBasketAsync((string)row.BasketId);
        }

        public static async Task<PaymentTransactionResponse?> MarkFailedAsync(MarkPaymentFailedRequest request)
        {
            await using var conn = new NpgsqlConnection(DBHelper.GetConnection());
            await conn.OpenAsync();
            const string sql = "SELECT * FROM pamphlet_payment_mark_failed(@BasketId, @ErrorCode, @ErrorMessage)";
            var row = await conn.QuerySingleOrDefaultAsync<dynamic>(sql, request);
            if (row == null) return null;
            return await GetByBasketAsync((string)row.BasketId);
        }

        public static async Task<PaymentUnlockStatusResponse> IsUnlockedAsync(string eventId, string userId)
        {
            await using var conn = new NpgsqlConnection(DBHelper.GetConnection());
            await conn.OpenAsync();
            const string sql = "SELECT * FROM pamphlet_payment_is_unlocked(@EventId, @UserId)";
            var row = await conn.QuerySingleOrDefaultAsync<PaymentUnlockStatusResponse>(
                sql, new { EventId = eventId, UserId = userId });
            return row ?? new PaymentUnlockStatusResponse { IsUnlocked = false };
        }
    }
}
