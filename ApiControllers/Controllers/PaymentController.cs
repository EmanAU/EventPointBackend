using System.Threading.Tasks;
using IServices;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Models.Payment;

namespace ApiControllers.Controllers
{
    /// <summary>
    /// Endpoints that support the GoPayFast pamphlet unlock flow on the
    /// Next.js pdf-web app. All callers must present the shared secret
    /// configured under <c>PaymentConfig:ApiKey</c> in appsettings as
    /// the <c>X-Payment-Api-Key</c> header (because the pdf-web proxies
    /// these calls via server actions).
    /// </summary>
    [Route("api/payment")]
    [ApiController]
    public class PaymentController : ControllerBase
    {
        private readonly IPaymentService _paymentService;
        private readonly IConfiguration _config;
        private readonly ILogger<PaymentController> _logger;

        public PaymentController(
            IPaymentService paymentService,
            IConfiguration config,
            ILogger<PaymentController> logger)
        {
            _paymentService = paymentService;
            _config = config;
            _logger = logger;
        }

        private bool IsAuthorizedInternalCaller()
        {
            var expected = _config["PaymentConfig:ApiKey"];
            if (string.IsNullOrWhiteSpace(expected))
            {
                // No key configured — allow (local dev default). In prod always set one.
                return true;
            }
            if (!Request.Headers.TryGetValue("X-Payment-Api-Key", out var provided))
                return false;
            return string.Equals(expected, provided.ToString(), StringComparison.Ordinal);
        }

        /// <summary>
        /// Creates a new pending pamphlet payment transaction. Called by the
        /// Next.js server action <c>createGopayfastUnlockTransaction</c>
        /// right after it obtains a GoPayFast access token.
        /// </summary>
        [HttpPost("pamphlet")]
        public async Task<ActionResult<PaymentTransactionResponse>> CreateAsync(
            [FromBody] CreatePaymentTransactionRequest request)
        {
            if (!IsAuthorizedInternalCaller())
                return Unauthorized(new { message = "Invalid payment API key." });

            if (request == null ||
                string.IsNullOrWhiteSpace(request.EventId) ||
                string.IsNullOrWhiteSpace(request.UserId) ||
                string.IsNullOrWhiteSpace(request.BasketId) ||
                request.Amount <= 0)
            {
                return BadRequest(new { message = "EventId, UserId, BasketId and a positive Amount are required." });
            }

            try
            {
                var result = await _paymentService.CreateAsync(request);
                _logger.LogInformation(
                    "PamphletPayment created: PaymentId={PaymentId} BasketId={BasketId} EventId={EventId} UserId={UserId}",
                    result.PaymentId, result.BasketId, result.EventId, result.UserId);
                return Ok(result);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PamphletPayment create failed");
                return StatusCode(500, new { message = "Failed to create pamphlet payment: " + ex.Message });
            }
        }

        /// <summary>
        /// Returns whether the (eventId, userId) pair has an already-completed
        /// pamphlet payment. Used by the Next.js page to decide between
        /// the locked screen and the downloadable pamphlet.
        /// </summary>
        [HttpGet("pamphlet-status")]
        public async Task<ActionResult<PaymentUnlockStatusResponse>> StatusAsync(
            [FromQuery] string eventId,
            [FromQuery] string userId)
        {
            if (!IsAuthorizedInternalCaller())
                return Unauthorized(new { message = "Invalid payment API key." });

            if (string.IsNullOrWhiteSpace(eventId) || string.IsNullOrWhiteSpace(userId))
                return BadRequest(new { message = "eventId and userId are required." });

            try
            {
                var status = await _paymentService.IsUnlockedAsync(eventId!, userId!);
                return Ok(status);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PamphletPayment status failed");
                return StatusCode(500, new { message = "Failed to read pamphlet status: " + ex.Message });
            }
        }

        /// <summary>
        /// Looks up a transaction by basket id. Used by the GoPayFast
        /// success-callback server action to confirm the basket belongs to
        /// the current event/user and is not already failed.
        /// </summary>
        [HttpGet("pamphlet/by-basket/{basketId}")]
        public async Task<ActionResult<PaymentTransactionResponse>> GetByBasketAsync(string basketId)
        {
            if (!IsAuthorizedInternalCaller())
                return Unauthorized(new { message = "Invalid payment API key." });

            if (string.IsNullOrWhiteSpace(basketId))
                return BadRequest(new { message = "basketId is required." });

            var row = await _paymentService.GetByBasketAsync(basketId);
            if (row == null) return NotFound(new { message = "Transaction not found." });
            return Ok(row);
        }

        /// <summary>
        /// Marks a transaction as completed. Called after the Next.js server
        /// action validates the GoPayFast callback SHA-256 hash.
        /// </summary>
        [HttpPost("pamphlet/complete")]
        public async Task<ActionResult<PaymentTransactionResponse>> CompleteAsync(
            [FromBody] MarkPaymentCompletedRequest request)
        {
            if (!IsAuthorizedInternalCaller())
                return Unauthorized(new { message = "Invalid payment API key." });

            if (request == null || string.IsNullOrWhiteSpace(request.BasketId))
                return BadRequest(new { message = "BasketId is required." });

            try
            {
                var row = await _paymentService.MarkCompletedAsync(request);
                if (row == null) return NotFound(new { message = "No pending transaction for this basket." });
                _logger.LogInformation(
                    "PamphletPayment completed: BasketId={BasketId} TxnId={TxnId}",
                    row.BasketId, row.TransactionId);
                return Ok(row);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PamphletPayment complete failed");
                return StatusCode(500, new { message = "Failed to mark payment complete: " + ex.Message });
            }
        }

        /// <summary>
        /// Marks a transaction as failed with error code+message from GoPayFast.
        /// </summary>
        [HttpPost("pamphlet/fail")]
        public async Task<ActionResult<PaymentTransactionResponse>> FailAsync(
            [FromBody] MarkPaymentFailedRequest request)
        {
            if (!IsAuthorizedInternalCaller())
                return Unauthorized(new { message = "Invalid payment API key." });

            if (request == null || string.IsNullOrWhiteSpace(request.BasketId))
                return BadRequest(new { message = "BasketId is required." });

            try
            {
                var row = await _paymentService.MarkFailedAsync(request);
                if (row == null) return NotFound(new { message = "No pending transaction for this basket." });
                return Ok(row);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "PamphletPayment fail failed");
                return StatusCode(500, new { message = "Failed to mark payment failed: " + ex.Message });
            }
        }
    }
}
