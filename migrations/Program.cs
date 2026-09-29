using System;
using System.Collections.Generic;
using System.IO;
using Npgsql;

var connStr = "Host=ep-dry-butterfly-a4ndkt27.us-east-1.aws.neon.tech;Port=5432;Database=verceldb;Username=default;Password=hfsveANi5k1K;SSL Mode=Require;Trust Server Certificate=true";

// Run migration if "migrate" argument passed
if (args.Length > 0 && args[0].Equals("migrate", StringComparison.OrdinalIgnoreCase))
{
    var sqlPath = Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "001_create_all_tables.sql");
    if (args.Length > 1) sqlPath = args[1];
    sqlPath = Path.GetFullPath(sqlPath);
    if (!File.Exists(sqlPath))
    {
        Console.WriteLine($"SQL file not found: {sqlPath}");
        return 1;
    }
    Console.WriteLine($"Running migration: {sqlPath}\n");
    try
    {
        var sql = await File.ReadAllTextAsync(sqlPath);
        await using var conn = new NpgsqlConnection(connStr);
        await conn.OpenAsync();
        await using var cmd = new NpgsqlCommand(sql, conn);
        await cmd.ExecuteNonQueryAsync();
        Console.WriteLine("✓ Migration completed successfully.");
        return 0;
    }
    catch (Exception ex)
    {
        Console.WriteLine($"✗ Migration failed: {ex.Message}");
        if (ex.InnerException != null) Console.WriteLine($"  {ex.InnerException.Message}");
        return 1;
    }
}

Console.WriteLine("Connecting to Neon database...\n");

try
{
    await using var conn = new NpgsqlConnection(connStr);
    await conn.OpenAsync();
    Console.WriteLine("✓ Connected to Neon database\n");

    var tables = new List<string>();
    await using (var cmd = new NpgsqlCommand("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name", conn))
    await using (var r = await cmd.ExecuteReaderAsync())
    {
        while (await r.ReadAsync()) tables.Add(r.GetString(0));
    }
    
    Console.WriteLine($"Tables found: {tables.Count}");
    foreach (var t in tables) Console.WriteLine($"  - {t}");
    
    if (!tables.Contains("event_categories"))
    {
        Console.WriteLine("\n✗ event_categories table NOT FOUND - migration script has NOT been run.");
        Console.WriteLine("  Run: psql \"Host=...\" -f 001_create_all_tables.sql");
        return 1;
    }

    var categories = new List<(int id, string name)>();
    await using (var cmd = new NpgsqlCommand("SELECT pk_event_category_id, event_category_name FROM event_categories", conn))
    await using (var r = await cmd.ExecuteReaderAsync())
    {
        while (await r.ReadAsync()) categories.Add((r.GetInt32(0), r.GetString(1)));
    }
    Console.WriteLine($"\nEvent categories: {categories.Count}");
    foreach (var c in categories) Console.WriteLine($"  {c.id}: {c.name}");

    await using (var cmd = new NpgsqlCommand("SELECT * FROM categories_get()", conn))
    {
        await cmd.ExecuteScalarAsync();
        Console.WriteLine("\n✓ categories_get() function works");
    }
    
    Console.WriteLine("\n✓ Migration script has been run. Database is accessible.");
    return 0;
}
catch (Exception ex)
{
    Console.WriteLine($"\n✗ Error: {ex.Message}");
    if (ex.InnerException != null) Console.WriteLine($"  {ex.InnerException.Message}");
    return 1;
}
