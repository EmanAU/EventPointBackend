using System;
using ApiControllers.Services;
using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.PrayerWall;


namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class PrayerWallController : ControllerBase
    {
        private readonly IPrayerWallService _prayerWallService;
        private readonly IPrayerWallHubNotifier _hubNotifier;
        private readonly IUpdatesHubNotifier _updatesNotifier;
        private readonly IEventService _eventService;
        private readonly IUserService _userService;

        public PrayerWallController(
            IPrayerWallService prayerWallService,
            IPrayerWallHubNotifier hubNotifier,
            IUpdatesHubNotifier updatesNotifier,
            IEventService eventService,
            IUserService userService)
        {
            _prayerWallService = prayerWallService;
            _hubNotifier = hubNotifier;
            _updatesNotifier = updatesNotifier;
            _eventService = eventService;
            _userService = userService;
        }

        [HttpPost("post-or-update-prayer")]
        public async Task<ActionResult<PostOrUpdatePrayerResponse>> PostOrUpdatePrayerAsync([FromBody] PostOrUpdatePrayerRequest request)
        {

            try
            {
                var result = await _prayerWallService.PostOrUpdatePrayerAsync(request);

                // Handle logical failures returned by the DB (IsSuccess = FALSE)
                if (!result.IsSuccess)
                {
                    // Database returned: "Unauthorized: You must be an admin or approved guest to post."
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    // Database returned: "Time limit exceeded. You can only edit your message within 1 hour of posting."
                    if (result.Message.Contains("Time limit exceeded"))
                    {
                        return BadRequest(new { message = result.Message });
                    }

                    // Fallback for any other logical DB rejections
                    return BadRequest(new { message = result.Message });
                }

                if (result.PendingApproval && !string.IsNullOrEmpty(result.PrayerId))
                {
                    try
                    {
                        var eventSummary = await _eventService.GetEventNotificationSummaryAsync(request.EventId);
                        var author = await _userService.GetUserByIdAsync(request.UserId);
                        var adminIds = await _eventService.GetEventAdminUserIdsAsync(request.EventId);

                        if (eventSummary != null && author != null && adminIds.Count > 0)
                        {
                            foreach (var adminId in adminIds)
                            {
                                if (string.Equals(adminId, request.UserId, StringComparison.Ordinal))
                                    continue;

                                var payload = new
                                {
                                    notificationId = $"{request.EventId}_{result.PrayerId}_{adminId}_{DateTime.UtcNow.Ticks}",
                                    eventId = request.EventId,
                                    eventTitle = eventSummary.EventTitle,
                                    eventImageUrl = eventSummary.EventCoverImageUrl ?? "",
                                    prayerId = result.PrayerId,
                                    authorId = request.UserId,
                                    authorName = author.Name,
                                    authorImageUrl = author.ProfileImageUrl ?? "",
                                    createdAt = DateTime.UtcNow
                                };
                                await _updatesNotifier.NotifyPrayerNeedsApproval(adminId, payload);
                            }
                        }
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Failed to send prayer pending notifications: {ex.Message}");
                    }
                }

                // 200 OK: Returns IsSuccess, Message, and the PrayerId
                _ = _hubNotifier.NotifyPrayerPosted(request.EventId);
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpDelete("delete-prayer")]
        public async Task<ActionResult<DeletePrayerResponse>> DeletePrayerAsync([FromBody] DeletePrayerRequest request)
        {
            try
            {
                var result = await _prayerWallService.DeletePrayerAsync(request);

                // Handle logical failures returned by the DB (IsSuccess = FALSE)
                if (!result.IsSuccess)
                {
                    // Database returned: "Prayer not found."
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }

                    // Database returned: "Unauthorized to delete this message."
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    // Database returned: "Time limit exceeded. You cannot delete this message anymore."
                    if (result.Message.Contains("Time limit exceeded"))
                    {
                        return BadRequest(new { message = result.Message });
                    }

                    // Fallback for any other logical DB rejections
                    return BadRequest(new { message = result.Message });
                }

                // 200 OK: "Message deleted by Admin." OR "Your message was deleted."
                _ = _hubNotifier.NotifyPrayerDeleted(request.EventId, request.PrayerId);
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("prayers")]
        public async Task<ActionResult<IEnumerable<PrayerResponse>>> GetPrayersAsync([FromQuery] GetPrayersRequest request)
        {
            if (string.IsNullOrEmpty(request.EventId) || string.IsNullOrEmpty(request.ViewerUserId))
            {
                return BadRequest(new { message = "EventId and ViewerUserId are required." });
            }

            try
            {
                var result = await _prayerWallService.GetPrayersAsync(request);

                // 200 OK
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                // 403 Forbidden: "This event is private. Only approved guests can view..."
                return StatusCode(403, new { message = ex.Message });
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpPost("approve-prayer")]
        public async Task<ActionResult<ApprovePrayerResponse>> ApprovePrayerAsync([FromBody] ApprovePrayerRequest request)
        {
            try
            {
                var result = await _prayerWallService.ApprovePrayerAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }
                    if (result.Message.Contains("not found"))
                    {
                        return NotFound(new { message = result.Message });
                    }
                    return BadRequest(new { message = result.Message });
                }

                try
                {
                    var authorUserId = await _prayerWallService.GetPrayerAuthorUserIdAsync(request.EventId, request.PrayerId);
                    if (!string.IsNullOrEmpty(authorUserId) &&
                        !string.Equals(authorUserId, request.AdminUserId, StringComparison.Ordinal))
                    {
                        var eventSummary = await _eventService.GetEventNotificationSummaryAsync(request.EventId);
                        var approver = await _userService.GetUserByIdAsync(request.AdminUserId);
                        if (eventSummary != null)
                        {
                            var payload = new
                            {
                                notificationId = $"{request.EventId}_{request.PrayerId}_{authorUserId}_{DateTime.UtcNow.Ticks}",
                                eventId = request.EventId,
                                eventTitle = eventSummary.EventTitle,
                                eventImageUrl = eventSummary.EventCoverImageUrl ?? "",
                                eventCoverImageUrl = eventSummary.EventCoverImageUrl ?? "",
                                prayerId = request.PrayerId,
                                approverId = request.AdminUserId,
                                approverName = approver?.Name ?? "Admin",
                                approverImageUrl = approver?.ProfileImageUrl ?? "",
                                createdAt = DateTime.UtcNow
                            };
                            await _updatesNotifier.NotifyPrayerWallApproved(authorUserId, payload);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to send prayer approved update notification: {ex.Message}");
                }

                _ = _hubNotifier.NotifyPrayerApproved(request.EventId, request.PrayerId);
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("participants")]
        public async Task<ActionResult<IEnumerable<PrayerParticipantResponse>>> GetPrayerParticipantsAsync([FromQuery] string eventId)
        {
            if (string.IsNullOrEmpty(eventId))
            {
                return BadRequest(new { message = "EventId is required." });
            }

            try
            {
                var result = await _prayerWallService.GetPrayerParticipantsAsync(eventId);
                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }
    }
}
