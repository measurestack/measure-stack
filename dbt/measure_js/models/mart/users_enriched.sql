with booking_aggr as (
    select 
        user_id, 
        count(*) bookings, 
        SUM(CASE WHEN is_paid THEN 1 ELSE 0 END) AS paid_bookings, 
        sum(revenue) revenue 
    from {{ ref('bookings_validated')}} 
    group by 1
), report_aggr as (
    select 
        user_id, 
        count(*) reports 
    from {{ source('firestore','reports')}} 
    group by 1
)
SELECT
    u.user_id,
    u.email,
    coalesce(u.created_at,u2.first_session_ts) created_at, -- this is a fix for first users which did not have a created_at
    first_session_ts,
    last_session_ts,
    first_utm,
    last_utm,
    ext_utm_list,
    utm_ts_list,
    touchpoints,
    sessions,
    1 users,
{% for metric in var('session_metrics', []) %}
    {{ metric.name }},
{% endfor %} 
    b.revenue,
    b.bookings,
    b.paid_bookings,
    r.reports,
from {{ ref('firestore_users')}}  u
left join {{ ref('users_attributed')}} u2 on u2.user_id=u.user_id
left join booking_aggr b on b.user_id = u.user_id
left join report_aggr r on r.user_id = u.user_id
