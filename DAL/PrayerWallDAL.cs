
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using Models.PrayerWall;

namespace DAL
{
    public class PrayerWallDAL
    {
        public static async Task<ApprovePrayerResponse> ApprovePrayerAsync(ApprovePrayerRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM prayer_approve(
                    @EventId,
                    @PrayerId,
                    @AdminUserId
                )";

                    var result = await conn.QuerySingleAsync<ApprovePrayerResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not approve the prayer. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<PrayerParticipantResponse>> GetPrayerParticipantsAsync(string eventId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM prayer_get_participants(
                    @EventId
                )";

                    var result = await conn.QueryAsync<PrayerParticipantResponse>(sql, new { EventId = eventId });

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not retrieve prayer participants. Error: " + ex.Message, ex);
            }
        }

        public static async Task<string?> GetPrayerAuthorUserIdAsync(string eventId, string prayerId)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();
                    const string sql = """
                        SELECT fk_user_id::text
                        FROM event_prayers
                        WHERE pk_event_prayer_id = @PrayerId AND fk_event_id = @EventId
                        LIMIT 1
                        """;
                    return await conn.QuerySingleOrDefaultAsync<string>(sql, new { EventId = eventId, PrayerId = prayerId });
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not resolve prayer author. Error: " + ex.Message, ex);
            }
        }

        public static async Task<PostOrUpdatePrayerResponse> PostOrUpdatePrayerAsync(PostOrUpdatePrayerRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM prayer_post_or_update(
                    @EventId,
                    @UserId,
                    @MessageText
                )";

                    var result = await conn.QuerySingleAsync<PostOrUpdatePrayerResponse>(sql, request);

                    if (result.IsSuccess && !string.IsNullOrEmpty(result.PrayerId))
                    {
                        const string pendingSql = @"
                            SELECT NOT COALESCE(ep.is_approved, FALSE)
                            FROM event_prayers ep
                            WHERE ep.pk_event_prayer_id = @PrayerId AND ep.fk_event_id = @EventId";
                        var needsApproval = await conn.QuerySingleOrDefaultAsync<bool?>(
                            pendingSql,
                            new { result.PrayerId, request.EventId });
                        if (needsApproval != null)
                            result.PendingApproval = needsApproval.Value;
                    }

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not post or update the prayer. Error: " + ex.Message, ex);
            }
        }

        public static async Task<DeletePrayerResponse> DeletePrayerAsync(DeletePrayerRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM prayer_delete(
                    @EventId,
                    @PrayerId,
                    @RequestingUserId
                )";

                    var result = await conn.QuerySingleAsync<DeletePrayerResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not delete the prayer. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<PrayerResponse>> GetPrayersAsync(GetPrayersRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM prayers_get(
                    @EventId,
                    @ViewerUserId
                )";

                    var result = await conn.QueryAsync<PrayerResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Catch the explicit RAISE EXCEPTION from the SQL function (Privacy block)
                if (ex.SqlState == "P0001")
                {
                    throw new UnauthorizedAccessException(ex.MessageText);
                }

                throw new Exception("System Error: Could not retrieve prayers. Error: " + ex.Message, ex);
            }
        }
    }
}
