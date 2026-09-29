using Models.Reference;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IReferenceService
    {
        Task<IEnumerable<CategoryResponse>> GetCategoriesAsync();
        Task<IEnumerable<SubCategoryResponse>> GetSubCategoriesByCategoryIdAsync(int categoryId);
        Task<IEnumerable<RelationshipTypeResponse>> GetRelationshipTypesAsync();
        Task<IEnumerable<RelationshipResponse>> GetRelationshipsByTypeAsync(int relationshipTypeId);
        Task<IEnumerable<ColorResponse>> GetColorsAsync();
        Task<IEnumerable<EventPrivacyResponse>> GetEventPrivacyAsync();
    }
}
