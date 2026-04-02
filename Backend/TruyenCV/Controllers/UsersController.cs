using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;
using TruyenCV.Dtos.Auth;
using TruyenCV.Services.IService;

namespace TruyenCV.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IAuthService _authService;

    public UsersController(IAuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDTO dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(new { status = false, message = "D? li?u kh�ng h?p l?.", data = (object?)null, errors = ToErrorDict(ModelState) });

        var (success, message, data) = await _authService.RegisterAsync(dto);

        if (success)
            return StatusCode(201, new { status = true, message, data });

        return BadRequest(new { status = false, message, data = (object?)null });
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDTO dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(new { status = false, message = "D? li?u kh�ng h?p l?.", data = (object?)null, errors = ToErrorDict(ModelState) });

        var (success, message, data) = await _authService.LoginAsync(dto);

        if (success)
            return Ok(new { status = true, message, data });

        return Unauthorized(new { status = false, message, data = (object?)null });
    }

    [Authorize]
    [HttpPost("logout")]
    public async Task<IActionResult> Logout()
    {
        // Note: For stateless APIs, logout is typically handled client-side by removing the token.
        // If using session-based authentication, you would call SignOutAsync here.
        return Ok(new { status = true, message = "Đăng xuất thành công", data = (object?)null });
    }

    private static Dictionary<string, string[]> ToErrorDict(ModelStateDictionary modelState)
        => modelState
            .Where(x => x.Value?.Errors.Count > 0)
            .ToDictionary(
                k => k.Key,
                v => v.Value!.Errors
                    .Select(e => string.IsNullOrWhiteSpace(e.ErrorMessage) ? "Dữ liệu không khớp." : e.ErrorMessage)
                    .ToArray()
            );
}
