using Models.User;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices.Auth
{
    public interface IJwtService
    {
        Task<UserResponse?> AuthenticateUser(string Token);
        Task<UserResponse?> AuthenticateUserWithAccessToken(string accessToken);
    }
}
