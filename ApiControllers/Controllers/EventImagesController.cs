using Amazon.S3.Model;
using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.Images;
using Models.MixedFeed;


namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class EventImagesController : ControllerBase
    {
        private readonly IEventImageService _eventImageService;

        public EventImagesController(IEventImageService eventImageService)
        {
            _eventImageService = eventImageService;
        }

        [HttpPost("create-event-image")]
        public async Task<ActionResult<CreateEventImageResponse>> CreateEventImageAsync([FromBody] CreateEventImageRequest request)
        {

            try
            {
                var result = await _eventImageService.CreateEventImageAsync(request);

                // 200 OK - We return the result whether it was auto-approved or pending
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                // 403 Forbidden: User is not an admin or an approved guest
                return StatusCode(403, new { message = ex.Message });
            }
            catch (ArgumentException ex)
            {
                // 400 Bad Request: Missing ImageUrl
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpPost("approve-image")]
        public async Task<ActionResult<ApproveEventImageResponse>> ApproveEventImageAsync([FromBody] ApproveEventImageRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            try
            {
                var result = await _eventImageService.ApproveEventImageAsync(request);

                if (!result.IsSuccess)
                {
                    // Database returned: "Image not found."
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }

                    // Database returned: "Unauthorized: Only admins..."
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    // Fallback for any other logical DB rejections
                    return BadRequest(new { message = result.Message });
                }

                // 200 OK: "Image approved successfully."
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("private-event-images")]
        public async Task<ActionResult<IEnumerable<PrivateFeedImageResponse>>> GetPrivateFeedAsync([FromQuery] GetPrivateFeedRequest request)
        {
            // Basic validation
            if (string.IsNullOrEmpty(request.EventId) || string.IsNullOrEmpty(request.ViewerUserId))
            {
                return BadRequest(new { message = "EventId and ViewerUserId are required." });
            }

            if (request.PageSize <= 0 || request.PageSize > 100)
            {
                return BadRequest(new { message = "PageSize must be between 1 and 100." });
            }

            try
            {
                var result = await _eventImageService.GetPrivateFeedAsync(request);

                // 200 OK
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                // 403 Forbidden: "Unauthorized: You are not a guest of this event."
                return StatusCode(403, new { message = ex.Message });
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpPost("toggle-like")]
        public async Task<ActionResult<ToggleImageLikeResponse>> ToggleImageLikeAsync([FromBody] ToggleImageLikeRequest request)
        {
            try
            {
                var result = await _eventImageService.ToggleImageLikeAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }
                    return BadRequest(new { message = result.Message });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpDelete("delete-image")]
        public async Task<ActionResult<DeleteEventImageResponse>> DeleteEventImageAsync([FromBody] DeleteEventImageRequest request)
        {
            try
            {
                var result = await _eventImageService.DeleteEventImageAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }
                    return BadRequest(new { message = result.Message });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("public-event-images")]
        public async Task<ActionResult<IEnumerable<PublicImageFeedResponse>>> GetPublicImageFeedAsync([FromQuery] GetPublicImageFeedRequest request)
        {
            if (string.IsNullOrEmpty(request.EventId))
            {
                return BadRequest(new { message = "EventId is required." });
            }

            if (request.PageSize <= 0 || request.PageSize > 100)
            {
                return BadRequest(new { message = "PageSize must be between 1 and 100." });
            }

            try
            {
                var result = await _eventImageService.GetPublicImageFeedAsync(request);
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(403, new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("user-mixed-feed")]
        public async Task<ActionResult<IEnumerable<UserMixedImagesFeedResponse>>> GetUserMixedFeedAsync([FromQuery] UserMixedImagesFeedRequest request)
        {
            // ViewerId is strictly required to determine relationship context
            if (string.IsNullOrEmpty(request.ViewerId))
            {
                return BadRequest(new { message = "ViewerId is required." });
            }

            // Protect the database from massive queries while allowing the default to pass through
            if (request.Limit.HasValue && (request.Limit <= 0 || request.Limit > 100))
            {
                return BadRequest(new { message = "Limit must be between 1 and 100." });
            }

            try
            {
                // Assuming your service layer is injected as _eventImageService
                var result = await _eventImageService.GetUserMixedFeedAsync(request);
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(403, new { message = ex.Message });
            }
            catch (Exception ex)
            {
                // Log the actual exception in a real production environment
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }
    }
}
