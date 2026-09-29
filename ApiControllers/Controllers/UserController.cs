using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.User;


namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class UserController : ControllerBase
    {
        private readonly IUserService _userService;

        public UserController(IUserService userService)
        {
            _userService = userService;
        }

        [HttpPut("update-profile")]
        public async Task<ActionResult<UpdateUserProfileResponse>> UpdateUserProfileAsync([FromBody] UpdateUserProfileRequest request)
        {
            try
            {
                var result = await _userService.UpdateUserProfileAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }

                    if (result.Message.Contains("empty"))
                    {
                        return BadRequest(new { message = result.Message });
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

        [HttpGet("get-user/{userId}")]
        public async Task<ActionResult<UserResponse>> GetUserByIdAsync(string userId)
        {
            try
            {
                var result = await _userService.GetUserByIdAsync(userId);

                if (result == null)
                {
                    return NotFound(new { message = "User not found." });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpPost("upload-profile-image")]
        public async Task<ActionResult> UploadProfileImageAsync(IFormFile file)
        {
            try
            {
                var imageUrl = await _userService.UploadProfileImageAsync(file);
                return Ok(new { imageUrl });
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "Image upload failed. Error: " + ex.Message });
            }
        }
    }
}