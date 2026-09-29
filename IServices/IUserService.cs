using Microsoft.AspNetCore.Http;
using Models.User;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace IServices
{
    public interface IUserService
    {
        Task<UpdateUserProfileResponse> UpdateUserProfileAsync(UpdateUserProfileRequest request);
        Task<UserResponse?> GetUserByIdAsync(string userId);
        Task<string> UploadProfileImageAsync(IFormFile file);
    }
}
