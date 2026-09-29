using Npgsql;

var defaultConn =
    "Host=ep-dry-butterfly-a4ndkt27.us-east-1.aws.neon.tech;Port=5432;Database=verceldb;Username=default;Password=hfsveANi5k1K;SSL Mode=Require;Trust Server Certificate=true";

string connectionString;
string[] migrations;

if (args.Length >= 2 && string.Equals(args[0], "--only", StringComparison.OrdinalIgnoreCase))
{
    migrations = new[] { args[1] };
    connectionString = args.Length >= 3 ? args[2] : defaultConn;
    Console.WriteLine($"Running single migration: {migrations[0]}");
}
else
{
    connectionString = args.Length > 0 ? args[0] : defaultConn;
    migrations = new[]
    {
        "create_invitation_cards.sql", "add_promote_admin_color.sql", "add_is_admin_to_approved_guests.sql",
        "add_creator_codes_colors_to_guests.sql", "fix_approve_only_inviter_admin.sql", "add_inviter_chain_to_guests.sql",
        "add_prayer_approval_image_delete_caption.sql", "add_image_privacy_relationship_type.sql", "add_demote_admin.sql",
        "add_profile_image_to_user_functions.sql", "add_upload_limit_to_image_create.sql", "add_creator_relative_relationship_paths.sql",
        "add_city_country_remove_email_from_guests.sql", "fix_relationship_path_creator_relative.sql", "add_public_event_viewer_access.sql",
        "add_venue_to_public_feed.sql", "add_search_to_public_feed.sql", "add_invitation_card_url.sql", "remove_prayer_edit.sql",
        "add_prayer_post_pending_approval_return.sql",
        "add_event_pamphlet_payments.sql",
    };
}
var basePaths = new[]
{
    Path.Combine(Directory.GetCurrentDirectory(), "migrations"),
    Path.Combine(Directory.GetCurrentDirectory(), "..", "migrations"),
    Path.Combine(Directory.GetCurrentDirectory(), "..", "EventPointApi", "migrations"),
    "/Users/mac138/Documents/Code/ep/EventPointApi/migrations",
};
var migrationsDir = basePaths.FirstOrDefault(d => Directory.Exists(d));
if (migrationsDir is null)
{
    Console.WriteLine("Migrations directory not found.");
    return 1;
}

foreach (var migration in migrations)
{
    var sqlPath = Path.Combine(migrationsDir, migration);
    if (!File.Exists(sqlPath))
    {
        Console.WriteLine($"Skipping {migration} (not found).");
        continue;
    }
    var sql = await File.ReadAllTextAsync(sqlPath);
    Console.WriteLine($"Running migration: {migration}");
    try
    {
        await using var conn = new NpgsqlConnection(connectionString);
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand(sql, conn);
        await cmd.ExecuteNonQueryAsync();
        Console.WriteLine($"  {migration} completed.");
    }
    catch (Exception ex)
    {
        Console.WriteLine($"  {migration} failed: {ex.Message}");
        return 1;
    }
}
Console.WriteLine("All migrations completed successfully.");
return 0;
