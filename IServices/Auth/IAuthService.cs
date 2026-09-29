
using Models.User;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices.Auth
{
    public interface IAuthService
    {
        Task<UserResponse?> GoogleLoginAsync(string TokenId);
        Task<UserResponse?> GoogleLoginWithAccessTokenAsync(string accessToken);
    }
}
