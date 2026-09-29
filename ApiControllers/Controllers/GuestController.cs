using ApiControllers.Services;
using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.Guest;


namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class GuestController : ControllerBase
    {
        private readonly IGuestService _guestService;
        private readonly IUpdatesHubNotifier _updatesNotifier;
        private readonly IEventService _eventService;
        private readonly IUserService _userService;

        public GuestController(
            IGuestService guestService, 
            IUpdatesHubNotifier updatesNotifier,
            IEventService eventService,
            IUserService userService)
        {
            _guestService = guestService;
            _updatesNotifier = updatesNotifier;
            _eventService = eventService;
            _userService = userService;
        }

        [HttpPost("approve-guest")]
        public async Task<ActionResult<ApproveGuestResponse>> ApproveGuestAsync([FromBody] ApproveGuestRequest request)
        {

            try
            {
                var result = await _guestService.ApproveGuestAsync(request);

                if (!result.IsSuccess)
                {
                    // Handle specific logic based on the DB message
                    if (result.Message.Contains("Unauthorized"))
                    {
                        // 403 Forbidden: User is not an admin
                        return StatusCode(403, new { message = result.Message });
                    }

                    if (result.Message.Contains("not found"))
                    {
                        // 404 Not Found: The guest request doesn't exist
                        return NotFound(new { message = result.Message });
                    }

                    // Default fallback for other failures
                    return BadRequest(new { message = result.Message });
                }

                // Notify the approved user via SignalR
                try
                {
                    var eventSummary = await _eventService.GetEventNotificationSummaryAsync(request.EventId);
                    var approver = await _userService.GetUserByIdAsync(request.AdminUserId);
                    if (eventSummary != null)
                    {
                        var payload = new
                        {
                            notificationId = $"{request.EventId}_{request.TargetGuestId}_{DateTime.UtcNow.Ticks}",
                            eventId = request.EventId,
                            eventTitle = eventSummary.EventTitle,
                            eventImageUrl = eventSummary.EventCoverImageUrl ?? "",
                            approverId = request.AdminUserId,
                            approverName = approver?.Name ?? "Admin",
                            createdAt = DateTime.UtcNow
                        };
                        await _updatesNotifier.NotifyRequestApproved(request.TargetGuestId, payload);
                    }
                }
                catch (Exception ex)
                {
                    // Log but don't fail the request
                    Console.WriteLine($"Failed to send approval notification: {ex.Message}");
                }

                // 200 OK
                return Ok(result);
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred while approving the guest. " + ex.Message });
            }
        }

        [HttpPost("promote-admin")]
        public async Task<ActionResult<PromoteAdminResponse>> PromoteAdminAsync([FromBody] PromoteAdminRequest request)
        {
            try
            {
                var result = await _guestService.PromoteAdminAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    if (result.Message.Contains("accepted guest"))
                    {
                        return BadRequest(new { message = result.Message });
                    }

                    if (result.Message.Contains("already an admin"))
                    {
                        return Conflict(new { message = result.Message });
                    }

                    return BadRequest(new { message = result.Message });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("approved-guests")]
        public async Task<ActionResult<IEnumerable<ApprovedGuestResponse>>> GetApprovedGuestsAsync([FromQuery] GetApprovedGuestsRequest request)
        {
            if (string.IsNullOrEmpty(request.EventId) || string.IsNullOrEmpty(request.RequestingUserId))
            {
                return BadRequest(new { message = "EventId and RequestingUserId are required." });
            }

            try
            {
                var result = await _guestService.GetApprovedGuestsAsync(request);

                // 200 OK
                return Ok(result);
            }
            catch (UnauthorizedAccessException ex)
            {
                // 403 Forbidden: Handled from the SQL RAISE EXCEPTION
                return StatusCode(403, new { message = ex.Message });
            }
            catch (Exception ex)
            {
                // 500 Internal Server Error
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpDelete("remove-guest")]
        public async Task<ActionResult<RemoveGuestResponse>> RemoveGuestAsync([FromBody] RemoveGuestRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }

            try
            {
                var result = await _guestService.RemoveGuestAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    if (result.Message.Contains("creator of the group cannot be removed"))
                    {
                        return BadRequest(new { message = result.Message });
                    }

                    return BadRequest(new { message = result.Message });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }

        [HttpPost("demote-admin")]
        public async Task<ActionResult<DemoteAdminResponse>> DemoteAdminAsync([FromBody] DemoteAdminRequest request)
        {
            try
            {
                var result = await _guestService.DemoteAdminAsync(request);

                if (!result.IsSuccess)
                {
                    if (result.Message.Contains("Unauthorized"))
                    {
                        return StatusCode(403, new { message = result.Message });
                    }

                    return BadRequest(new { message = result.Message });
                }

                return Ok(result);
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }
    }
}
