-- split up each source into individual row; renormalize metrics accordingly
SELECT 
    user_id,
    email,
    created_at,
    first_session_ts,
    last_session_ts,
    utm,
    utm_ts_list[OFFSET(off)] as utm_ts,  -- Accessing utm_ts at the same offset
    1/greatest(1,array_length(ext_utm_list)) users,
    revenue/greatest(1,array_length(ext_utm_list)) revenue,
    bookings/greatest(1,array_length(ext_utm_list)) bookings,
    paid_bookings/greatest(1,array_length(ext_utm_list)) paid_bookings,
    reports/greatest(1,array_length(ext_utm_list)) reports,
    sessions/greatest(1,array_length(ext_utm_list)) sessions
FROM {{ref("users_enriched")}} left join unnest(ext_utm_list) as utm WITH OFFSET as off
