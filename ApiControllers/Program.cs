using ApiControllers.Hubs;
using ApiControllers.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using DAL;
using IServices;
using IServices.Auth;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Services;
using Services.Auth;
using System.Net;
using System.Text;
using Serilog;

var builder = WebApplication.CreateBuilder(args);


builder.Host.UseSerilog((context, configuration) =>
        configuration
            .ReadFrom.Configuration(context.Configuration)
            .WriteTo.Console() // Keeps your standard console output
            .WriteTo.File(
                path: "logs/api-log-.txt",
                rollingInterval: RollingInterval.Day, // Creates a new file at midnight (e.g., api-log-20240521.txt)
                retainedFileCountLimit: 30 // Automatically deletes logs older than 30 days to save disk space
            )
    );

// Listen on all interfaces so Android emulator (10.0.2.2) and LAN devices can reach the API.
builder.WebHost.UseUrls("http://0.0.0.0:5249");

//builder.Logging.AddFilter("Microsoft.AspNetCore.SignalR", LogLevel.Information);
//builder.Logging.AddFilter("Microsoft.AspNetCore.Http.Connections", LogLevel.Information);

DBHelper.Init(builder.Configuration);

// Exact origins for production + local dev. In Development, any http://<IP>:3000 is also allowed
// so Next.js (`npm run dev -H 0.0.0.0`) works from emulators / phones via LAN IP or 10.0.2.2.
var corsExactOrigins = new HashSet<string>(StringComparer.Ordinal)
{
    "http://localhost:5249",
    "http://localhost:3000",
    "http://localhost:8080",
    "http://localhost:8081",
    "http://127.0.0.1:5249",
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8080",
    "http://127.0.0.1:8081",
    "http://10.0.2.2:5249",
    "http://10.0.2.2:3000",
    "http://10.0.2.2:8080",
    "http://10.0.2.2:8081",
    "https://www.careho.pk",
    "http://www.careho.pk",
    // Deployed pamphlet / payment Next.js app (Vercel)
    "https://event-point-payment.vercel.app",
};

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(origin =>
            {
                if (corsExactOrigins.Contains(origin))
                    return true;
                if (builder.Environment.IsDevelopment()
                    && Uri.TryCreate(origin, UriKind.Absolute, out var u)
                    && string.Equals(u.Scheme, "http", StringComparison.OrdinalIgnoreCase)
                    && u.Port == 3000
                    && IPAddress.TryParse(u.Host, out _))
                    return true;
                return false;
            })
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    var jwtSecurityScheme = new OpenApiSecurityScheme
    {
        BearerFormat = "JWT",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = JwtBearerDefaults.AuthenticationScheme,
        Description = "Enter your JWT Access Token",
        Reference = new OpenApiReference
        {
            Id = JwtBearerDefaults.AuthenticationScheme,
            Type = ReferenceType.SecurityScheme
        }
    };

    options.AddSecurityDefinition(jwtSecurityScheme.Reference.Id, jwtSecurityScheme);
    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { jwtSecurityScheme, Array.Empty<string>() }
    });
});

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
}).AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = builder.Configuration["JwtConfig:Issuer"],
        ValidAudience = builder.Configuration["JwtConfig:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["JwtConfig:Key"]!)),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true
    };
    // SignalR: read JWT from query string (access_token) for WebSocket connections
    options.Events = new Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        },
        OnAuthenticationFailed = context =>
        {
            var logger = context.HttpContext.RequestServices.GetRequiredService<ILoggerFactory>()
                .CreateLogger("JwtBearer");
            logger.LogWarning(
                context.Exception,
                "JWT authentication failed for {Method} {Path}",
                context.Request.Method,
                context.Request.Path);
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<IEventService, EventService>();
builder.Services.AddScoped<IImageUploadService, ImageUploadService>();
builder.Services.AddScoped<IReferenceService, ReferenceService>();
builder.Services.AddScoped<IGuestService, GuestService>();
builder.Services.AddScoped<IEventImageService, EventImageService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IPrayerWallService, PrayerWallService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddSingleton<IPrayerWallHubNotifier, PrayerWallHubNotifier>();
builder.Services.AddSingleton<IUpdatesHubNotifier, UpdatesHubNotifier>();
builder.Services.AddSingleton<IHubFilter, SignalRHubExceptionLoggingFilter>();
builder.Services.AddSignalR(hubOptions =>
{
    if (builder.Environment.IsDevelopment())
        hubOptions.EnableDetailedErrors = true;
});

var app = builder.Build();

app.UseSerilogRequestLogging();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHub<PrayerWallHub>(PrayerWallHub.HubPath);
app.MapHub<UpdatesHub>(UpdatesHub.HubPath);

app.Run();
