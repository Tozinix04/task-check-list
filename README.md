# Task Checklist & Progress Dashboard

ASP.NET Core MVC (.NET 10) + Entity Framework Core 10 + SQL Server.

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) (`dotnet --list-sdks` should list `10.0.x`)
- Docker (for the local SQL Server 2022 container)

## Running locally

1. **Configure the database password.** Copy the example environment file and set a strong
   value for `SA_PASSWORD` (SQL Server requires at least 8 characters with upper case,
   lower case, digits and symbols):

   ```bash
   cp .env.example .env
   ```

2. **Start SQL Server.** The `sqlserver-init` service creates the `TaskChecklistDb` database
   with the initial schema and seed data:

   ```bash
   docker compose up -d
   ```

3. **Set the connection string.** `appsettings.json` only contains a placeholder; the real
   password is never committed. Use one of the following (same password as in `.env`):

   ```bash
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" \
     "Server=127.0.0.1,1433;Database=TaskChecklistDb;User Id=sa;Password=REPLACE_WITH_YOUR_PASSWORD;TrustServerCertificate=True;" \
     --project TaskChecklist
   ```

   or create `TaskChecklist/appsettings.Development.json` (git-ignored) with a
   `ConnectionStrings:DefaultConnection` entry, or export the environment variable
   `ConnectionStrings__DefaultConnection`.

4. **Run the application.** Pending EF Core migrations are applied automatically at startup
   (`Database.Migrate()` in `Program.cs`):

   ```bash
   dotnet run --project TaskChecklist --launch-profile http
   ```

   Open <http://localhost:5005>.

## EF Core migrations

The `dotnet-ef` CLI is pinned in the local tool manifest (`dotnet-tools.json`):

```bash
dotnet tool restore
dotnet ef migrations list --project TaskChecklist
dotnet ef migrations add <Name> --project TaskChecklist
dotnet ef database update --project TaskChecklist
```

All schema changes are made through migrations in `TaskChecklist/Migrations`.

## Notes

- `TaskChecklist/Data/postgres-init.sql` and `POSTGRES_PASSWORD` are not used by the
  application, which runs on SQL Server only.
