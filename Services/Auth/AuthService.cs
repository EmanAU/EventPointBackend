using Google.Apis.Auth;
using Microsoft.Extensions.Configuration;
using Dapper;
using Npgsql;
using System.Data;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;

using IServices.Auth;
using DAL;
using Models.User;
using Models.Auth;

namespace Services.Auth
{
    public class AuthService : IAuthService
    {
        private readonly string _googleClientId;
        private static readonly HttpClient _httpClient = new();

        public AuthService(IConfiguration config)
        {
            _googleClientId = config["Google:ClientId"] ?? "";
        }

        /// <summary>
        /// Authenticate using a Google ID token (mobile flow).
        /// Validates the JWT signature directly with Google's public keys.
        /// </summary>
        public async Task<UserResponse?> GoogleLoginAsync(string TokenId)
        {
            GoogleJsonWebSignature.Payload payload;

            try
            {
                var settings = new GoogleJsonWebSignature.ValidationSettings()
                {
                    Audience = new[] { _googleClientId }
                };

                payload = await GoogleJsonWebSignature.ValidateAsync(TokenId, settings);
            }
            catch (InvalidJwtException)
            {
                throw new UnauthorizedAccessException("Invalid Google Token.");
            }

            return await FindOrCreateUser(payload.Email, payload.Name, payload.Picture);
        }

        /// <summary>
        /// Authenticate using a Google access token (web flow).
        /// Calls Google's userinfo endpoint to verify the token and get profile info.
        /// </summary>
        public async Task<UserResponse?> GoogleLoginWithAccessTokenAsync(string accessToken)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, "https://www.googleapis.com/oauth2/v3/userinfo");
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

            var response = await _httpClient.SendAsync(request);

            if (!response.IsSuccessStatusCode)
                throw new UnauthorizedAccessException("Invalid Google access token.");

            var json = await response.Content.ReadAsStringAsync();
            var userInfo = JsonSerializer.Deserialize<GoogleUserInfo>(json);

            if (userInfo == null || string.IsNullOrEmpty(userInfo.email))
                throw new UnauthorizedAccessException("Could not retrieve user info from Google.");

            return await FindOrCreateUser(userInfo.email, userInfo.name ?? "", userInfo.picture);
        }

        private async Task<UserResponse?> FindOrCreateUser(string email, string name, string? profileImageUrl = null)
        {
            var user = await UserDAL.GetUserByEmailAsync(email);

            if (user is not null)
                return user;

            CreateUserRequest createRequest = new CreateUserRequest
            {
                Email = email,
                Name = name,
                PhoneNumber = ""
            };
            var createResponse = await UserDAL.CreateUserAsync(createRequest);

            return new UserResponse
            {
                UserId = createResponse.UserId,
                Name = name,
                Email = email,
                ProfileImageUrl = profileImageUrl ?? "",
                RoleName = createResponse.RoleName,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
        }
    }

}
