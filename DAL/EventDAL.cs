using Dapper;
using Models.Event;
using Models.Invitation;
using Models.PublicFeed;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DAL
{
    public class EventDAL
    {
        public static async Task<CreateEventResponse> CreateGroupAsync(CreateEventRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // DB function: event_create(CategoryId, PrivacyId, Title, CreatorUserId, EventDateTime, Venue, CoverImageUrl, TagLine, ExpectedGuests, SubCategoryId)
                    string sql = @"
                SELECT * FROM event_create(
                    @EventCategoryId,
                    @PrivacyId,
                    @EventTitle,
                    @CreatorId,
                    @EventDateTime::timestamptz,
                    @Venue,
                    @EventCoverImageUrl,
                    @TagLine,
                    @ExpectedGuestNumber,
                    @SubCategoryId
                )";

                    // Default PrivacyId to 1 (Public) if 0 or invalid; default ExpectedGuestNumber to 1 (DB CHECK requires > 0)
                    int privacyId = request.PrivacyId is 1 or 2 ? request.PrivacyId : 1;
                    int expectedGuests = request.ExpectedGuestNumber > 0 ? request.ExpectedGuestNumber : 1;

                    var result = await conn.QuerySingleAsync<CreateEventResponse>(
                        sql,
                        new
                        {
                            request.EventCategoryId,
                            PrivacyId = privacyId,
                            request.EventTitle,
                            request.CreatorId,
                            request.EventDateTime,
                            request.Venue,
                            request.EventCoverImageUrl,
                            request.TagLine,
                            ExpectedGuestNumber = expectedGuests,
                            SubCategoryId = request.SubCategoryId ?? (object)DBNull.Value
                        }
                    );

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Code 23505: Unique Constraint Violation
                if (ex.SqlState == "23505")
                {
                    throw new InvalidOperationException($"An event with the title '{request.EventTitle}' already exists.");
                }

                // Code 23503: Foreign Key Violation (Invalid category, creator, privacy, or subcategory)
                if (ex.SqlState == "23503")
                {
                    var hint = ex.ConstraintName switch
                    {
                        "fk_events_creator" => "Your user account may not be synced. Try signing out and back in.",
                        "fk_events_category" => "Invalid event category. Please refresh and try again.",
                        "fk_events_privacy" => "Invalid privacy setting. Use Public (1) or Guests Only (2).",
                        "fk_events_sub_category" => "Invalid subcategory for this category.",
                        _ => ex.MessageText
                    };
                    throw new InvalidOperationException(hint);
                }

                // Code P0001: Custom Postgres Exception (e.g. "Event title cannot be empty")
                if (ex.SqlState == "P0001")
                {
                    throw new ArgumentException(ex.MessageText);
                }

                // Include DB detail in message for logging and debugging
                var detail = ex.MessageText + (string.IsNullOrEmpty(ex.Detail) ? "" : " | " + ex.Detail);
                throw new Exception($"Could not create the event group. DB: [{ex.SqlState}] {detail}", ex);
            }
        }

        public static async Task<JoinEventResponse> JoinEventAsync(JoinEventRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: Calling the function
                    string sql = "SELECT * FROM event_join_request_by_code(@AdminCode, @UserId)";

                    var result = await conn.QuerySingleAsync<JoinEventResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Custom Error: "Invalid Event Code provided."
                if (ex.SqlState == "P0001")
                {
                    // We can treat this as a 404 Not Found or 400 Bad Request
                    throw new ArgumentException(ex.Message);
                }

                throw new Exception("System Error: Could not join the event. " + ex.Message);
            }
        }

        public static async Task<IEnumerable<PendingRequestResponse>> GetPendingRequestsAsync(Models.Event.GetPendingRequestsRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    string sql = @"
                SELECT * FROM event_get_pending_requests(
                    @AdminUserId, 
                    @EventId
                )";

                    // Execute: Dapper maps the list of results to IEnumerable<PendingRequestResponse>
                    var result = await conn.QueryAsync<PendingRequestResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                // Log the full error in your actual application
                throw new Exception("System Error: Could not retrieve pending requests.", ex);
            }
        }

        public static async Task<EventNotificationSummaryResponse?> GetEventNotificationSummaryAsync(string eventId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    const string sql = @"
                        SELECT
                            e.pk_event_id AS ""EventId"",
                            COALESCE(ea_creator.fk_user_id, e.fk_creator_id, '') AS ""CreatorId"",
                            COALESCE(e.event_title, '') AS ""EventTitle"",
                            COALESCE(e.event_cover_image_url, '') AS ""EventCoverImageUrl""
                        FROM events e
                        LEFT JOIN event_admins ea_creator
                            ON ea_creator.fk_event_id = e.pk_event_id
                           AND ea_creator.is_creator = TRUE
                        WHERE e.pk_event_id = @EventId";

                    return await conn.QuerySingleOrDefaultAsync<EventNotificationSummaryResponse>(
                        sql,
                        new { EventId = eventId });
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        /// <summary>All admin user IDs for an event (for prayer-approval notifications, etc.).</summary>
        public static async Task<List<string>> GetEventAdminUserIdsAsync(string eventId)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();
                    const string sql = """
                        SELECT fk_user_id::text
                        FROM event_admins
                        WHERE fk_event_id = @EventId
                        """;
                    var rows = await conn.QueryAsync<string>(sql, new { EventId = eventId });
                    return rows.Distinct().ToList();
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<EventDetailResponse?> GetEventByIdAsync(string eventId, string userId)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // User must be admin OR approved guest. Role = Admin or Guest. EventCode from creator's admin_code.
                    string sql = @"
                        SELECT
                            e.pk_event_id AS ""EventId"",
                            e.fk_creator_id AS ""CreatorId"",
                            COALESCE(e.event_title, '') AS ""EventTitle"",
                            COALESCE(e.tag_line, '') AS ""TagLine"",
                            COALESCE(e.event_date_time, e.created_at, NOW())::timestamptz AS ""EventDateTime"",
                            COALESCE(e.venue, '') AS ""Venue"",
                            COALESCE(e.venue, '') AS ""Location"",
                            COALESCE(ea_creator.admin_code, '') AS ""EventCode"",
                            COALESCE(ec.event_category_name, '') AS ""EventCategoryName"",
                            COALESCE(sc.sub_category_name, '') AS ""SubCategoryName"",
                            COALESCE(e.expected_guest_number, 0) AS ""ExpectedGuestNumber"",
                            CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Guest' END AS ""Role"",
                            COALESCE(e.created_at, NOW())::timestamptz AS ""CreatedAt"",
                            COALESCE(e.event_cover_image_url, '') AS ""EventCoverImageUrl"",
                            CASE WHEN e.fk_event_privacy_id = 1 THEN 'Public' ELSE 'Private' END AS ""EventType""
                        FROM events e
                        LEFT JOIN event_categories ec ON ec.pk_event_category_id = e.fk_event_category_id
                        LEFT JOIN sub_categories sc ON sc.pk_sub_category_id = e.fk_sub_category_id
                        LEFT JOIN event_admins ea_creator ON ea_creator.fk_event_id = e.pk_event_id AND ea_creator.is_creator = TRUE
                        LEFT JOIN event_admins ea ON ea.fk_event_id = e.pk_event_id AND ea.fk_user_id = @UserId
                        LEFT JOIN event_guests eg ON eg.fk_event_id = e.pk_event_id AND eg.fk_user_id = @UserId AND eg.fk_request_status_id = 2
                        WHERE e.pk_event_id = @EventId
                          AND (ea.pk_event_admin_id IS NOT NULL OR eg.pk_event_guest_id IS NOT NULL)";
                    var ev = await conn.QuerySingleOrDefaultAsync<dynamic>(sql, new { EventId = eventId, UserId = userId });

                    // 2. Public viewer path: Event is public, user is not a member. Role = Viewer, no EventCode.
                    if (ev == null)
                    {
                        string publicSql = @"
                            SELECT
                                e.pk_event_id AS ""EventId"",
                                e.fk_creator_id AS ""CreatorId"",
                                COALESCE(e.event_title, '') AS ""EventTitle"",
                                COALESCE(e.tag_line, '') AS ""TagLine"",
                                COALESCE(e.event_date_time, e.created_at, NOW())::timestamptz AS ""EventDateTime"",
                                COALESCE(e.venue, '') AS ""Venue"",
                                COALESCE(e.venue, '') AS ""Location"",
                                '' AS ""EventCode"",
                                COALESCE(ec.event_category_name, '') AS ""EventCategoryName"",
                                COALESCE(sc.sub_category_name, '') AS ""SubCategoryName"",
                                COALESCE(e.expected_guest_number, 0) AS ""ExpectedGuestNumber"",
                                'Viewer' AS ""Role"",
                                COALESCE(e.created_at, NOW())::timestamptz AS ""CreatedAt"",
                                COALESCE(e.event_cover_image_url, '') AS ""EventCoverImageUrl"",
                                'Public' AS ""EventType""
                            FROM events e
                            LEFT JOIN event_categories ec ON ec.pk_event_category_id = e.fk_event_category_id
                            LEFT JOIN sub_categories sc ON sc.pk_sub_category_id = e.fk_sub_category_id
                            WHERE e.pk_event_id = @EventId
                              AND e.fk_event_privacy_id = 1";
                        ev = await conn.QuerySingleOrDefaultAsync<dynamic>(publicSql, new { EventId = eventId });
                        if (ev == null) return null;
                    }

                    var detail = new EventDetailResponse
                    {
                        EventId = (string?)ev.EventId ?? "",
                        CreatorId = (string?)ev.CreatorId ?? "",
                        EventTitle = (string?)ev.EventTitle ?? "",
                        TagLine = (string?)ev.TagLine ?? "",
                        EventDateTime = ev.EventDateTime is DateTime dt ? dt : DateTime.UtcNow,
                        Venue = (string?)ev.Venue ?? "",
                        Location = (string?)ev.Location ?? "",
                        EventCode = (string?)ev.EventCode ?? "",
                        EventCategoryName = (string?)ev.EventCategoryName ?? "",
                        SubCategoryName = (string?)ev.SubCategoryName ?? "",
                        ExpectedGuestNumber = Convert.ToInt32(ev.ExpectedGuestNumber),
                        Role = (string?)ev.Role ?? "Guest",
                        CreatedAt = ev.CreatedAt is DateTime ca ? ca : DateTime.UtcNow,
                        EventCoverImageUrl = (string?)ev.EventCoverImageUrl ?? "",
                        EventType = (string?)ev.EventType ?? "Private"
                    };

                    var gallerySql = @"SELECT image_url FROM event_images WHERE fk_event_id = @EventId AND is_approved = TRUE ORDER BY created_at";
                    var urls = await conn.QueryAsync<string>(gallerySql, new { EventId = eventId });
                    detail.GalleryImageUrls = urls.ToList();

                    // Load invitation card (invitation_cards or similar - try both schemas)
                    var invSql = @"
                        SELECT headline AS ""Headline"", couple_names AS ""CoupleNames"", invitation_text AS ""InvitationText"",
                               event_date AS ""EventDate"", event_time AS ""EventTime"", description AS ""Description"",
                               address AS ""Address"", template_id AS ""TemplateId"",
                               COALESCE(invitation_card_url, '') AS ""InvitationCardUrl""
                        FROM invitation_cards WHERE event_id = @EventId";
                    try
                    {
                        var inv = await conn.QuerySingleOrDefaultAsync<Models.Invitation.InvitationCardResponse>(invSql, new { EventId = eventId });
                        detail.InvitationCard = inv;
                    }
                    catch { /* invitation_cards may not exist or use different schema */ }

                    return detail;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<bool> UpdateEventAsync(string eventId, string userId, UpdateEventRequest request)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    int updated = await conn.ExecuteAsync(@"
                        UPDATE events SET
                            event_title = @EventTitle,
                            tag_line = @TagLine,
                            event_date_time = @EventDateTime,
                            venue = @Venue,
                            expected_guest_number = @ExpectedGuestNumber,
                            event_cover_image_url = @EventCoverImageUrl
                        FROM event_admins ea
                        WHERE events.pk_event_id = ea.fk_event_id 
                          AND events.pk_event_id = @EventId 
                          AND ea.fk_user_id = @UserId",
                        new
                        {
                            EventId = eventId,
                            UserId = userId,
                            request.EventTitle,
                            request.TagLine,
                            request.EventDateTime,
                            request.Venue,
                            request.Location,
                            request.ExpectedGuestNumber,
                            request.EventCoverImageUrl
                        });
                    return updated > 0;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<int> AddEventImageAsync(string eventId, string userId, string imageUrl)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    var hasAccess = await conn.ExecuteScalarAsync<int?>(
                        "SELECT 1 FROM event_members WHERE event_id = @eid::uuid AND user_id = @uid::uuid AND role = 'Admin' LIMIT 1",
                        new { eid = eventId, uid = userId });
                    if (hasAccess != 1) return 0;

                    var maxOrder = await conn.QuerySingleOrDefaultAsync<int?>(
                        "SELECT COALESCE(MAX(display_order), 0) FROM event_images WHERE event_id = @eid::uuid",
                        new { eid = eventId }) ?? 0;

                    var inserted = await conn.ExecuteScalarAsync<int>(@"
                        INSERT INTO event_images (event_id, image_url, display_order)
                        VALUES (@eid::uuid, @url, @order)
                        RETURNING image_id", new { eid = eventId, url = imageUrl, order = maxOrder + 1 });
                    return inserted;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<bool> UpdateInvitationCardAsync(string eventId, string userId, UpdateInvitationCardRequest request)
        {
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    int rows = await conn.ExecuteAsync(@"
                        INSERT INTO invitation_cards (event_id, headline, couple_names, invitation_text, event_date, event_time, description, address, template_id, invitation_card_url, updated_at)
                        SELECT @EventId, @Headline, @CoupleNames, @InvitationText, @EventDate, @EventTime, @Description, @Address, @TemplateId, @InvitationCardUrl, NOW()
                        FROM event_admins ea
                        WHERE ea.fk_event_id = @EventId AND ea.fk_user_id = @UserId
                        ON CONFLICT (event_id) DO UPDATE SET
                            headline = @Headline,
                            couple_names = @CoupleNames,
                            invitation_text = @InvitationText,
                            event_date = @EventDate,
                            event_time = @EventTime,
                            description = @Description,
                            address = @Address,
                            template_id = @TemplateId,
                            invitation_card_url = @InvitationCardUrl,
                            updated_at = NOW()",
                        new
                        {
                            EventId = eventId,
                            UserId = userId,
                            request.Headline,
                            request.CoupleNames,
                            request.InvitationText,
                            request.EventDate,
                            request.EventTime,
                            request.Description,
                            request.Address,
                            request.TemplateId,
                            InvitationCardUrl = request.InvitationCardUrl ?? string.Empty
                        });
                    return rows > 0;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<IEnumerable<EventResponse>> GetEventsByUserAsync(string userId)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // Events where user is admin (event_admins) OR approved guest (event_guests, status=2)
                    string sql = @"
                        SELECT DISTINCT
                            e.pk_event_id AS EventId,
                            COALESCE(e.fk_creator_id::TEXT, '') AS CreatorId,
                            e.event_title AS EventTitle,
                            COALESCE(e.tag_line, '') AS TagLine,
                            e.event_date_time AS EventDateTime,
                            COALESCE(e.venue, '') AS Venue,
                            COALESCE(e.venue, '') AS Location,
                            COALESCE(ea_creator.admin_code, '') AS EventCode,
                            COALESCE(ec.event_category_name, '') AS EventCategoryName,
                            COALESCE(sc.sub_category_name, '') AS SubCategoryName,
                            COALESCE(e.expected_guest_number, 0) AS ExpectedGuestNumber,
                            CASE WHEN ea.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Guest' END AS Role,
                            e.created_at AS CreatedAt,
                            COALESCE(e.event_cover_image_url, '') AS EventCoverImageUrl,
                            CASE WHEN e.fk_event_privacy_id = 1 THEN 'Public' ELSE 'Private' END AS EventType
                        FROM events e
                        LEFT JOIN event_categories ec ON ec.pk_event_category_id = e.fk_event_category_id
                        LEFT JOIN sub_categories sc ON sc.pk_sub_category_id = e.fk_sub_category_id
                        LEFT JOIN event_admins ea_creator ON ea_creator.fk_event_id = e.pk_event_id AND ea_creator.is_creator = TRUE
                        LEFT JOIN event_admins ea ON ea.fk_event_id = e.pk_event_id AND ea.fk_user_id = @UserId
                        LEFT JOIN event_guests eg ON eg.fk_event_id = e.pk_event_id AND eg.fk_user_id = @UserId AND eg.fk_request_status_id = 2
                        WHERE ea.pk_event_admin_id IS NOT NULL OR eg.pk_event_guest_id IS NOT NULL
                        ORDER BY e.created_at DESC";
                    var parameters = new { UserId = userId };

                    var result = await conn.QueryAsync<EventResponse>(sql, parameters);
                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        public static async Task<IEnumerable<PublicFeedEventResponse>> GetPublicFeedAsync(GetPublicFeedRequest request)
        {
            string connectionString = DBHelper.GetConnection();

            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();

                    // SQL: The parameter order MUST match the SQL function exactly
                    string sql = @"
                SELECT * FROM event_get_public_feed(
                    @PageSize,
                    @CursorDate,
                    @CursorEventId,
                    @Search
                )";

                    var result = await conn.QueryAsync<PublicFeedEventResponse>(sql, request);

                    return result;
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception("System Error: Could not retrieve the public feed. Error: " + ex.Message, ex);
            }
        }

        /// <summary>
        /// Vertical scroll feed: all events the user joined or admins, plus public events they are not a member of (with cap).
        /// </summary>
        public static async Task<IEnumerable<EventScrollItemResponse>> GetEventsScrollFeedAsync(string userId)
        {
            const int publicCap = 200;
            string connectionString = DBHelper.GetConnection();
            try
            {
                using (var conn = new NpgsqlConnection(connectionString))
                {
                    await conn.OpenAsync();
                    // Flat rows for Dapper, then map invitation.
                    const string sql = """
                        WITH me AS (
                            SELECT fk_event_id AS eid
                            FROM event_admins
                            WHERE fk_user_id = @UserId
                            UNION
                            SELECT fk_event_id
                            FROM event_guests
                            WHERE fk_user_id = @UserId AND fk_request_status_id = 2
                        ),
                        member_rows AS (
                            SELECT
                                e.pk_event_id AS "EventId",
                                COALESCE(e.event_title, '') AS "EventTitle",
                                COALESCE(e.tag_line, '') AS "TagLine",
                                COALESCE(e.event_date_time, e.created_at, NOW())::timestamptz AS "EventDateTime",
                                COALESCE(e.venue, '') AS "Venue",
                                COALESCE(e.event_cover_image_url, '') AS "EventCoverImageUrl",
                                CASE WHEN e.fk_event_privacy_id = 1 THEN 'Public' ELSE 'Private' END AS "EventType",
                                CASE WHEN ea_m.pk_event_admin_id IS NOT NULL THEN 'Admin' ELSE 'Guest' END AS "Role",
                                TRUE AS "IsMember",
                                ic.headline AS "IcHeadline",
                                ic.couple_names AS "IcCoupleNames",
                                ic.invitation_text AS "IcInvitationText",
                                ic.event_date AS "IcEventDate",
                                ic.event_time AS "IcEventTime",
                                ic.description AS "IcDescription",
                                ic.address AS "IcAddress",
                                ic.template_id AS "IcTemplateId",
                                ic.invitation_card_url AS "IcInvitationCardUrl"
                            FROM events e
                            INNER JOIN me ON me.eid = e.pk_event_id
                            LEFT JOIN event_admins ea_m ON ea_m.fk_event_id = e.pk_event_id AND ea_m.fk_user_id = @UserId
                            LEFT JOIN invitation_cards ic ON ic.event_id = e.pk_event_id
                        ),
                        public_rows AS (
                            SELECT
                                e.pk_event_id AS "EventId",
                                COALESCE(e.event_title, '') AS "EventTitle",
                                COALESCE(e.tag_line, '') AS "TagLine",
                                COALESCE(e.event_date_time, e.created_at, NOW())::timestamptz AS "EventDateTime",
                                COALESCE(e.venue, '') AS "Venue",
                                COALESCE(e.event_cover_image_url, '') AS "EventCoverImageUrl",
                                'Public' AS "EventType",
                                'Viewer' AS "Role",
                                FALSE AS "IsMember",
                                ic.headline AS "IcHeadline",
                                ic.couple_names AS "IcCoupleNames",
                                ic.invitation_text AS "IcInvitationText",
                                ic.event_date AS "IcEventDate",
                                ic.event_time AS "IcEventTime",
                                ic.description AS "IcDescription",
                                ic.address AS "IcAddress",
                                ic.template_id AS "IcTemplateId",
                                ic.invitation_card_url AS "IcInvitationCardUrl"
                            FROM events e
                            LEFT JOIN invitation_cards ic ON ic.event_id = e.pk_event_id
                            WHERE e.fk_event_privacy_id = 1
                              AND NOT EXISTS (SELECT 1 FROM me WHERE me.eid = e.pk_event_id)
                            ORDER BY COALESCE(e.event_date_time, e.created_at) DESC NULLS LAST, e.pk_event_id DESC
                            LIMIT @PublicCap
                        )
                        SELECT * FROM member_rows
                        UNION ALL
                        SELECT * FROM public_rows
                        ORDER BY 4 DESC
                        """;
                    var rows = await conn.QueryAsync<EventScrollSqlRow>(sql, new { UserId = userId, PublicCap = publicCap });
                    return rows.Select(MapScrollRow).Where(x => x != null).Cast<EventScrollItemResponse>();
                }
            }
            catch (PostgresException ex)
            {
                throw new Exception($"Database Error: {ex.MessageText}", ex);
            }
        }

        private sealed class EventScrollSqlRow
        {
            public string EventId { get; set; } = string.Empty;
            public string EventTitle { get; set; } = string.Empty;
            public string TagLine { get; set; } = string.Empty;
            public DateTime EventDateTime { get; set; }
            public string Venue { get; set; } = string.Empty;
            public string EventCoverImageUrl { get; set; } = string.Empty;
            public string EventType { get; set; } = string.Empty;
            public string Role { get; set; } = string.Empty;
            public bool IsMember { get; set; }
            public string? IcHeadline { get; set; }
            public string? IcCoupleNames { get; set; }
            public string? IcInvitationText { get; set; }
            public string? IcEventDate { get; set; }
            public string? IcEventTime { get; set; }
            public string? IcDescription { get; set; }
            public string? IcAddress { get; set; }
            public int? IcTemplateId { get; set; }
            public string? IcInvitationCardUrl { get; set; }
        }

        private static EventScrollItemResponse? MapScrollRow(EventScrollSqlRow r)
        {
            if (string.IsNullOrEmpty(r.EventId)) return null;
            InvitationCardResponse? inv = null;
            if (HasAnyInvitationData(r))
            {
                inv = new InvitationCardResponse
                {
                    Headline = r.IcHeadline ?? string.Empty,
                    CoupleNames = r.IcCoupleNames ?? string.Empty,
                    InvitationText = r.IcInvitationText ?? string.Empty,
                    EventDate = r.IcEventDate ?? string.Empty,
                    EventTime = r.IcEventTime ?? string.Empty,
                    Description = r.IcDescription ?? string.Empty,
                    Address = r.IcAddress ?? string.Empty,
                    TemplateId = r.IcTemplateId ?? 1,
                    InvitationCardUrl = r.IcInvitationCardUrl ?? string.Empty
                };
            }
            return new EventScrollItemResponse
            {
                EventId = r.EventId,
                EventTitle = r.EventTitle,
                TagLine = r.TagLine,
                EventDateTime = r.EventDateTime,
                Venue = r.Venue,
                EventCoverImageUrl = r.EventCoverImageUrl,
                EventType = string.IsNullOrEmpty(r.EventType) ? "Private" : r.EventType,
                Role = string.IsNullOrEmpty(r.Role) ? "Guest" : r.Role,
                IsMember = r.IsMember,
                InvitationCard = inv
            };
        }

        private static bool HasAnyInvitationData(EventScrollSqlRow r)
        {
            if (!string.IsNullOrWhiteSpace(r.IcInvitationCardUrl)) return true;
            if (!string.IsNullOrWhiteSpace(r.IcHeadline) && r.IcHeadline != "TOGETHER WITH THEIR FAMILIES") return true;
            if (!string.IsNullOrWhiteSpace(r.IcCoupleNames)) return true;
            if (!string.IsNullOrWhiteSpace(r.IcInvitationText) && r.IcInvitationText != "INVITE YOU TO CELEBRATE THEIR WEDDING") return true;
            if (!string.IsNullOrWhiteSpace(r.IcEventDate)) return true;
            if (!string.IsNullOrWhiteSpace(r.IcEventTime)) return true;
            if (!string.IsNullOrWhiteSpace(r.IcDescription)) return true;
            if (!string.IsNullOrWhiteSpace(r.IcAddress)) return true;
            return false;
        }
    }
}
