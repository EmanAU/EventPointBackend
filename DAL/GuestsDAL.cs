using Dapper;

using Models.Guest;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DAL
{
    public class GuestsDAL
    {
        public static async Task<ApproveGuestResponse> ApproveGuestAsync(ApproveGuestRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM event_guest_approve(
                    @AdminUserId,
                    @TargetGuestId,
                    @EventId,
                    @RelationshipTypeId,
                    @RelationshipId
                )";

                    // Execute: Dapper maps request properties to the @Parameters automatically
                    var result = await conn.QuerySingleAsync<ApproveGuestResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Log the error
                throw new Exception("System Error: Could not approve the guest. " + ex);
            }
        }

        public static async Task<PromoteAdminResponse> PromoteAdminAsync(PromoteAdminRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_admin_promote(
                    @CreatorUserId,
                    @TargetGuestUserId,
                    @EventId,
                    @ColorId
                )";

                    var result = await conn.QuerySingleAsync<PromoteAdminResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not promote the guest to admin. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<ApprovedGuestResponse>> GetApprovedGuestsAsync(GetApprovedGuestsRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_get_approved_guests(
                    @EventId,
                    @RequestingUserId
                )";

                    var result = await conn.QueryAsync<ApprovedGuestResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Catch the explicit RAISE EXCEPTION 'Unauthorized: ...' from the SQL function
                if (ex.SqlState == "P0001")
                {
                    throw new UnauthorizedAccessException(ex.MessageText);
                }

                throw new Exception("System Error: Could not retrieve approved guests. Error: " + ex.Message, ex);
            }
        }

        public static async Task<RemoveGuestResponse> RemoveGuestAsync(RemoveGuestRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_guest_remove(
                    @AdminUserId,
                    @TargetUserId,
                    @EventId
                )";

                    var result = await conn.QuerySingleAsync<RemoveGuestResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not remove the user. Error: " + ex.Message, ex);
            }
        }

        public static async Task<DemoteAdminResponse> DemoteAdminAsync(DemoteAdminRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM event_admin_demote(
                    @CreatorUserId,
                    @TargetAdminUserId,
                    @EventId
                )";

                    var result = await conn.QuerySingleAsync<DemoteAdminResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not demote the admin. Error: " + ex.Message, ex);
            }
        }
    }
}
