using Amazon.Runtime;
using Amazon.S3;
using Amazon.S3.Model;
using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;

namespace Services
{
    public class ImageUploadService : IImageUploadService
    {
        private readonly IAmazonS3 _s3Client;
        private readonly string _bucketName;
        private readonly string _publicDomain;

        public ImageUploadService(IConfiguration config)
        {
            var r2Config = config.GetSection("R2Config");

            _bucketName = r2Config["BucketName"]
                ?? throw new InvalidOperationException("BucketName missing");

            _publicDomain = r2Config["PublicDomain"]
                ?? throw new InvalidOperationException("PublicDomain missing");

            var accessKey = r2Config["AccessKey"]
                ?? throw new InvalidOperationException("AccessKey missing");

            var secretKey = r2Config["SecretKey"]
                ?? throw new InvalidOperationException("SecretKey missing");

            var serviceUrl = r2Config["ServiceUrl"]
                ?? throw new InvalidOperationException("ServiceUrl missing");

            var credentials = new BasicAWSCredentials(accessKey, secretKey);

            var s3Config = new AmazonS3Config
            {
                ServiceURL = serviceUrl,
                AuthenticationRegion = "auto"
            };

            _s3Client = new AmazonS3Client(credentials, s3Config);
        }

        private async Task<string> UploadToStorageAsync(
            Stream fileStream,
            string fileName,
            string contentType)
        {
            try
            {
                var request = new PutObjectRequest
                {
                    InputStream = fileStream,
                    BucketName = _bucketName,
                    Key = fileName,
                    ContentType = contentType,
                    DisablePayloadSigning = true
                };

                var response = await _s3Client.PutObjectAsync(request);

                if (response.HttpStatusCode != System.Net.HttpStatusCode.OK)
                    throw new Exception("Storage upload failed.");

                return $"{_publicDomain}/{fileName}";
            }
            catch (AmazonS3Exception ex)
            {
                throw new Exception($"Storage error: {ex.Message}", ex);
            }
            catch (IOException ex)
            {
                throw new Exception("File stream error.", ex);
            }
            catch (Exception ex)
            {
                throw new Exception("Unexpected upload error.", ex);
            }
        }

        public async Task<string> UploadImageAsync(IFormFile file)
        {
            if (file == null || file.Length == 0)
                throw new ArgumentException("No file uploaded.");

            if (file.Length > 5 * 1024 * 1024)
                throw new ArgumentException("File too large (max 5MB).");

            if (!file.ContentType.StartsWith("image/"))
                throw new ArgumentException("Only image files allowed.");

            var extension = Path.GetExtension(file.FileName);
            var fileName = $"images/{Guid.NewGuid()}{extension}";

            try
            {
                using var stream = file.OpenReadStream();
                return await UploadToStorageAsync(stream, fileName, file.ContentType);
            }
            catch (Exception ex)
            {
                throw new Exception("Image upload failed.", ex);
            }
        }
    }

}
