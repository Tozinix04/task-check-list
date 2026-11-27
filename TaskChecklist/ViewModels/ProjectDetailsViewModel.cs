using TaskChecklist.Models;

namespace TaskChecklist.ViewModels
{
    public class ProjectDetailsViewModel
    {
        public Project Project { get; set; } = null!;

        public IReadOnlyList<TaskItem> Tasks { get; set; } = [];

        public ProjectProgress Progress { get; set; } = new();
    }
}
