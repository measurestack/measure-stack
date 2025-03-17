WITH UserSessions AS (
    SELECT 
        u.session_id,
        COUNT(DISTINCT u.user_id) AS users_created
    FROM {{ ref('usercreation2sessions') }} u
    GROUP BY u.session_id
),

BookingSessions AS (
    SELECT 
        b.session_id,
        COUNT(DISTINCT b.booking_id) AS bookings,
        SUM(CASE WHEN b2.is_paid THEN 1 ELSE 0 END) AS paid_bookings,
        -- ARRAY_AGG(b2.booking_id IGNORE NULLS) AS bookings_a,
        SUM(b2.revenue) AS revenue
    FROM {{ ref('bookings2sessions') }} b
    LEFT JOIN {{ ref('bookings_validated') }} b2 ON b.booking_id = b2.booking_id
    GROUP BY b.session_id
),

ReportSessions AS (
    SELECT 
        r.session_id,
        COUNT(DISTINCT r.report_id) AS reports,
        -- ARRAY_AGG(r.report_id IGNORE NULLS) AS reports_a
    FROM {{ ref('reports2sessions') }} r
    GROUP BY r.session_id
),
aggregated AS (
    SELECT
        COALESCE(u.session_id, b.session_id, r.session_id) AS session_id,
        u.users_created,
        b.bookings,
        b.paid_bookings,
        b.revenue,
        r.reports,
    FROM UserSessions u
    FULL OUTER JOIN BookingSessions b ON u.session_id = b.session_id
    FULL OUTER JOIN ReportSessions r ON COALESCE(u.session_id, b.session_id) = r.session_id
)
SELECT 
    s.*,
    1 sessions,
    CONCAT(ifnull(utm.source,''), '/', ifnull(utm.medium,''), ':', ifnull(utm.campaign,'')) source,
    ifnull(a.users_created,0) users_created,
    IFNULL(a.bookings, 0) AS bookings,
    IFNULL(a.paid_bookings, 0) AS paid_bookings,
    IFNULL(a.revenue, 0) AS revenue,
    IFNULL(a.reports, 0) AS reports,
FROM {{ref('sessions_attributed')}} s
LEFT JOIN aggregated a ON s.session_id = a.session_id