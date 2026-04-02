using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace TruyenCV.Dtos.Stories;

public class ImportStoryDTO
{
    [BindingBehavior(BindingBehavior.Optional)]
    public int? StoryId { get; set; } // ID của truyện (nếu update mode) - null = tạo story mới

    [BindingBehavior(BindingBehavior.Optional)]
    public string? StoryUrl { get; set; } // URL chapter đầu tiên của truyện

    [BindingBehavior(BindingBehavior.Optional)]
    public int AuthorId { get; set; } // ID của tác giả trong hệ thống

    [BindingBehavior(BindingBehavior.Optional)]
    public int? PrimaryGenreId { get; set; }

    [BindingBehavior(BindingBehavior.Optional)]
    public List<int>? GenreIds { get; set; }

    [BindingBehavior(BindingBehavior.Optional)]
    public int NumberOfChapters { get; set; } = 1; // Số chapter cần tải

    [BindingBehavior(BindingBehavior.Optional)]
    public int DelaySeconds { get; set; } = 2; // Delay giữa các request (tính bằng giây)
}

public class ImportStoryProgressDTO
{
    public string ImportId { get; set; } = null!;
    public string Status { get; set; } = null!; // pending | processing | completed | failed
    public int ChaptersImported { get; set; }
    public int TotalChapters { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime? CompletedAt { get; set; }
}
