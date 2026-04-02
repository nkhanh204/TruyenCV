using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using Microsoft.Extensions.Caching.Memory;
using TruyenCV.Dtos.Chapters;
using TruyenCV.Dtos.Stories;
using TruyenCV.Services.IService;

namespace TruyenCV.Controllers;

[ApiController]
[Route("api/[controller]")]
public class StoriesController : ControllerBase
{
    private static readonly HashSet<string> SupportedImportHosts = new(StringComparer.OrdinalIgnoreCase)
    {
        "truyenchu.app",
        "www.truyenchu.app",
        "truyenchu.com",
        "www.truyenchu.com",
        "truyenchu.vn",
        "www.truyenchu.vn"
    };

    private readonly IStoryService _service;
    private readonly IChapterService _chapterService;
    private readonly IDataScraperService _scraperService;
    private readonly IMemoryCache _cache;
    private readonly ILogger<StoriesController> _logger;
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public StoriesController(
        IStoryService service,
        IChapterService chapterService,
        IDataScraperService scraperService,
        IMemoryCache cache,
        ILogger<StoriesController> logger,
        IServiceScopeFactory serviceScopeFactory)
    {
        _service = service;
        _chapterService = chapterService;
        _scraperService = scraperService;
        _cache = cache;
        _logger = logger;
        _serviceScopeFactory = serviceScopeFactory;
    }

    [HttpGet("all")]
    public async Task<IActionResult> GetAll([FromQuery] string? q = null)
    {
        var data = await _service.GetAllAsync(q);
        return Ok(new { status = true, message = "Lấy danh sách truyện thành công.", data });
    }

    [HttpGet("latest")]
    public async Task<IActionResult> GetLatest([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        try
        {
            if (page < 1)
                return BadRequest(new { status = false, message = "Trang phải từ 1 trở lên.", data = (object?)null });

            if (pageSize < 1 || pageSize > 100)
                return BadRequest(new { status = false, message = "Kích thước trang phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetLatestAsync(page, pageSize);
            return Ok(new { status = true, message = "Lấy danh sách truyện mới nhất thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("completed")]
    public async Task<IActionResult> GetCompleted([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        try
        {
            if (page < 1)
                return BadRequest(new { status = false, message = "Trang phải từ 1 trở lên.", data = (object?)null });

            if (pageSize < 1 || pageSize > 100)
                return BadRequest(new { status = false, message = "Kích thước trang phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetCompletedAsync(page, pageSize);
            return Ok(new { status = true, message = "Lấy danh sách truyện đã hoàn thành thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("ongoing")]
    public async Task<IActionResult> GetOngoing([FromQuery] int page = 1, [FromQuery] int pageSize = 10)
    {
        try
        {
            if (page < 1)
                return BadRequest(new { status = false, message = "Trang phải từ 1 trở lên.", data = (object?)null });

            if (pageSize < 1 || pageSize > 100)
                return BadRequest(new { status = false, message = "Kích thước trang phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetOngoingAsync(page, pageSize);
            return Ok(new { status = true, message = "Lấy danh sách truyện đang tiến hành thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("by-author/{authorId:int}")]
    public async Task<IActionResult> GetByAuthor(int authorId)
    {
        try
        {
            var data = await _service.GetByAuthorAsync(authorId);
            return Ok(new { status = true, message = "Lấy danh sách truyện theo tác giả thành công.", data });
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { status = false, message = "Không tìm thấy tác giả.", data = (object?)null });
        }
    }

    [HttpGet("by-genre/{genreId:int}")]
    public async Task<IActionResult> GetByGenre(int genreId, [FromQuery] List<int>? genreIds = null)
    {
        try
        {
            // Nếu có genreIds query parameter, lọc theo nhiều thể loại
            if (genreIds is not null && genreIds.Count > 0)
            {
                var data = await _service.GetByGenresAsync(genreIds);
                return Ok(new { status = true, message = "Lấy danh sách truyện theo các thể loại thành công.", data });
            }

            // Ngược lại, lọc theo genreId từ route
            var singleData = await _service.GetByGenreAsync(genreId);
            return Ok(new { status = true, message = "Lấy danh sách truyện theo thể loại thành công.", data = singleData });
        }
        catch (KeyNotFoundException)
        {
            return NotFound(new { status = false, message = "Không tìm thấy thể loại.", data = (object?)null });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var dto = await _service.GetByIdAsync(id);
        return dto is null
            ? NotFound(new { status = false, message = "Không tìm thấy truyện.", data = (object?)null })
            : Ok(new { status = true, message = "Lấy thông tin truyện thành công.", data = dto });
    }

    // ===== Top Stories =====

    [HttpGet("top-weekly")]
    public async Task<IActionResult> GetTopWeekly([FromQuery] int limit = 10)
    {
        try
        {
            if (limit < 1 || limit > 100)
                return BadRequest(new { status = false, message = "Limit phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetTopWeeklyAsync(limit);
            return Ok(new { status = true, message = "Lấy top truyện tuần thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("top-monthly")]
    public async Task<IActionResult> GetTopMonthly([FromQuery] int limit = 10)
    {
        try
        {
            if (limit < 1 || limit > 100)
                return BadRequest(new { status = false, message = "Limit phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetTopMonthlyAsync(limit);
            return Ok(new { status = true, message = "Lấy top truyện tháng thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("top-all-time")]
    public async Task<IActionResult> GetTopAllTime([FromQuery] int limit = 10)
    {
        try
        {
            if (limit < 1 || limit > 100)
                return BadRequest(new { status = false, message = "Limit phải từ 1 đến 100.", data = (object?)null });

            var data = await _service.GetTopAllTimeAsync(limit);
            return Ok(new { status = true, message = "Lấy top truyện mọi thời đại thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [HttpGet("top-rated")]
    public async Task<IActionResult> GetTopRated([FromQuery] int page = 1, [FromQuery] int pageSize = 10, [FromQuery] string? period = null)
    {
        try
        {
            if (page < 1)
                return BadRequest(new { status = false, message = "Trang phải từ 1 trở lên.", data = (object?)null });

            if (pageSize < 1 || pageSize > 100)
                return BadRequest(new { status = false, message = "Kích thước trang phải từ 1 đến 100.", data = (object?)null });

            // Validate period parameter
            if (period != null && period != "all" && period != "month" && period != "week")
                return BadRequest(new { status = false, message = "Period không hợp lệ. Chỉ chấp nhận: 'all', 'month', 'week' hoặc null.", data = (object?)null });

            var data = await _service.GetTopRatedAsync(page, pageSize, period);
            return Ok(new { status = true, message = "Lấy danh sách truyện xếp hạng thành công.", data });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    // ===== User Story Creation =====

    [Authorize]
    [HttpPost("create-as-user")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> CreateAsUser([FromForm] StoryCreateDTO dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(new { status = false, message = "Dữ liệu không hợp lệ.", data = (object?)null, errors = ToErrorDict(ModelState) });

        try
        {
            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
            if (string.IsNullOrEmpty(userId))
                return Unauthorized(new { status = false, message = "Không tìm thấy thông tin user.", data = (object?)null });

            var created = await _service.CreateAsUserAsync(userId, dto);
            return StatusCode(201, new { status = true, message = "Tạo truyện thành công.", data = created });
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(403, new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [Authorize(Roles = "Admin,Employee")]
    [HttpPost("create")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Create([FromForm] StoryCreateDTO dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(new { status = false, message = "Dữ liệu không hợp lệ.", data = (object?)null, errors = ToErrorDict(ModelState) });

        try
        {
            var created = await _service.CreateAsync(dto);
            return StatusCode(201, new { status = true, message = "Tạo truyện thành công.", data = created });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [Authorize(Roles = "Admin,Employee")]
    [HttpPut("update-{id:int}")]
    [Consumes("multipart/form-data")]
    public async Task<IActionResult> Update(int id, [FromForm] StoryUpdateDTO dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(new { status = false, message = "Dữ liệu không hợp lệ.", data = (object?)null, errors = ToErrorDict(ModelState) });

        try
        {
            var updated = await _service.UpdateAsync(id, dto);
            return Ok(new { status = true, message = "Cập nhật truyện thành công.", data = updated });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { status = false, message = ex.Message, data = (object?)null });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(500, new { status = false, message = ex.Message, data = (object?)null });
        }
    }

    [Authorize(Roles = "Admin")]
    [HttpDelete("delete-{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var ok = await _service.DeleteAsync(id);
        return ok
            ? Ok(new { status = true, message = "Xóa truyện thành công.", data = new { storyId = id } })
            : NotFound(new { status = false, message = "Không tìm thấy truyện để xóa.", data = (object?)null });
    }

    // ===== Import Chapter from External URLs =====

    /// <summary>
    /// Bắt đầu quá trình tải chapters từ URL
    /// </summary>
    // [Authorize(Roles = "Admin,Employee")]
    [HttpPost("import")]
    public async Task<IActionResult> ImportChapters([FromBody] ImportStoryDTO dto)
    {
        try
        {
            // Validate input
            if (string.IsNullOrWhiteSpace(dto.StoryUrl))
                return BadRequest(new { status = false, message = "URL chapter không được để trống.", data = (object?)null });

            if (!Uri.TryCreate(dto.StoryUrl, UriKind.Absolute, out var storyUri))
                return BadRequest(new { status = false, message = "URL không hợp lệ.", data = (object?)null });

            if (!IsSupportedImportHost(storyUri.Host))
                return BadRequest(new
                {
                    status = false,
                    message = "Chỉ hỗ trợ URL từ TruyenChu (truyenchu.app / truyenchu.com / truyenchu.vn).",
                    data = (object?)null
                });

            if (dto.AuthorId <= 0)
                return BadRequest(new { status = false, message = "AuthorId không hợp lệ.", data = (object?)null });

            if (dto.NumberOfChapters < 1 || dto.NumberOfChapters > 500)
                return BadRequest(new { status = false, message = "Số chapter phải từ 1 đến 500.", data = (object?)null });

            if (dto.DelaySeconds < 1 || dto.DelaySeconds > 60)
                return BadRequest(new { status = false, message = "Delay phải từ 1 đến 60 giây.", data = (object?)null });

            // Generate import ID
            var importId = Guid.NewGuid().ToString();

            // Create progress object
            var progress = new ImportStoryProgressDTO
            {
                ImportId = importId,
                Status = "processing",
                ChaptersImported = 0,
                TotalChapters = dto.NumberOfChapters,
                StartedAt = DateTime.UtcNow
            };

            // Cache the progress (keep for 1 hour)
            _cache.Set(importId, progress, TimeSpan.FromHours(1));

            // Start background task (fire and forget)
            _ = ImportChaptersBackground(importId, dto, progress);

            return Accepted(new
            {
                status = true,
                message = "Quá trình tải chapter bắt đầu.",
                data = new { importId, storyUrl = dto.StoryUrl, numberOfChapters = dto.NumberOfChapters }
            });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Lỗi khi bắt đầu import: {ex.Message}");
            return StatusCode(500, new { status = false, message = "Lỗi: " + ex.Message, data = (object?)null });
        }
    }

    /// <summary>
    /// Kiểm tra trạng thái quá trình import
    /// </summary>
    [HttpGet("import/status/{importId}")]
    public IActionResult GetImportStatus(string importId)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(importId))
                return BadRequest(new { status = false, message = "ImportId không được để trống.", data = (object?)null });

            if (_cache.TryGetValue(importId, out ImportStoryProgressDTO progress))
            {
                return Ok(new { status = true, message = "Lấy trạng thái import thành công.", data = progress });
            }

            return NotFound(new { status = false, message = "Không tìm thấy import session.", data = (object?)null });
        }
        catch (Exception ex)
        {
            _logger.LogError($"Lỗi khi lấy trạng thái import: {ex.Message}");
            return StatusCode(500, new { status = false, message = "Lỗi: " + ex.Message, data = (object?)null });
        }
    }

    // Private method for background import task
    private async Task ImportChaptersBackground(string importId, ImportStoryDTO dto, ImportStoryProgressDTO progress)
    {
        try
        {
            _logger.LogInformation($"Bắt đầu tải {dto.NumberOfChapters} chapters cho story ID {dto.AuthorId}");

            // Fetch chapters from the scraper (doesn't need DbContext)
            var chapters = await _scraperService.FetchMultipleChaptersAsync(
                dto.StoryUrl ?? "",
                dto.NumberOfChapters,
                dto.DelaySeconds,
                onProgress: (current, total) =>
                {
                    progress.ChaptersImported = current;
                    _cache.Set(importId, progress, TimeSpan.FromHours(1));
                    _logger.LogInformation($"Progress: {current}/{total} chapters imported");
                }
            );

            if (chapters.Count == 0)
            {
                progress.Status = "failed";
                progress.ErrorMessage = "Không tải được chapter nào";
                progress.CompletedAt = DateTime.UtcNow;
                _cache.Set(importId, progress, TimeSpan.FromHours(1));
                return;
            }

            // Create new service scope for database operations
            using (var scope = _serviceScopeFactory.CreateScope())
            {
                var storyService = scope.ServiceProvider.GetRequiredService<IStoryService>();
                var chapterService = scope.ServiceProvider.GetRequiredService<IChapterService>();

                int storyId;

                // Determine if this is UPDATE mode or IMPORT mode
                if (dto.StoryId.HasValue && dto.StoryId.Value > 0)
                {
                    // UPDATE MODE: Add chapters to existing story
                    storyId = dto.StoryId.Value;
                    _logger.LogInformation($"UPDATE MODE: Thêm {chapters.Count} chapters vào story {storyId}");

                    // Get the max chapter number for this story
                    var existingChapters = await chapterService.GetChaptersByStoryAsync(storyId);
                    var maxChapterNumber = existingChapters?.Count > 0
                        ? existingChapters.Max(x => x.ChapterNumber)
                        : 0;

                    _logger.LogInformation($"Story hiện có {existingChapters?.Count ?? 0} chapters, max chapter number = {maxChapterNumber}");
                }
                else
                {
                    // IMPORT MODE: Create new story
                    var storyTitle = chapters.FirstOrDefault()?.NovelTitle ?? "Không xác định";
                    var storyDto = new StoryCreateDTO
                    {
                        Title = storyTitle,
                        AuthorId = dto.AuthorId,
                        Description = "Import từ TruyenChu",
                        PrimaryGenreId = dto.PrimaryGenreId,
                        GenreIds = dto.GenreIds,
                        Status = "Đang tiến hành"
                    };

                    var createdStory = await storyService.CreateAsync(storyDto);
                    storyId = createdStory.StoryId;
                    _logger.LogInformation($"IMPORT MODE: Tạo story mới {storyId}: {storyTitle}");
                }

                // Get current max chapter number to continue from
                var currentChapters = await chapterService.GetChaptersByStoryAsync(storyId);
                int nextChapterNumber = (currentChapters?.Count > 0
                    ? currentChapters.Max(x => x.ChapterNumber)
                    : 0) + 1;

                _logger.LogInformation($"Tính toán chapter number: có {currentChapters?.Count ?? 0} chapters, next = {nextChapterNumber}");

                // Save chapters to database
                int chapterCount = 0;
                foreach (var chapter in chapters)
                {
                    try
                    {
                        var chapterDto = new ChapterCreateDTO
                        {
                            StoryId = storyId,
                            ChapterNumber = nextChapterNumber + chapterCount,
                            Title = chapter.ChapterTitle,
                            Content = chapter.Content
                        };

                        await chapterService.CreateAsync(chapterDto);
                        chapterCount++;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning($"Lỗi lưu chapter {nextChapterNumber + chapterCount}: {ex.Message}");
                        // Continue with next chapter
                    }
                }

                progress.Status = "completed";
                progress.ChaptersImported = chapterCount;
                progress.CompletedAt = DateTime.UtcNow;
                _cache.Set(importId, progress, TimeSpan.FromHours(1));

                _logger.LogInformation($"Hoàn thành import {chapterCount} chapters cho story {storyId}");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError($"Lỗi trong quá trình import: {ex.Message}");
            progress.Status = "failed";
            progress.ErrorMessage = ex.Message;
            progress.CompletedAt = DateTime.UtcNow;
            _cache.Set(importId, progress, TimeSpan.FromHours(1));
        }
    }

    private static bool IsSupportedImportHost(string host)
        => SupportedImportHosts.Contains(host);

    private static Dictionary<string, string[]> ToErrorDict(ModelStateDictionary modelState)
        => modelState
            .Where(x => x.Value?.Errors.Count > 0)
            .ToDictionary(
                k => k.Key,
                v => v.Value!.Errors.Select(e => string.IsNullOrWhiteSpace(e.ErrorMessage) ? "Dữ liệu không hợp lệ." : e.ErrorMessage).ToArray()
            );
}
