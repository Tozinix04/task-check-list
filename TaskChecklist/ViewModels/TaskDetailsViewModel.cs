using TaskChecklist.Models;

namespace TaskChecklist.ViewModels
{
    public class TaskDetailsViewModel
    {
        public TaskItem Task { get; set; } = null!;

        public IReadOnlyList<ChecklistItem> ChecklistItems { get; set; } = [];

        public int DoneChecklistItemsCount => ChecklistItems.Count(item => item.IsDone);

        public ChecklistItemInputModel NewChecklistItem { get; set; } = new();
    }
}
