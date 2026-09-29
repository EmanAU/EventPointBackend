using IServices.Auth;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.Auth;
using Models.User;


namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly IJwtService _jwtService;
        private readonly ILogger<AuthController> _logger;

        public AuthController(IJwtService jwtService, ILogger<AuthController> logger)
        {
            _jwtService = jwtService;
            _logger = logger;
        }

        /// <summary>
        /// Mobile flow: receives a Google ID token (JWT) for server-side validation.
        /// </summary>
        [HttpPost("google-login")]
        public async Task<ActionResult<UserResponse>> LoginUserAsync([FromBody] GoogleLoginRequest request)
        {
            _logger.LogInformation("GoogleLogin: Token present={HasToken}", !string.IsNullOrWhiteSpace(request?.IdToken));
            try
            {
                if (request == null)
                {
                    _logger.LogWarning("GoogleLogin rejected: Request body is null.");
                    return BadRequest("Request body is required.");
                }

                if (string.IsNullOrWhiteSpace(request.IdToken))
                {
                    _logger.LogWarning("GoogleLogin rejected: No ID token.");
                    return BadRequest("Google ID token is required.");
                }

                var user = await _jwtService.AuthenticateUser(request.IdToken);

                if (user == null)
                {
                    _logger.LogWarning("GoogleLogin failed: Authentication failed.");
                    return Unauthorized("Authentication failed.");
                }

                _logger.LogInformation("GoogleLogin success: UserId={UserId}, Email={Email}", user.UserId, user.Email);
                return Ok(user);
            }
            catch (UnauthorizedAccessException ex)
            {
                _logger.LogWarning(ex, "GoogleLogin unauthorized");
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GoogleLogin error: Message={Message}", ex.Message);
                return BadRequest(ex.Message);
            }
        }

        /// <summary>
        /// Web flow: receives a Google access token (OAuth2) and verifies via Google's userinfo API.
        /// </summary>
        [HttpPost("google-login-web")]
        public async Task<ActionResult<UserResponse>> LoginUserWebAsync([FromBody] GoogleWebLoginRequest request)
        {
            _logger.LogInformation("GoogleLoginWeb: Token present={HasToken}", !string.IsNullOrWhiteSpace(request?.AccessToken));
            try
            {
                if (request == null)
                {
                    _logger.LogWarning("GoogleLoginWeb rejected: Request body is null.");
                    return BadRequest("Request body is required.");
                }

                if (string.IsNullOrWhiteSpace(request.AccessToken))
                {
                    _logger.LogWarning("GoogleLoginWeb rejected: No access token.");
                    return BadRequest("Google access token is required.");
                }

                var user = await _jwtService.AuthenticateUserWithAccessToken(request.AccessToken);

                if (user == null)
                {
                    _logger.LogWarning("GoogleLoginWeb failed: Authentication failed.");
                    return Unauthorized("Authentication failed.");
                }

                _logger.LogInformation("GoogleLoginWeb success: UserId={UserId}, Email={Email}", user.UserId, user.Email);
                return Ok(user);
            }
            catch (UnauthorizedAccessException ex)
            {
                _logger.LogWarning(ex, "GoogleLoginWeb unauthorized");
                return Unauthorized(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GoogleLoginWeb error: Message={Message}", ex.Message);
                return BadRequest(ex.Message);
            }
        }
    }
}
