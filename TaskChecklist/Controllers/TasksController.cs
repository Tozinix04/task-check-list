using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using TaskChecklist.Data;
using TaskChecklist.Models;
using TaskChecklist.ViewModels;

namespace TaskChecklist.Controllers
{
    public class TasksController : Controller
    {
        private readonly ApplicationDbContext _context;

        public TasksController(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IActionResult> Index()
        {
            var tasks = await _context.TaskItems
                .Include(t => t.Project)
                .ToListAsync();
            return View(tasks);
        }

        public async Task<IActionResult> Details(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            var viewModel = await BuildDetailsViewModelAsync(id.Value);
            if (viewModel == null)
            {
                return NotFound();
            }

            return View(viewModel);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> AddChecklistItem(int id,
            [Bind(Prefix = nameof(TaskDetailsViewModel.NewChecklistItem))] ChecklistItemInputModel input)
        {
            if (!await _context.TaskItems.AnyAsync(t => t.Id == id))
            {
                return NotFound();
            }

            if (!ModelState.IsValid)
            {
                var viewModel = await BuildDetailsViewModelAsync(id);
                if (viewModel == null)
                {
                    return NotFound();
                }

                viewModel.NewChecklistItem = input;
                return View(nameof(Details), viewModel);
            }

            _context.ChecklistItems.Add(new ChecklistItem
            {
                TaskItemId = id,
                Title = input.Title.Trim(),
                IsDone = input.IsDone
            });
            await _context.SaveChangesAsync();

            TempData["Success"] = "Checklist item added.";
            return RedirectToAction(nameof(Details), new { id });
        }

        public IActionResult Create(int? projectId)
        {
            ViewData["ProjectId"] = new SelectList(_context.Projects, "Id", "Name", projectId);

            if (projectId.HasValue)
            {
                return View(new TaskItem { ProjectId = projectId.Value });
            }

            return View();
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("ProjectId,Title,Description,DueDate,IsCompleted")] TaskItem taskItem)
        {
            if (ModelState.IsValid && await ValidateSelectedProjectAsync(taskItem.ProjectId))
            {
                _context.Add(taskItem);
                await _context.SaveChangesAsync();
                return RedirectToAction("Details", "Projects", new { id = taskItem.ProjectId });
            }
            ViewData["ProjectId"] = new SelectList(_context.Projects, "Id", "Name", taskItem.ProjectId);
            return View(taskItem);
        }

        public async Task<IActionResult> Edit(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            var taskItem = await _context.TaskItems.FindAsync(id);
            if (taskItem == null)
            {
                return NotFound();
            }
            ViewData["ProjectId"] = new SelectList(_context.Projects, "Id", "Name", taskItem.ProjectId);
            return View(taskItem);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit(int id, [Bind("Id,ProjectId,Title,Description,DueDate,IsCompleted")] TaskItem taskItem)
        {
            if (id != taskItem.Id)
            {
                return NotFound();
            }

            if (ModelState.IsValid && await ValidateSelectedProjectAsync(taskItem.ProjectId))
            {
                try
                {
                    _context.Update(taskItem);
                    await _context.SaveChangesAsync();
                }
                catch (DbUpdateConcurrencyException)
                {
                    if (!TaskItemExists(taskItem.Id))
                    {
                        return NotFound();
                    }
                    throw;
                }
                return RedirectToAction("Details", "Projects", new { id = taskItem.ProjectId });
            }
            ViewData["ProjectId"] = new SelectList(_context.Projects, "Id", "Name", taskItem.ProjectId);
            return View(taskItem);
        }

        public async Task<IActionResult> Delete(int? id)
        {
            if (id == null)
            {
                return NotFound();
            }

            var taskItem = await _context.TaskItems
                .Include(t => t.Project)
                .FirstOrDefaultAsync(t => t.Id == id);
            if (taskItem == null)
            {
                return NotFound();
            }

            return View(taskItem);
        }

        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            var taskItem = await _context.TaskItems.FindAsync(id);
            int? projectId = taskItem?.ProjectId;

            if (taskItem != null)
            {
                _context.TaskItems.Remove(taskItem);
                await _context.SaveChangesAsync();
            }

            if (projectId.HasValue)
            {
                return RedirectToAction("Details", "Projects", new { id = projectId });
            }
            return RedirectToAction(nameof(Index));
        }

        private async Task<TaskDetailsViewModel?> BuildDetailsViewModelAsync(int id)
        {
            var taskItem = await _context.TaskItems
                .AsNoTracking()
                .Include(t => t.Project)
                .Include(t => t.ChecklistItems.OrderBy(c => c.Id))
                .FirstOrDefaultAsync(t => t.Id == id);

            if (taskItem == null)
            {
                return null;
            }

            return new TaskDetailsViewModel
            {
                Task = taskItem,
                ChecklistItems = taskItem.ChecklistItems.ToList()
            };
        }

        private async Task<bool> ValidateSelectedProjectAsync(int projectId)
        {
            if (await _context.Projects.AnyAsync(project => project.Id == projectId))
            {
                return true;
            }

            ModelState.AddModelError(nameof(TaskItem.ProjectId), "Select an existing project.");
            return false;
        }

        private bool TaskItemExists(int id)
        {
            return _context.TaskItems.Any(e => e.Id == id);
        }
    }
}
