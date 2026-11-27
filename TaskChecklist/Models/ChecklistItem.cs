using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace TaskChecklist.Models
{
    public class ChecklistItem
    {
        public int Id { get; set; }

        public int TaskItemId { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; } = string.Empty;

        [Display(Name = "Done")]
        public bool IsDone { get; set; }

        [ValidateNever]
        public TaskItem TaskItem { get; set; } = null!;
    }
}
