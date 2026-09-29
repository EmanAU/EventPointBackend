using Microsoft.AspNetCore.Http;

namespace IServices
{
    public interface IImageUploadService
    {
        Task<string> UploadImageAsync(IFormFile file);
    }
}
