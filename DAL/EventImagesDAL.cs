
using Dapper;
using Models.Images;
using Models.MixedFeed;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DAL
{
    public class EventImagesDAL
    {
        public static async Task<CreateEventImageResponse> CreateEventImageAsync(CreateEventImageRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_image_create(
                    @EventId,
                    @UserId,
                    @ImageUrl,
                    @Caption,
                    @RelationshipTypeId
                )";

                    var result = await conn.QuerySingleAsync<CreateEventImageResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Handle explicit RAISE EXCEPTION messages from the SQL function
                if (ex.SqlState == "P0001")
                {
                    if (ex.MessageText.Contains("Unauthorized"))
                    {
                        throw new UnauthorizedAccessException(ex.MessageText);
                    }

                    // For 'Image URL cannot be empty'
                    throw new ArgumentException(ex.MessageText);
                }

                throw new Exception("System Error: Could not upload the image. Error: " + ex.Message, ex);
            }
        }

        public static async Task<ApproveEventImageResponse> ApproveEventImageAsync(ApproveEventImageRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_image_approve(
                    @AdminUserId,
                    @ImageId
                )";

                    var result = await conn.QuerySingleAsync<ApproveEventImageResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not approve the image. Error: " + ex.Message, ex);
            }
        }

        public static async Task<ToggleImageLikeResponse> ToggleImageLikeAsync(ToggleImageLikeRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM image_toggle_like(
                    @UserId,
                    @ImageId
                )";

                    var result = await conn.QuerySingleAsync<ToggleImageLikeResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not toggle image like. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<PrivateFeedImageResponse>> GetPrivateFeedAsync(GetPrivateFeedRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM image_get_feed_private(
                    @EventId,
                    @ViewerUserId,
                    @PageSize,
                    @CursorDate,
                    @CursorImageId
                )";

                    var result = await conn.QueryAsync<PrivateFeedImageResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Catch the explicit RAISE EXCEPTION from the SQL function (Privacy block)
                if (ex.SqlState == "P0001" && ex.MessageText.Contains("Unauthorized"))
                {
                    throw new UnauthorizedAccessException(ex.MessageText);
                }

                throw new Exception("System Error: Could not retrieve the private feed. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<PublicImageFeedResponse>> GetPublicImageFeedAsync(GetPublicImageFeedRequest request)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM image_get_feed_public(
                    @EventId,
                    @PageSize,
                    @CursorDate,
                    @CursorImageId
                )";

                    var result = await conn.QueryAsync<PublicImageFeedResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Catch the explicit RAISE EXCEPTION from the SQL function (Private event block)
                if (ex.SqlState == "P0001" && ex.MessageText.Contains("private and cannot be viewed"))
                {
                    throw new UnauthorizedAccessException(ex.MessageText);
                }

                throw new Exception("System Error: Could not retrieve the public image feed. Error: " + ex.Message, ex);
            }
        }

        public static async Task<DeleteEventImageResponse> DeleteEventImageAsync(DeleteEventImageRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM event_image_delete(
                    @EventId,
                    @ImageId,
                    @RequestingUserId
                )";

                    var result = await conn.QuerySingleAsync<DeleteEventImageResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not delete the image. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<UserMixedImagesFeedResponse>> GetUserMixedFeedAsync(UserMixedImagesFeedRequest request)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly.
                    // We use COALESCE so that if the C# request object passes null, 
                    // Postgres will fall back to your intended default values.
                    string sql = @"
            SELECT * FROM get_user_mixed_image_feed(
                @ViewerId,
                COALESCE(@CursorTime, NOW()),
                COALESCE(@CursorId, 'ZZZZZZZZ'),
                COALESCE(@Limit, 20)
            )";

                    var result = await conn.QueryAsync<UserMixedImagesFeedResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Add any explicit RAISE EXCEPTION handling here if you add custom error states to this function
                // (e.g., if you eventually throw an error when a user doesn't exist)
                throw new Exception("System Error: Could not retrieve the user mixed image feed. Error: " + ex.Message, ex);
            }
            catch (Exception ex)
            {
                throw new Exception("An unexpected error occurred while retrieving the feed. Error: " + ex.Message, ex);
            }
        }
    }
}
