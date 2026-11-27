namespace TaskChecklist.ViewModels
{
    public class ProjectProgress
    {
        public int TotalTasks { get; init; }

        public int CompletedTasks { get; init; }

        public int PercentCompleted => Percent(CompletedTasks, TotalTasks);

        public int TotalChecklistItems { get; init; }

        public int DoneChecklistItems { get; init; }

        public int ChecklistPercentDone => Percent(DoneChecklistItems, TotalChecklistItems);

        private static int Percent(int part, int total) =>
            total == 0 ? 0 : (int)Math.Round(part * 100.0 / total, MidpointRounding.AwayFromZero);
    }
}
