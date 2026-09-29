using Microsoft.Extensions.Configuration;

namespace DAL
{
    public class DBHelper
    {
        private static IConfiguration? _config;

        public static void Init(IConfiguration config)
        {
            _config = config;
        }

        public static string GetConnection()
        {
            var conn = _config?.GetConnectionString("DefaultConnection");
            if (!string.IsNullOrEmpty(conn))
                return conn;
            return "Host=localhost;Username=postgres;Password=admin;Database=dbEventpoint;Include Error Detail=True";
        }
    }
}
