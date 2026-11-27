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

3. **Set the connection string.** `appsettings.json` contains a placeholder. Use the same
   password as in `.env`. If you changed `MSSQL_PORT` in `.env`, replace `1433` below
   with that port. The command prompts for the password and quotes it for SQL Server
   so it can contain semicolons or quotation marks.

   ```bash
   (
     printf 'SQL Server password: '
     IFS= read -rs taskchecklist_sql_password || exit 1
     printf '\n'
     dotnet user-secrets set "ConnectionStrings:DefaultConnection" \
       "Server=127.0.0.1,1433;Database=TaskChecklistDb;User Id=sa;Password=\"${taskchecklist_sql_password//\"/\"\"}\";TrustServerCertificate=True;" \
       --project TaskChecklist
   )
   ```

   You can also set `ConnectionStrings:DefaultConnection` in the git-ignored
   `TaskChecklist/appsettings.Development.json` or export
   `ConnectionStrings__DefaultConnection`. When composing the connection string
   yourself, put double quotes around the password value and double any `"` within it.

4. **Run the application.** Pending EF Core migrations are applied automatically at startup
   (`Database.Migrate()` in `Program.cs`):

   ```bash
   dotnet run --project TaskChecklist --launch-profile http
   ```

   Open <http://localhost:5005>.

## EF Core migrations

The `dotnet-ef` CLI is pinned in the local tool manifest (`dotnet-tools.json`).
Replace `AddTaskPriority` with a name that describes your migration.

```bash
dotnet tool restore
dotnet ef migrations list --project TaskChecklist
dotnet ef migrations add AddTaskPriority --project TaskChecklist
dotnet ef database update --project TaskChecklist
```

All schema changes are made through migrations in `TaskChecklist/Migrations`.

## Notes

- `TaskChecklist/Data/postgres-init.sql` and `POSTGRES_PASSWORD` are not used by the
  application, which runs on SQL Server only.
