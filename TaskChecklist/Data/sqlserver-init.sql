USE [master];
GO

IF DB_ID(N'TaskChecklistDb') IS NULL
BEGIN TRY
    EXEC(N'CREATE DATABASE [TaskChecklistDb]');
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 1801
        THROW;
END CATCH;
GO

USE [TaskChecklistDb];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- Use the same lock as EF Core when it applies migrations at startup.
DECLARE @lockResult int;
EXEC @lockResult = sys.sp_getapplock
    @Resource = N'__EFMigrationsLock', @LockMode = 'Exclusive', @LockOwner = 'Transaction';
IF @lockResult < 0
    THROW 50001, 'Could not acquire the migration lock.', 1;

IF OBJECT_ID(N'dbo.__EFMigrationsHistory', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;

IF NOT EXISTS (
    SELECT 1 FROM [dbo].[__EFMigrationsHistory]
    WHERE [MigrationId] = N'20260102120859_InitialCreate'
)
BEGIN
    CREATE TABLE [dbo].[Projects] (
        [Id] int NOT NULL IDENTITY(1,1),
        [Name] nvarchar(200) NOT NULL,
        [Description] nvarchar(1000) NOT NULL,
        CONSTRAINT [PK_Projects] PRIMARY KEY ([Id])
    );

    CREATE TABLE [dbo].[TaskItems] (
        [Id] int NOT NULL IDENTITY(1,1),
        [ProjectId] int NOT NULL,
        [Title] nvarchar(200) NOT NULL,
        [Description] nvarchar(1000) NOT NULL,
        [DueDate] datetime2 NULL,
        [IsCompleted] bit NOT NULL,
        CONSTRAINT [PK_TaskItems] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TaskItems_Projects_ProjectId] FOREIGN KEY ([ProjectId])
            REFERENCES [dbo].[Projects] ([Id]) ON DELETE CASCADE
    );

    CREATE INDEX [IX_TaskItems_ProjectId] ON [dbo].[TaskItems] ([ProjectId]);

    SET IDENTITY_INSERT [dbo].[Projects] ON;
    INSERT INTO [dbo].[Projects] ([Id], [Name], [Description]) VALUES
        (1, N'Website Redesign', N'Redesign the company website with a modern look and improved user experience.'),
        (2, N'Mobile App Development', N'Develop a cross-platform mobile application for customer engagement.'),
        (3, N'Database Migration', N'Migrate legacy database to the new cloud infrastructure.');
    SET IDENTITY_INSERT [dbo].[Projects] OFF;

    SET IDENTITY_INSERT [dbo].[TaskItems] ON;
    INSERT INTO [dbo].[TaskItems] ([Id], [ProjectId], [Title], [Description], [DueDate], [IsCompleted]) VALUES
        (1, 1, N'Create wireframes', N'Design initial wireframes for the homepage and key landing pages.', '2026-01-09', 1),
        (2, 1, N'Implement responsive design', N'Ensure the website works well on all device sizes.', '2026-01-16', 0),
        (3, 1, N'Set up analytics', N'Integrate Google Analytics and set up conversion tracking.', '2026-01-23', 0),
        (4, 2, N'Define app requirements', N'Document all functional and non-functional requirements.', '2026-01-07', 1),
        (5, 2, N'Design UI mockups', N'Create detailed UI mockups for all screens.', '2026-01-12', 1),
        (6, 2, N'Implement authentication', N'Build user authentication and authorization module.', '2026-01-22', 0),
        (7, 3, N'Analyze current schema', N'Document the existing database schema and relationships.', '2026-01-05', 1),
        (8, 3, N'Create migration scripts', N'Write scripts to migrate data to the new database.', '2026-01-17', 0);
    SET IDENTITY_INSERT [dbo].[TaskItems] OFF;

    INSERT INTO [dbo].[__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20260102120859_InitialCreate', N'9.0.0');
END;

COMMIT;
GO
