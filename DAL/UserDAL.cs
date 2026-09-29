using Dapper;

using Models.User;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DAL
{
    public class UserDAL
    {
        public static async Task<CreateUserResponse> CreateUserAsync(CreateUserRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // FIX: Use SELECT syntax because functions return data
                    string sql = "SELECT * FROM user_create(@p_name, @p_email, @p_phone_number)";

                    var parameters = new
                    {
                        p_name = request.Name,
                        p_email = request.Email,
                        p_phone_number = request.PhoneNumber
                    };

                    // FIX: Use default CommandType (Text), not StoredProcedure
                    var result = await conn.QuerySingleAsync<CreateUserResponse>(
                        sql,
                        parameters
                    );

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Your error handling logic here is excellent! Keep it.

                // Code 23505: Unique Constraint Violation
                if (ex.SqlState == "23505")
                {
                    throw new InvalidOperationException($"The email '{request.Email}' is already registered.");
                }

                // Code P0001: Custom RAISE EXCEPTION
                if (ex.SqlState == "P0001")
                {
                    throw new InvalidOperationException(ex.MessageText);
                }

                throw new Exception("System Error: Could not create user.", ex);
            }
        }
        public static async Task<UserCheckResponse> CheckUserExistAsync(string email)
        {

            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string functionName = "user_check_if_exist";

                    var parameters = new
                    {
                        p_email = email
                    };


                    var result = await conn.QuerySingleAsync<UserCheckResponse>(
                        functionName,
                        parameters,
                        commandType: CommandType.StoredProcedure
                    );

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error checking user existence: {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                throw new Exception("System Error: Could not check user existence.", ex);
            }
        }
        public static async Task<UserResponse?> GetUserByIdAsync(string userId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // Use raw SQL - CommandType.StoredProcedure doesn't work reliably with PostgreSQL
                    string sql = "SELECT * FROM user_get_by_id(@_user_id)";
                    var parameters = new { _user_id = userId };

                    var result = await conn.QuerySingleOrDefaultAsync<UserResponse>(sql, parameters);
                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: Could not retrieve user. {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                throw new Exception("System Error: An unexpected error occurred.", ex);
            }
        }
        public static async Task<UserResponse?> GetUserByEmailAsync(string email)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // FIX: Write the SQL explicitly using SELECT * FROM
                    string sql = "SELECT * FROM user_get_by_email(@p_user_email)";

                    // Important: Parameter name in C# must match the @parameter in the string above
                    var parameters = new
                    {
                        p_user_email = email
                    };

                    // FIX: Remove 'CommandType.StoredProcedure' or change it to 'Text' (default)
                    var result = await conn.QuerySingleOrDefaultAsync<UserResponse>(
                        sql,
                        parameters
                    );

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<UpdateUserProfileResponse> UpdateUserProfileAsync(UpdateUserProfileRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM user_update_profile(
                    @UserId,
                    @NewName,
                    @NewProfileImageUrl,
                    @NewCity,
                    @NewCountry
                )";

                    var result = await conn.QuerySingleAsync<UpdateUserProfileResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not update user profile. Error: " + ex.Message, ex);
            }
        }
    }
}
