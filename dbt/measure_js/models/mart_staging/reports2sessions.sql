select 
    r.report_id,
    s.session_id, --latest sesion with start_ts < user creation ts
from 
{{ source('firestore','reports')}} r
left join {{ ref('user_map')}} m on r.user_id = m.user_id
left join {{ref('sessions')}} s on m.session_id = s.session_id
QUALIFY (
    ROW_NUMBER() OVER (
        PARTITION BY r.report_id 
        ORDER BY LEAST(
            COALESCE(ABS(UNIX_MICROS(s.start_ts) - UNIX_MICROS(r.started)), 1e16),  -- using a large default
            COALESCE(ABS(UNIX_MICROS(s.end_ts) - UNIX_MICROS(r.started)), 1e16)
        )
    )
) = 1