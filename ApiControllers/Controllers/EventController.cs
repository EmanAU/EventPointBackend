using ApiControllers.Services;
using IServices;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Models.Event;
using Models.Images;
using Models.PublicFeed;
using Services;

namespace ApiControllers.Controllers
{
    [Route("api/event")]
    [ApiController]
    public class EventController : ControllerBase
    {
        private readonly IEventService _eventService;
        private readonly IImageUploadService _imageUploadService;
        private readonly IUpdatesHubNotifier _updatesNotifier;
        private readonly IUserService _userService;
        private readonly ILogger<EventController> _logger;

        public EventController(
            IEventService eventService, 
            IImageUploadService imageUploadService,
            IUpdatesHubNotifier updatesNotifier,
            IUserService userService,
            ILogger<EventController> logger)
        {
            _eventService = eventService;
            _imageUploadService = imageUploadService;
            _updatesNotifier = updatesNotifier;
            _userService = userService;
            _logger = logger;
        }

        [HttpPost("upload-image")]
        [RequestSizeLimit(5_242_880)]
        [RequestFormLimits(MultipartBodyLengthLimit = 5_242_880)]
        public async Task<ActionResult<UploadImageResponse>> UploadImageAsync(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                _logger.LogWarning("UploadImage rejected: No file uploaded.");
                return BadRequest(new { message = "No file uploaded." });
            }
            try
            {
                var url = await _imageUploadService.UploadImageAsync(file);
                _logger.LogInformation("UploadImage success: Url={Url}", url);
                return Ok(new UploadImageResponse { Url = url });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "UploadImage failed: Message={Message}", ex.Message);
                return StatusCode(500, new { message = "Upload failed: " + ex.Message });
            }
        }

        [HttpPost("create-group")]
        public async Task<ActionResult<CreateEventResponse>> CreateEventAsync([FromBody] CreateEventRequest request)
        {
            _logger.LogInformation("CreateEvent: CreatorId={CreatorId}, EventCategoryId={EventCategoryId}, EventTitle={EventTitle}",
                request?.CreatorId ?? "(null)", request?.EventCategoryId ?? 0, request?.EventTitle ?? "(null)");

            if (string.IsNullOrWhiteSpace(request?.CreatorId))
            {
                _logger.LogWarning("CreateEvent rejected: CreatorId is missing or empty.");
                return BadRequest(new { message = "CreatorId is required. Sign in again and retry." });
            }

            try
            {
                var result = await _eventService.CreateGroupAsync(request);
                _logger.LogInformation("CreateEvent success: EventId={EventId}", result?.EventId);
                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "CreateEvent validation failed");
                return BadRequest(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning(ex, "CreateEvent conflict");
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                var innerMsg = ex.InnerException?.Message ?? "";
                _logger.LogError(ex, "CreateEvent failed. Message={Message}, Inner={Inner}",
                    ex.Message, innerMsg);
                var message = "An internal error occurred while creating the group. " + ex.Message;
                if (!string.IsNullOrEmpty(innerMsg) && innerMsg != ex.Message)
                    message += " Detail: " + innerMsg;
                return StatusCode(500, new { message });
            }
        }


        [HttpPost("join-event")]
        public async Task<ActionResult<JoinEventResponse>> JoinEventAsync([FromBody] JoinEventRequest request)
        {
            _logger.LogInformation("JoinEvent: AdminCode={AdminCode}, UserId={UserId}", request?.AdminCode ?? "(null)", request?.UserId ?? "(null)");
            if (request == null)
            {
                _logger.LogWarning("JoinEvent rejected: Request body is null");
                return BadRequest(new { message = "Request body is required." });
            }

            if (!ModelState.IsValid)
            {
                _logger.LogWarning("JoinEvent rejected: ModelState invalid");
                return BadRequest(ModelState);
            }

            try
            {
                var result = await _eventService.JoinEventAsync(request);

                if (string.Equals(result.Status, "Duplicate", StringComparison.OrdinalIgnoreCase))
                {
                    _logger.LogWarning("JoinEvent conflict: Duplicate join attempt");
                    return Conflict(result);
                }

                // Send notification to event creator when a join request is recorded.
                // full_restore schema: event_join_request_by_code returns Status "Success".
                // Older migrations: same flow returns "Pending". Treat both (case-insensitive).
                var joinRequestRecorded =
                    !string.IsNullOrEmpty(result.EventId) &&
                    (string.Equals(result.Status, "Pending", StringComparison.OrdinalIgnoreCase) ||
                     string.Equals(result.Status, "Success", StringComparison.OrdinalIgnoreCase));

                if (joinRequestRecorded)
                {
                    try
                    {
                        var eventSummary = await _eventService.GetEventNotificationSummaryAsync(result.EventId);
                        var requester = await _userService.GetUserByIdAsync(request.UserId);

                        if (eventSummary == null)
                        {
                            _logger.LogWarning(
                                "Join request notification skipped: no event summary for EventId={EventId}",
                                result.EventId);
                        }
                        else if (requester == null)
                        {
                            _logger.LogWarning(
                                "Join request notification skipped: requester not found UserId={UserId}",
                                request.UserId);
                        }
                        else if (string.IsNullOrEmpty(eventSummary.CreatorId))
                        {
                            _logger.LogWarning(
                                "Join request notification skipped: empty CreatorId for EventId={EventId}",
                                result.EventId);
                        }
                        else
                        {
                            var adminUserId = eventSummary.CreatorId;

                            var payload = new
                            {
                                notificationId = $"{result.EventId}_{request.UserId}_{DateTime.UtcNow.Ticks}",
                                eventId = result.EventId,
                                eventTitle = eventSummary.EventTitle,
                                requesterId = request.UserId,
                                requesterName = requester.Name,
                                requesterImageUrl = requester.ProfileImageUrl ?? "",
                                createdAt = DateTime.UtcNow
                            };

                            await _updatesNotifier.NotifyJoinRequestReceived(adminUserId, payload);
                            _logger.LogInformation(
                                "Sent join request notification to admin {AdminId} (join status={Status})",
                                adminUserId,
                                result.Status);
                        }
                    }
                    catch (Exception notifyEx)
                    {
                        _logger.LogWarning(notifyEx, "Failed to send join request notification");
                        // Don't fail the request
                    }
                }

                _logger.LogInformation("JoinEvent success: EventId={EventId}", result.EventId);
                return Ok(result);
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning(ex, "JoinEvent not found");
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "JoinEvent failed: Message={Message}", ex.Message);
                return StatusCode(500, new { message = "An internal error occurred while processing the join request. " + ex.Message });
            }
        }

        [HttpGet("my-events")]
        public async Task<ActionResult<IEnumerable<EventResponse>>> GetMyEventsAsync([FromQuery] string userId)
        {
            _logger.LogInformation("GetMyEvents: UserId={UserId}", userId ?? "(null)");
            try
            {
                if (string.IsNullOrWhiteSpace(userId))
                {
                    _logger.LogWarning("GetMyEvents rejected: UserId is missing or empty.");
                    return BadRequest(new { message = "User ID is required." });
                }

                var result = await _eventService.GetEventsByUserAsync(userId);
                var count = result?.Count() ?? 0;
                _logger.LogInformation("GetMyEvents success: UserId={UserId}, EventCount={Count}", userId, count);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetMyEvents failed: UserId={UserId}, Message={Message}", userId ?? "(null)", ex.Message);
                return StatusCode(500, new { message = "An error occurred. Error: " + ex.Message });
            }
        }

        [HttpGet("event-details/{eventId}")]
        public async Task<ActionResult<EventDetailResponse>> GetEventDetailAsync([FromRoute] string eventId, [FromQuery] string userId)
        {
            _logger.LogInformation("GetEventDetail: EventId={EventId}, UserId={UserId}", eventId ?? "(null)", userId ?? "(null)");
            if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(eventId))
            {
                _logger.LogWarning("GetEventDetail rejected: EventId or UserId missing.");
                return BadRequest(new { message = "EventId and UserId are required." });
            }

            try
            {
                var result = await _eventService.GetEventDetailAsync(eventId, userId);
                if (result == null)
                {
                    _logger.LogWarning("GetEventDetail not found: EventId={EventId}, UserId={UserId}", eventId, userId);
                    return NotFound(new { message = "Event not found or access denied." });
                }
                _logger.LogInformation("GetEventDetail success: EventId={EventId}, Title={Title}", eventId, result.EventTitle);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetEventDetail failed: EventId={EventId}, Message={Message}", eventId, ex.Message);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        [HttpPut("{eventId}/invitation-card")]
        public async Task<ActionResult> UpdateInvitationCardAsync([FromRoute] string eventId, [FromQuery] string userId, [FromBody] UpdateInvitationCardRequest request)
        {
            _logger.LogInformation("UpdateInvitationCard: EventId={EventId}, UserId={UserId}", eventId ?? "(null)", userId ?? "(null)");
            if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(eventId))
            {
                _logger.LogWarning("UpdateInvitationCard rejected: EventId or UserId missing.");
                return BadRequest(new { message = "EventId and UserId are required." });
            }

            try
            {
                var ok = await _eventService.UpdateInvitationCardAsync(eventId, userId, request);
                if (!ok)
                {
                    _logger.LogWarning("UpdateInvitationCard not found: EventId={EventId}, UserId={UserId}", eventId, userId);
                    return NotFound(new { message = "Event not found or you are not an admin." });
                }
                _logger.LogInformation("UpdateInvitationCard success: EventId={EventId}", eventId);
                return Ok(new { message = "Invitation card updated." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "UpdateInvitationCard failed: EventId={EventId}, Message={Message}", eventId, ex.Message);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        [HttpPut("{eventId}")]
        public async Task<ActionResult> UpdateEventAsync([FromRoute] string eventId, [FromQuery] string userId, [FromBody] UpdateEventRequest request)
        {
            _logger.LogInformation("UpdateEvent: EventId={EventId}, UserId={UserId}", eventId ?? "(null)", userId ?? "(null)");
            if (string.IsNullOrWhiteSpace(userId) || string.IsNullOrWhiteSpace(eventId))
            {
                _logger.LogWarning("UpdateEvent rejected: EventId or UserId missing.");
                return BadRequest(new { message = "EventId and UserId are required." });
            }

            try
            {
                var ok = await _eventService.UpdateEventAsync(eventId, userId, request);
                if (!ok)
                {
                    _logger.LogWarning("UpdateEvent not found: EventId={EventId}, UserId={UserId}", eventId, userId);
                    return NotFound(new { message = "Event not found or you are not the admin." });
                }
                _logger.LogInformation("UpdateEvent success: EventId={EventId}", eventId);
                return Ok(new { message = "Event updated." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "UpdateEvent failed: EventId={EventId}, Message={Message}", eventId, ex.Message);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        [HttpGet("pending-requests")]
        public async Task<ActionResult<IEnumerable<PendingRequestResponse>>> GetPendingRequestsAsync([FromQuery] GetPendingRequestsRequest request)
        {
            _logger.LogInformation("GetPendingRequests: AdminUserId={AdminUserId}, EventId={EventId}", request?.AdminUserId ?? "(null)", request?.EventId ?? "(null)");
            if (request == null)
            {
                _logger.LogWarning("GetPendingRequests rejected: Request is null.");
                return BadRequest(new { message = "Request is required." });
            }

            if (string.IsNullOrEmpty(request.AdminUserId) || string.IsNullOrEmpty(request.EventId))
            {
                _logger.LogWarning("GetPendingRequests rejected: AdminUserId or EventId missing.");
                return BadRequest(new { message = "AdminUserId and EventId are required." });
            }

            try
            {
                var result = await _eventService.GetPendingRequestsAsync(request);

                if (result.Any())
                {
                    _logger.LogInformation("GetPendingRequests success: Count={Count}", result.Count());
                    return Ok(result);
                }

                _logger.LogInformation("GetPendingRequests: No pending requests found");
                return StatusCode(404);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetPendingRequests failed: Message={Message}", ex.Message);
                return StatusCode(500, new { message = "An internal error occurred while fetching pending requests. " + ex.Message });
            }
        }

        [HttpGet("public-feed")]
        public async Task<ActionResult<IEnumerable<PublicFeedEventResponse>>> GetPublicFeedAsync([FromQuery] GetPublicFeedRequest request)
        {
            _logger.LogInformation("GetPublicFeed: PageSize={PageSize}", request?.PageSize ?? 0);
            if (request == null)
            {
                _logger.LogWarning("GetPublicFeed rejected: Request is null.");
                return BadRequest(new { message = "Request is required." });
            }

            if (request.PageSize <= 0 || request.PageSize > 50)
            {
                _logger.LogWarning("GetPublicFeed rejected: Invalid PageSize.");
                return BadRequest(new { message = "PageSize must be between 1 and 50." });
            }

            if (!string.IsNullOrEmpty(request.Search) && request.Search.Length > 200)
            {
                _logger.LogWarning("GetPublicFeed rejected: Search too long.");
                return BadRequest(new { message = "Search must be at most 200 characters." });
            }

            try
            {
                var result = await _eventService.GetPublicFeedAsync(request);
                _logger.LogInformation("GetPublicFeed success: Count={Count}", result?.Count() ?? 0);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetPublicFeed failed: Message={Message}", ex.Message);
                return StatusCode(500, new { message = "An internal error occurred. Error: " + ex.Message });
            }
        }
    }
}
