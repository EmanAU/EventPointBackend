using IServices;
using Microsoft.AspNetCore.Mvc;
using Models.Event;
using System;
using System.Collections.Generic;
using System.Linq;

namespace ApiControllers.Controllers
{
    /// <summary>
    /// Scroll feed is registered here (not under <c>api/event/&#123;eventId&#125;</c>) so
    /// older deployments without the GET handler cannot return 405 for GET when the
    /// path was mistaken for a literal event id.
    /// </summary>
    [Route("api/feed")]
    [ApiController]
    public class EventsScrollFeedController : ControllerBase
    {
        private readonly IEventService _eventService;
        private readonly ILogger<EventsScrollFeedController> _logger;

        public EventsScrollFeedController(
            IEventService eventService,
            ILogger<EventsScrollFeedController> logger)
        {
            _eventService = eventService;
            _logger = logger;
        }

        [HttpGet("event-scroll")]
        public async Task<ActionResult<IEnumerable<EventScrollItemResponse>>> GetAsync([FromQuery] string userId)
        {
            _logger.LogInformation("GetEventScroll (feed): UserId={UserId}", userId ?? "(null)");
            try
            {
                if (string.IsNullOrWhiteSpace(userId))
                {
                    _logger.LogWarning("GetEventScroll rejected: UserId is missing or empty.");
                    return BadRequest(new { message = "User ID is required." });
                }

                var result = await _eventService.GetEventsScrollFeedAsync(userId);
                var list = result?.ToList() ?? new List<EventScrollItemResponse>();
                _logger.LogInformation("GetEventScroll success: UserId={UserId}, Count={Count}", userId, list.Count);
                return Ok(list);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "GetEventScroll failed: UserId={UserId}, Message={Message}", userId ?? "(null)", ex.Message);
                return StatusCode(500, new { message = "An error occurred. Error: " + ex.Message });
            }
        }
    }
}
