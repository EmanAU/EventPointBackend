using IServices;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Models.Notification;

namespace ApiControllers.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize]
    public class NotificationController : ControllerBase
    {
        private readonly INotificationService _notificationService;
        private readonly ILogger<NotificationController> _logger;

        public NotificationController(
            INotificationService notificationService,
            ILogger<NotificationController> logger)
        {
            _notificationService = notificationService;
            _logger = logger;
        }

        /// <summary>
        /// Get notifications for the current user
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<List<NotificationModel>>> GetNotificationsAsync(
            [FromQuery] string userId,
            [FromQuery] int pageSize = 20,
            [FromQuery] int pageNumber = 1,
            [FromQuery] bool unreadOnly = false)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { message = "UserId is required." });
            }

            try
            {
                var request = new GetNotificationsRequest
                {
                    UserId = userId,
                    PageSize = pageSize,
                    PageNumber = pageNumber,
                    UnreadOnly = unreadOnly
                };

                var notifications = await _notificationService.GetUserNotificationsAsync(request);
                return Ok(notifications);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetNotifications failed: UserId={UserId}", userId);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        /// <summary>
        /// Get unread notification count
        /// </summary>
        [HttpGet("unread-count")]
        public async Task<ActionResult<int>> GetUnreadCountAsync([FromQuery] string userId)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { message = "UserId is required." });
            }

            try
            {
                var count = await _notificationService.GetUnreadNotificationCountAsync(userId);
                return Ok(new { count });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetUnreadCount failed: UserId={UserId}", userId);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        /// <summary>
        /// Mark a notification as read
        /// </summary>
        [HttpPost("mark-read")]
        public async Task<ActionResult> MarkAsReadAsync([FromBody] MarkNotificationReadRequest request)
        {
            if (string.IsNullOrEmpty(request.NotificationId) || string.IsNullOrEmpty(request.UserId))
            {
                return BadRequest(new { message = "NotificationId and UserId are required." });
            }

            try
            {
                var success = await _notificationService.MarkNotificationReadAsync(request);
                if (success)
                {
                    return Ok(new { message = "Notification marked as read." });
                }
                return NotFound(new { message = "Notification not found or already read." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "MarkAsRead failed: NotificationId={NotificationId}", request.NotificationId);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        /// <summary>
        /// Mark all notifications as read for a user
        /// </summary>
        [HttpPost("mark-all-read")]
        public async Task<ActionResult> MarkAllAsReadAsync([FromQuery] string userId)
        {
            if (string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { message = "UserId is required." });
            }

            try
            {
                var count = await _notificationService.MarkAllNotificationsReadAsync(userId);
                return Ok(new { message = $"{count} notification(s) marked as read.", count });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "MarkAllAsRead failed: UserId={UserId}", userId);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }

        /// <summary>
        /// Delete a notification
        /// </summary>
        [HttpDelete("{notificationId}")]
        public async Task<ActionResult> DeleteNotificationAsync(
            [FromRoute] string notificationId,
            [FromQuery] string userId)
        {
            if (string.IsNullOrEmpty(notificationId) || string.IsNullOrEmpty(userId))
            {
                return BadRequest(new { message = "NotificationId and UserId are required." });
            }

            try
            {
                var success = await _notificationService.DeleteNotificationAsync(notificationId, userId);
                if (success)
                {
                    return Ok(new { message = "Notification deleted." });
                }
                return NotFound(new { message = "Notification not found." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "DeleteNotification failed: NotificationId={NotificationId}", notificationId);
                return StatusCode(500, new { message = "An error occurred. " + ex.Message });
            }
        }
    }
}
