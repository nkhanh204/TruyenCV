using System.Net.Http;
using System.Net.Sockets;
using System.Text.RegularExpressions;
using HtmlAgilityPack;
using TruyenCV.Services.IService;

namespace TruyenCV.Services.Implementation;

public class DataScraperService : IDataScraperService
{
    private static readonly string[] SupportedHosts =
    {
        "truyenchu.app",
        "www.truyenchu.app",
        "truyenchu.com",
        "www.truyenchu.com",
        "truyenchu.vn",
        "www.truyenchu.vn"
    };

    private readonly HttpClient _httpClient;
    private readonly ILogger<DataScraperService> _logger;

    public DataScraperService(HttpClient httpClient, ILogger<DataScraperService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;

        _httpClient.DefaultRequestHeaders.Add(
            "User-Agent",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        );
        _httpClient.Timeout = TimeSpan.FromSeconds(30);
    }

    public async Task<ChapterData> FetchChapterAsync(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var inputUri))
        {
            throw new Exception($"URL chapter khong hop le: {url}");
        }

        var candidateUrls = BuildCandidateUrls(inputUri).ToList();
        Exception? lastException = null;

        for (int i = 0; i < candidateUrls.Count; i++)
        {
            var candidateUrl = candidateUrls[i];
            try
            {
                _logger.LogInformation("Tai chapter tu: {Url}", candidateUrl);
                return await FetchSingleChapterAsync(candidateUrl);
            }
            catch (Exception ex) when (CanTryFallback(ex) && i < candidateUrls.Count - 1)
            {
                lastException = ex;
                _logger.LogWarning("Khong ket noi duoc URL {Url}. Thu host thay the...", candidateUrl);
            }
            catch (Exception ex)
            {
                _logger.LogError("Loi tai chapter tu {Url}: {Message}", candidateUrl, ex.Message);
                throw;
            }
        }

        _logger.LogError("Loi tai chapter tu {Url}: {Message}", url, lastException?.Message);
        throw new Exception(
            "Khong the ket noi den TruyenChu. Hay thu URL host khac (truyenchu.com hoac truyenchu.vn).",
            lastException
        );
    }

    public async Task<List<ChapterData>> FetchMultipleChaptersAsync(
        string startUrl,
        int numberOfChapters,
        int delaySeconds = 2,
        Action<int, int>? onProgress = null,
        CancellationToken cancellationToken = default)
    {
        var chapters = new List<ChapterData>();
        var currentUrl = startUrl;
        int successCount = 0;

        for (int i = 0; i < numberOfChapters; i++)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning("Qua trinh tai bi dung o chapter {Index}", i + 1);
                break;
            }

            if (string.IsNullOrWhiteSpace(currentUrl))
            {
                _logger.LogInformation("Khong con chapter tiep theo sau chapter {Index}", i);
                break;
            }

            var maxAttemptsPerChapter = 3;
            ChapterData? chapterData = null;

            for (int attempt = 1; attempt <= maxAttemptsPerChapter; attempt++)
            {
                try
                {
                    _logger.LogInformation(
                        "Dang tai chapter {Current}/{Total} (lan thu {Attempt}/{MaxAttempts}) tu: {Url}",
                        i + 1,
                        numberOfChapters,
                        attempt,
                        maxAttemptsPerChapter,
                        currentUrl
                    );

                    chapterData = await FetchChapterAsync(currentUrl);
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(
                        "Loi tai chapter {Index} (lan thu {Attempt}/{MaxAttempts}): {Message}",
                        i + 1,
                        attempt,
                        maxAttemptsPerChapter,
                        ex.Message
                    );

                    if (attempt < maxAttemptsPerChapter)
                    {
                        await Task.Delay(TimeSpan.FromSeconds(1), cancellationToken);
                        continue;
                    }

                    _logger.LogError(
                        "Dung import vi chapter {Index} that bai sau {MaxAttempts} lan. URL: {Url}",
                        i + 1,
                        maxAttemptsPerChapter,
                        currentUrl
                    );
                }
            }

            if (chapterData == null)
            {
                break;
            }

            chapters.Add(chapterData);
            successCount++;

            onProgress?.Invoke(successCount, numberOfChapters);
            _logger.LogInformation("Tai thanh cong chapter {Current}/{Total}: {Title}", i + 1, numberOfChapters, chapterData.ChapterTitle);

            var previousUrl = currentUrl;
            currentUrl = chapterData.NextUrl;

            if (string.IsNullOrWhiteSpace(currentUrl))
            {
                _logger.LogInformation("Chapter {Index} la chapter cuoi cung (khong tim thay next URL)", i + 1);
            }
            else if (currentUrl == previousUrl)
            {
                _logger.LogWarning("Next URL trung voi current URL, dung tai");
                currentUrl = null;
            }

            if (i < numberOfChapters - 1 && !string.IsNullOrWhiteSpace(currentUrl))
            {
                _logger.LogInformation("Cho {Delay} giay truoc khi tai chapter tiep theo...", delaySeconds);
                await Task.Delay(TimeSpan.FromSeconds(delaySeconds), cancellationToken);
            }
        }

        _logger.LogInformation("Hoan thanh: tai duoc {Success}/{Total} chapters", successCount, numberOfChapters);
        return chapters;
    }

    private async Task<ChapterData> FetchSingleChapterAsync(string url)
    {
        var response = await _httpClient.GetAsync(url);
        response.EnsureSuccessStatusCode();

        var htmlContent = await response.Content.ReadAsStringAsync();
        var doc = new HtmlDocument();
        doc.LoadHtml(htmlContent);

        var novelTitle = ExtractNovelTitle(doc);
        var chapterTitle = ExtractChapterTitle(doc);
        var content = ExtractChapterContent(doc);
        var nextUrl = ExtractNextChapterUrl(doc, url);
        if (string.IsNullOrWhiteSpace(nextUrl))
        {
            nextUrl = await TryResolveNextChapterUrlAsync(url);
        }
        var paragraphCount = content.Split(new[] { "\n\n" }, StringSplitOptions.RemoveEmptyEntries).Length;

        if (string.IsNullOrWhiteSpace(content))
        {
            throw new Exception("Khong tim thay noi dung chapter");
        }

        return new ChapterData
        {
            NovelTitle = novelTitle,
            ChapterTitle = chapterTitle,
            Content = content,
            Url = url,
            NextUrl = nextUrl,
            ParagraphCount = paragraphCount
        };
    }

    private async Task<string?> TryResolveNextChapterUrlAsync(string currentUrl)
    {
        var inferred = await TryInferAndProbeNextChapterUrlAsync(currentUrl);
        if (!string.IsNullOrWhiteSpace(inferred))
        {
            _logger.LogInformation("Resolved next chapter URL by probing: {Url}", inferred);
            return inferred;
        }

        var fromStoryPage = await TryResolveNextChapterFromStoryPageAsync(currentUrl);
        if (!string.IsNullOrWhiteSpace(fromStoryPage))
        {
            _logger.LogInformation("Resolved next chapter URL from story page: {Url}", fromStoryPage);
            return fromStoryPage;
        }

        return null;
    }

    private string ExtractNovelTitle(HtmlDocument doc)
    {
        var candidates = new[]
        {
            "//h1[@class='reading-book-title']",
            "//h1[contains(@class, 'reading-book')]",
            "//meta[@property='og:title']",
            "//title"
        };

        foreach (var xpath in candidates)
        {
            var node = doc.DocumentNode.SelectSingleNode(xpath);
            if (node != null)
            {
                var text = node.InnerText?.Trim();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text;
                }

                var content = node.GetAttributeValue("content", "");
                if (!string.IsNullOrWhiteSpace(content))
                {
                    return content;
                }
            }
        }

        return "Khong tim thay ten truyen";
    }

    private string ExtractChapterTitle(HtmlDocument doc)
    {
        var candidates = new[]
        {
            "//h2[@class='reading-chapter-title']",
            "//h2[contains(@class, 'reading-chapter')]",
            "//h2[contains(@class, 'chapter')]",
            "//meta[@property='og:title']"
        };

        foreach (var xpath in candidates)
        {
            var node = doc.DocumentNode.SelectSingleNode(xpath);
            if (node != null)
            {
                var text = node.InnerText?.Trim();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return text;
                }
            }
        }

        return "Khong tim thay ten chuong";
    }

    private string ExtractChapterContent(HtmlDocument doc)
    {
        var candidates = new[]
        {
            "//article[@class='reading-content']",
            "//article[contains(@class, 'reading')]",
            "//div[@class='reading-content']",
            "//div[contains(@class, 'content')]"
        };

        foreach (var xpath in candidates)
        {
            var node = doc.DocumentNode.SelectSingleNode(xpath);
            if (node != null)
            {
                var text = node.InnerText?.Trim();
                if (!string.IsNullOrWhiteSpace(text))
                {
                    return CleanText(text);
                }
            }
        }

        throw new Exception("Khong tim thay noi dung chapter");
    }

    private string? ExtractNextChapterUrl(HtmlDocument doc, string currentUrl)
    {
        var candidates = new[]
        {
            "//link[@rel='next']",
            "//a[@rel='next']",
            "//a[contains(@class, 'reading-chapter-btn--next')]",
            "//a[contains(@class, 'chapter-btn--next')]",
            "//a[@class='btn-next']",
            "//a[contains(@class, 'btn-next')]",
            "//a[contains(@href, '/truyen/') and contains(@class, 'next')]",
            "//a[contains(text(), 'Chuong tiep theo')]",
            "//a[contains(text(), 'Tiep theo')]",
            "//a[contains(text(), 'Next')]",
            "//a[contains(text(), 'Tiep')]",
            "//a[contains(@title, 'next') or contains(@title, 'Next')]",
            "//div[@class='reading-chapter-nav']//a[contains(@href, '/truyen/')]"
        };

        foreach (var xpath in candidates)
        {
            try
            {
                var nodes = doc.DocumentNode.SelectNodes(xpath);
                if (nodes != null && nodes.Count > 0)
                {
                    foreach (var node in nodes)
                    {
                        var href = node.GetAttributeValue("href", "");
                        if (!string.IsNullOrWhiteSpace(href) && href != currentUrl)
                        {
                            var absoluteUrl = ConvertToAbsoluteUrl(href, currentUrl);
                            if (absoluteUrl != currentUrl)
                            {
                                _logger.LogInformation("Found next chapter URL: {Url}", absoluteUrl);
                                return absoluteUrl;
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Error evaluating XPath {XPath}: {Message}", xpath, ex.Message);
            }
        }

        var fallbackNextUrl = ExtractNextChapterUrlFromHtml(doc, currentUrl);
        if (!string.IsNullOrWhiteSpace(fallbackNextUrl))
        {
            _logger.LogInformation("Found next chapter URL from HTML fallback: {Url}", fallbackNextUrl);
            return fallbackNextUrl;
        }

        _logger.LogWarning("Could not find next chapter URL");
        return null;
    }

    private string CleanText(string text)
    {
        text = Regex.Replace(text, "<[^>]*>", "");
        text = Regex.Replace(text, @"\s+", " ");
        return text.Trim();
    }

    private string ConvertToAbsoluteUrl(string url, string baseUrl)
    {
        if (Uri.IsWellFormedUriString(url, UriKind.Absolute))
        {
            return url;
        }

        var baseUri = new Uri(baseUrl);
        var absoluteUri = new Uri(baseUri, url);
        return absoluteUri.ToString();
    }

    private static IEnumerable<string> BuildCandidateUrls(Uri inputUri)
    {
        yield return inputUri.ToString();

        if (!IsSupportedHost(inputUri.Host))
        {
            yield break;
        }

        foreach (var host in SupportedHosts)
        {
            if (host.Equals(inputUri.Host, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var uriBuilder = new UriBuilder(inputUri) { Host = host };
            yield return uriBuilder.Uri.ToString();
        }
    }

    private static bool IsSupportedHost(string host)
        => SupportedHosts.Any(x => x.Equals(host, StringComparison.OrdinalIgnoreCase));

    private static bool CanTryFallback(Exception ex)
    {
        if (ex is HttpRequestException httpEx)
        {
            if (httpEx.InnerException is SocketException)
            {
                return true;
            }

            return httpEx.Message.Contains("No such host is known", StringComparison.OrdinalIgnoreCase)
                || httpEx.Message.Contains("Name or service not known", StringComparison.OrdinalIgnoreCase)
                || httpEx.Message.Contains("Temporary failure in name resolution", StringComparison.OrdinalIgnoreCase);
        }

        return ex is SocketException;
    }

    private async Task<string?> TryInferAndProbeNextChapterUrlAsync(string currentUrl)
    {
        if (!TryExtractStoryAndChapter(currentUrl, out var baseUri, out var storySlug, out var chapterNumber, out var chapterSuffix))
        {
            return null;
        }

        var nextChapterNumber = chapterNumber + 1;
        var candidates = new List<string>
        {
            $"{baseUri.Scheme}://{baseUri.Host}/truyen/{storySlug}/chuong-{nextChapterNumber}"
        };

        foreach (var candidate in candidates.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            var reachable = await TryGetFirstReachableUrlAsync(candidate);
            if (!string.IsNullOrWhiteSpace(reachable))
            {
                return reachable;
            }
        }

        return null;
    }

    private async Task<string?> TryResolveNextChapterFromStoryPageAsync(string currentUrl)
    {
        if (!TryExtractStoryAndChapter(currentUrl, out var baseUri, out var storySlug, out var currentChapterNumber, out _))
        {
            return null;
        }

        var storyUrl = $"{baseUri.Scheme}://{baseUri.Host}/truyen/{storySlug}";
        foreach (var storyCandidate in BuildCandidateUrls(new Uri(storyUrl)))
        {
            try
            {
                var html = await _httpClient.GetStringAsync(storyCandidate);
                var normalized = html.Replace("\\/", "/");
                var matches = Regex.Matches(
                    normalized,
                    $@"\/truyen\/{Regex.Escape(storySlug)}\/chuong-(\d+)[^""'<>\\s]*",
                    RegexOptions.IgnoreCase
                );

                if (matches.Count == 0)
                {
                    continue;
                }

                var nextMap = new SortedDictionary<int, string>();
                foreach (Match m in matches)
                {
                    var relative = m.Value;
                    var absolute = ConvertToAbsoluteUrl(relative, storyCandidate);
                    var number = ExtractChapterNumberFromUrl(absolute);
                    if (!number.HasValue || number.Value <= currentChapterNumber)
                    {
                        continue;
                    }

                    if (!nextMap.ContainsKey(number.Value))
                    {
                        nextMap[number.Value] = absolute;
                    }
                }

                if (nextMap.TryGetValue(currentChapterNumber + 1, out var immediateNext))
                {
                    return immediateNext;
                }

                if (nextMap.Count > 0)
                {
                    return nextMap.First().Value;
                }
            }
            catch (Exception ex) when (CanTryFallback(ex))
            {
                _logger.LogWarning("Could not fetch story page candidate {Url}: {Message}", storyCandidate, ex.Message);
            }
        }

        return null;
    }

    private async Task<string?> TryGetFirstReachableUrlAsync(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var parsed))
        {
            return null;
        }

        foreach (var candidate in BuildCandidateUrls(parsed))
        {
            try
            {
                using var response = await _httpClient.GetAsync(candidate, HttpCompletionOption.ResponseHeadersRead);
                if (response.IsSuccessStatusCode)
                {
                    return response.RequestMessage?.RequestUri?.ToString() ?? candidate;
                }
            }
            catch (Exception ex) when (CanTryFallback(ex))
            {
                _logger.LogWarning("Reachability check failed for {Url}: {Message}", candidate, ex.Message);
            }
        }

        return null;
    }

    private string? ExtractNextChapterUrlFromHtml(HtmlDocument doc, string currentUrl)
    {
        var rawHtml = doc.DocumentNode.OuterHtml;
        if (string.IsNullOrWhiteSpace(rawHtml))
        {
            return null;
        }

        var normalizedHtml = rawHtml.Replace("\\/", "/");
        var matches = Regex.Matches(
            normalizedHtml,
            @"(https?:\/\/[^""'<>\\s]+\/truyen\/[^""'<>\\s]+\/chuong-\d+[^""'<>\\s]*)|(\/truyen\/[^""'<>\\s]+\/chuong-\d+[^""'<>\\s]*)",
            RegexOptions.IgnoreCase
        );

        if (matches.Count == 0)
        {
            return null;
        }

        var currentChapterNumber = ExtractChapterNumberFromUrl(currentUrl);
        string? bestImmediateNext = null;
        string? bestGreaterNext = null;
        int bestGreaterNumber = int.MaxValue;

        foreach (Match match in matches)
        {
            var candidateRaw = match.Value;
            var absoluteUrl = ConvertToAbsoluteUrl(candidateRaw, currentUrl);
            if (absoluteUrl.Equals(currentUrl, StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var candidateChapterNumber = ExtractChapterNumberFromUrl(absoluteUrl);
            if (currentChapterNumber.HasValue && candidateChapterNumber.HasValue)
            {
                if (candidateChapterNumber.Value == currentChapterNumber.Value + 1)
                {
                    bestImmediateNext = absoluteUrl;
                    break;
                }

                if (candidateChapterNumber.Value > currentChapterNumber.Value
                    && candidateChapterNumber.Value < bestGreaterNumber)
                {
                    bestGreaterNumber = candidateChapterNumber.Value;
                    bestGreaterNext = absoluteUrl;
                }
            }
            else if (bestGreaterNext == null)
            {
                bestGreaterNext = absoluteUrl;
            }
        }

        return bestImmediateNext ?? bestGreaterNext;
    }

    private static int? ExtractChapterNumberFromUrl(string url)
    {
        var match = Regex.Match(url, @"chuong-(\d+)", RegexOptions.IgnoreCase);
        if (!match.Success)
        {
            return null;
        }

        return int.TryParse(match.Groups[1].Value, out var chapterNumber)
            ? chapterNumber
            : null;
    }

    private static bool TryExtractStoryAndChapter(
        string currentUrl,
        out Uri baseUri,
        out string storySlug,
        out int chapterNumber,
        out string chapterSuffix)
    {
        baseUri = null!;
        storySlug = string.Empty;
        chapterNumber = 0;
        chapterSuffix = string.Empty;

        if (!Uri.TryCreate(currentUrl, UriKind.Absolute, out var parsed))
        {
            return false;
        }

        var match = Regex.Match(
            parsed.AbsolutePath,
            @"^/truyen/(?<slug>[^/]+)/chuong-(?<num>\d+)(?<suffix>[^/]*)$",
            RegexOptions.IgnoreCase
        );

        if (!match.Success || !int.TryParse(match.Groups["num"].Value, out chapterNumber))
        {
            return false;
        }

        baseUri = parsed;
        storySlug = match.Groups["slug"].Value;
        chapterSuffix = match.Groups["suffix"].Value;
        return true;
    }
}
