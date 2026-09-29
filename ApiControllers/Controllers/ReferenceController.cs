using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.Reference;
using Services;

namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class ReferenceController : ControllerBase
    {
        private readonly IReferenceService _referenceService;

        public ReferenceController(IReferenceService referenceService)
        {
            _referenceService = referenceService;
        }

        [HttpGet("categories")]
        public async Task<ActionResult<IEnumerable<CategoryResponse>>> GetCategoriesAsync()
        {
            try
            {
                var result = await _referenceService.GetCategoriesAsync();

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An error occurred while fetching categories.\nError: " + ex.Message });
            }
        }

        [HttpGet("sub-categories")]
        public async Task<ActionResult<IEnumerable<SubCategoryResponse>>> GetSubCategoriesAsync([FromQuery] int categoryId)
        {
            if (categoryId <= 0)
            {
                return BadRequest(new { message = "Invalid Category ID provided." });
            }

            try
            {
                var result = await _referenceService.GetSubCategoriesByCategoryIdAsync(categoryId);

                // 200 OK
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An error occurred while fetching sub-categories. " + ex.Message });
            }
        }

        [HttpGet("relationship-types")]
        public async Task<ActionResult<IEnumerable<RelationshipTypeResponse>>> GetRelationshipTypesAsync()
        {
            try
            {
                var result = await _referenceService.GetRelationshipTypesAsync();

                // 200 OK
                return Ok(result);
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred while fetching relationship types. " + ex.Message });
            }
        }

        [HttpGet("relationships")]
        public async Task<ActionResult<IEnumerable<RelationshipResponse>>> GetRelationshipsByTypeAsync([FromQuery] int relationshipTypeId)
        {
            // Basic validation
            if (relationshipTypeId <= 0)
            {
                return BadRequest(new { message = "Invalid Relationship Type ID provided." });
            }

            try
            {
                var result = await _referenceService.GetRelationshipsByTypeAsync(relationshipTypeId);

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("colors")]
        public async Task<ActionResult<IEnumerable<ColorResponse>>> GetColorsAsync()
        {
            try
            {
                var result = await _referenceService.GetColorsAsync();

                // 200 OK
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("event-privacy")]
        public async Task<ActionResult<IEnumerable<EventPrivacyResponse>>> GetEventPrivacyAsync()
        {
            try
            {
                var result = await _referenceService.GetEventPrivacyAsync();

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }
    }
}
