using Microsoft.EntityFrameworkCore;
using TaskChecklist.Models;

namespace TaskChecklist.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<Project> Projects { get; set; }
        public DbSet<TaskItem> TaskItems { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<Project>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(1000);
            });

            modelBuilder.Entity<TaskItem>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Description).HasMaxLength(1000);

                entity.HasOne(e => e.Project)
                    .WithMany(p => p.Tasks)
                    .HasForeignKey(e => e.ProjectId)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            SeedData(modelBuilder);
        }

        private void SeedData(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Project>().HasData(
                new Project
                {
                    Id = 1,
                    Name = "Website Redesign",
                    Description = "Redesign the company website with a modern look and improved user experience."
                },
                new Project
                {
                    Id = 2,
                    Name = "Mobile App Development",
                    Description = "Develop a cross-platform mobile application for customer engagement."
                },
                new Project
                {
                    Id = 3,
                    Name = "Database Migration",
                    Description = "Migrate legacy database to the new cloud infrastructure."
                }
            );

            // Keep sample task dates stable across runs to match the initial migration.
            var seedDate = new DateTime(2026, 1, 2, 0, 0, 0, DateTimeKind.Local);

            modelBuilder.Entity<TaskItem>().HasData(
                new TaskItem
                {
                    Id = 1,
                    ProjectId = 1,
                    Title = "Create wireframes",
                    Description = "Design initial wireframes for the homepage and key landing pages.",
                    DueDate = seedDate.AddDays(7),
                    IsCompleted = true
                },
                new TaskItem
                {
                    Id = 2,
                    ProjectId = 1,
                    Title = "Implement responsive design",
                    Description = "Ensure the website works well on all device sizes.",
                    DueDate = seedDate.AddDays(14),
                    IsCompleted = false
                },
                new TaskItem
                {
                    Id = 3,
                    ProjectId = 1,
                    Title = "Set up analytics",
                    Description = "Integrate Google Analytics and set up conversion tracking.",
                    DueDate = seedDate.AddDays(21),
                    IsCompleted = false
                },
                new TaskItem
                {
                    Id = 4,
                    ProjectId = 2,
                    Title = "Define app requirements",
                    Description = "Document all functional and non-functional requirements.",
                    DueDate = seedDate.AddDays(5),
                    IsCompleted = true
                },
                new TaskItem
                {
                    Id = 5,
                    ProjectId = 2,
                    Title = "Design UI mockups",
                    Description = "Create detailed UI mockups for all screens.",
                    DueDate = seedDate.AddDays(10),
                    IsCompleted = true
                },
                new TaskItem
                {
                    Id = 6,
                    ProjectId = 2,
                    Title = "Implement authentication",
                    Description = "Build user authentication and authorization module.",
                    DueDate = seedDate.AddDays(20),
                    IsCompleted = false
                },
                new TaskItem
                {
                    Id = 7,
                    ProjectId = 3,
                    Title = "Analyze current schema",
                    Description = "Document the existing database schema and relationships.",
                    DueDate = seedDate.AddDays(3),
                    IsCompleted = true
                },
                new TaskItem
                {
                    Id = 8,
                    ProjectId = 3,
                    Title = "Create migration scripts",
                    Description = "Write scripts to migrate data to the new database.",
                    DueDate = seedDate.AddDays(15),
                    IsCompleted = false
                }
            );
        }
    }
}
