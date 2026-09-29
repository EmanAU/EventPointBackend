using Dapper;

using Models.Reference;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DAL
{
    public class ReferenceDAL
    {
        public static async Task<IEnumerable<CategoryResponse>> GetCategoriesAsync()
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = "SELECT * FROM categories_get()";

                    var result = await conn.QueryAsync<CategoryResponse>(sql);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Log the error here
                throw new Exception("System Error: Could not retrieve categories.", ex);
            }
        }

        public static async Task<IEnumerable<SubCategoryResponse>> GetSubCategoriesByCategoryIdAsync(int categoryId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = "SELECT * FROM sub_category_get_by_category_id(@p_category_id)";
                    var parameters = new { p_category_id = categoryId };

                    var result = await conn.QueryAsync<SubCategoryResponse>(sql, parameters);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"System Error: Could not retrieve sub-categories for Category ID {categoryId}.", ex);
            }
        }

        public static async Task<IEnumerable<RelationshipTypeResponse>> GetRelationshipTypesAsync()
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: Calling the function
                    string sql = "SELECT * FROM ref_get_relationship_types()";

                    var result = await conn.QueryAsync<RelationshipTypeResponse>(sql);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Log the error
                throw new Exception("System Error: Could not retrieve relationship types. " + ex.Message);
            }
        }

        public static async Task<IEnumerable<RelationshipResponse>> GetRelationshipsByTypeAsync(int relationshipTypeId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = "SELECT * FROM ref_get_relationships_by_type(@InRelationshipTypeId)";

                    var parameters = new { InRelationshipTypeId = relationshipTypeId };

                    var result = await conn.QueryAsync<RelationshipResponse>(sql, parameters);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not retrieve relationships. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<ColorResponse>> GetColorsAsync()
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: Calling the function
                    string sql = "SELECT * FROM ref_get_colors()";

                    var result = await conn.QueryAsync<ColorResponse>(sql);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not retrieve colors. Error: " + ex.Message, ex);
            }
        }

        public static async Task<IEnumerable<EventPrivacyResponse>> GetEventPrivacyAsync()
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: Calling the function
                    string sql = "SELECT * FROM ref_get_event_privacy()";

                    var result = await conn.QueryAsync<EventPrivacyResponse>(sql);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not retrieve event privacy types. Error: " + ex.Message, ex);
            }
        }
    }
}
