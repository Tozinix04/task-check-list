using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace TaskChecklist.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Projects",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Projects", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "TaskItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectId = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    DueDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    IsCompleted = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TaskItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TaskItems_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.InsertData(
                table: "Projects",
                columns: new[] { "Id", "Description", "Name" },
                values: new object[,]
                {
                    { 1, "Redesign the company website with a modern look and improved user experience.", "Website Redesign" },
                    { 2, "Develop a cross-platform mobile application for customer engagement.", "Mobile App Development" },
                    { 3, "Migrate legacy database to the new cloud infrastructure.", "Database Migration" }
                });

            migrationBuilder.InsertData(
                table: "TaskItems",
                columns: new[] { "Id", "Description", "DueDate", "IsCompleted", "ProjectId", "Title" },
                values: new object[,]
                {
                    { 1, "Design initial wireframes for the homepage and key landing pages.", new DateTime(2026, 1, 9, 0, 0, 0, 0, DateTimeKind.Local), true, 1, "Create wireframes" },
                    { 2, "Ensure the website works well on all device sizes.", new DateTime(2026, 1, 16, 0, 0, 0, 0, DateTimeKind.Local), false, 1, "Implement responsive design" },
                    { 3, "Integrate Google Analytics and set up conversion tracking.", new DateTime(2026, 1, 23, 0, 0, 0, 0, DateTimeKind.Local), false, 1, "Set up analytics" },
                    { 4, "Document all functional and non-functional requirements.", new DateTime(2026, 1, 7, 0, 0, 0, 0, DateTimeKind.Local), true, 2, "Define app requirements" },
                    { 5, "Create detailed UI mockups for all screens.", new DateTime(2026, 1, 12, 0, 0, 0, 0, DateTimeKind.Local), true, 2, "Design UI mockups" },
                    { 6, "Build user authentication and authorization module.", new DateTime(2026, 1, 22, 0, 0, 0, 0, DateTimeKind.Local), false, 2, "Implement authentication" },
                    { 7, "Document the existing database schema and relationships.", new DateTime(2026, 1, 5, 0, 0, 0, 0, DateTimeKind.Local), true, 3, "Analyze current schema" },
                    { 8, "Write scripts to migrate data to the new database.", new DateTime(2026, 1, 17, 0, 0, 0, 0, DateTimeKind.Local), false, 3, "Create migration scripts" }
                });

            migrationBuilder.CreateIndex(
                name: "IX_TaskItems_ProjectId",
                table: "TaskItems",
                column: "ProjectId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "TaskItems");

            migrationBuilder.DropTable(
                name: "Projects");
        }
    }
}
