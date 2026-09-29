using DAL;
using IServices;
using IServices.Auth;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;
using Models.User;
using System;
using System.Collections.Generic;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Services.Auth
{
    public class JwtService : IJwtService
    {
        private readonly IConfiguration _configurations;
        private readonly IAuthService _authService;

        public JwtService(IConfiguration configurations, IAuthService authService)
        {
            _configurations = configurations ?? throw new ArgumentNullException(nameof(configurations));
            _authService = authService;
        }


        public async Task<UserResponse?> AuthenticateUser(string Token)
        {
            if (string.IsNullOrEmpty(Token))
                return null;

            var loginResponse = await _authService.GoogleLoginAsync(Token);
            return GenerateJwt(loginResponse);
        }

        public async Task<UserResponse?> AuthenticateUserWithAccessToken(string accessToken)
        {
            if (string.IsNullOrEmpty(accessToken))
                return null;

            var loginResponse = await _authService.GoogleLoginWithAccessTokenAsync(accessToken);
            return GenerateJwt(loginResponse);
        }

        private UserResponse? GenerateJwt(UserResponse? loginResponse)
        {
            if (loginResponse == null)
                return null;

            var issuer = _configurations["JwtConfig:Issuer"];
            var audience = _configurations["JwtConfig:Audience"];
            var key = _configurations["JwtConfig:Key"];

            if (string.IsNullOrEmpty(issuer))
                throw new InvalidOperationException("JWT Issuer configuration is missing or empty.");

            if (string.IsNullOrEmpty(audience))
                throw new InvalidOperationException("JWT Audience configuration is missing or empty.");

            if (string.IsNullOrEmpty(key))
                throw new InvalidOperationException("JWT Key configuration is missing or empty.");

            var tokenValidityMins = _configurations.GetValue<int>("JwtConfig:TokenValidityMins");
            if (tokenValidityMins <= 0)
                throw new InvalidOperationException("JWT TokenValidityMins must be greater than 0.");

            var tokenExpiryTimeStamp = DateTime.UtcNow.AddMinutes(tokenValidityMins);

            var tokenDescription = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(JwtRegisteredClaimNames.Name, loginResponse.UserId)
                }),
                Expires = tokenExpiryTimeStamp,
                Issuer = issuer,
                Audience = audience,
                SigningCredentials = new SigningCredentials(
                    new SymmetricSecurityKey(Encoding.ASCII.GetBytes(key)),
                    SecurityAlgorithms.HmacSha512Signature),
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var securityToken = tokenHandler.CreateToken(tokenDescription);
            var accessToken = tokenHandler.WriteToken(securityToken);

            return new UserResponse
            {
                AccessToken = accessToken,
                Name = loginResponse.Name,
                ProfileImageUrl = loginResponse.ProfileImageUrl ?? "",
                ExpiresIn = (int)tokenExpiryTimeStamp.Subtract(DateTime.UtcNow).TotalSeconds,
                UserId = loginResponse.UserId,
                Email = loginResponse.Email,
                RoleName = loginResponse.RoleName,
                CreatedAt = loginResponse.CreatedAt,
                UpdatedAt = loginResponse.UpdatedAt
            };
        }

    }
}
