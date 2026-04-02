namespace TruyenCV.Services.IService;

public class ChapterData
{
    public string NovelTitle { get; set; } = null!;
    public string ChapterTitle { get; set; } = null!;
    public string Content { get; set; } = null!;
    public string Url { get; set; } = null!;
    public string? NextUrl { get; set; }
    public int ParagraphCount { get; set; }
}

public interface IDataScraperService
{
    /// <summary>
    /// Tải dữ liệu từ một URL chapter
    /// </summary>
    Task<ChapterData> FetchChapterAsync(string url);

    /// <summary>
    /// Tải nhiều chapter từ một URL khởi đầu
    /// </summary>
    Task<List<ChapterData>> FetchMultipleChaptersAsync(
        string startUrl,
        int numberOfChapters,
        int delaySeconds = 2,
        Action<int, int>? onProgress = null,
        CancellationToken cancellationToken = default);
}
