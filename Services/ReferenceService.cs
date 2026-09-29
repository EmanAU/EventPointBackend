using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using DAL;
using IServices;

using Models.Reference;


namespace Services
{
    public class ReferenceService : IReferenceService
    {
        public async Task<IEnumerable<CategoryResponse>> GetCategoriesAsync()
        {
            return await ReferenceDAL.GetCategoriesAsync();
        }

        public async Task<IEnumerable<SubCategoryResponse>> GetSubCategoriesByCategoryIdAsync(int categoryId)
        {
            return await ReferenceDAL.GetSubCategoriesByCategoryIdAsync(categoryId);
        }
        public async Task<IEnumerable<RelationshipTypeResponse>> GetRelationshipTypesAsync()
        {
            return await ReferenceDAL.GetRelationshipTypesAsync();
        }

        public async Task<IEnumerable<RelationshipResponse>> GetRelationshipsByTypeAsync(int relationshipTypeId)
        {
            return await ReferenceDAL.GetRelationshipsByTypeAsync(relationshipTypeId);
        }

        public async Task<IEnumerable<ColorResponse>> GetColorsAsync()
        {
            return await ReferenceDAL.GetColorsAsync();
        }

        public async Task<IEnumerable<EventPrivacyResponse>> GetEventPrivacyAsync()
        {
            return await ReferenceDAL.GetEventPrivacyAsync();
        }
    }
}
