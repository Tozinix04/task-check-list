using System.ComponentModel.DataAnnotations;

namespace TaskChecklist.ViewModels
{
    public class ChecklistItemInputModel
    {
        [Required(ErrorMessage = "Title is required.")]
        [StringLength(200, ErrorMessage = "Title cannot exceed 200 characters.")]
        [Display(Name = "Title")]
        public string Title { get; set; } = string.Empty;

        [Display(Name = "Done")]
        public bool IsDone { get; set; }
    }
}
