namespace TruyenCV.Dtos.Chapters;

public class ImportChapterDTO
{
    public int StoryId { get; set; }
    public int ChapterNumber { get; set; }
    public string? Title { get; set; }
    public string Content { get; set; } = null!;
    public string? SourceUrl { get; set; }
}
