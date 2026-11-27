using TaskChecklist.Models;

namespace TaskChecklist.ViewModels
{
    public class ProjectDetailsViewModel
    {
        public Project Project { get; set; } = null!;

        public IReadOnlyList<TaskItem> Tasks { get; set; } = [];

        public ProjectProgress Progress { get; set; } = new();

        public TaskStatusFilter StatusFilter { get; set; } = TaskStatusFilter.All;

        public string EmptyTasksMessage => StatusFilter switch
        {
            TaskStatusFilter.Completed => "No completed tasks in this project.",
            TaskStatusFilter.Pending => "No pending tasks in this project.",
            _ => "No tasks have been added to this project yet."
        };
    }
}
