using DAL;
using IServices;
using Microsoft.AspNetCore.Http;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Models.User;

namespace Services
{
    public class UserService : IUserService
    {
        private readonly IImageUploadService _imageUploadService;

        public UserService(IImageUploadService imageUploadService)
        {
            _imageUploadService = imageUploadService;
        }

        public async Task<UpdateUserProfileResponse> UpdateUserProfileAsync(UpdateUserProfileRequest request)
        {
            return await UserDAL.UpdateUserProfileAsync(request);
        }

        public async Task<UserResponse?> GetUserByIdAsync(string userId)
        {
            return await UserDAL.GetUserByIdAsync(userId);
        }

        public async Task<string> UploadProfileImageAsync(IFormFile file)
        {
            return await _imageUploadService.UploadImageAsync(file);
        }
    }
}
