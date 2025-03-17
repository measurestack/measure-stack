select 
    u.user_id,
    s.session_id, --latest sesion with start_ts < user creation ts
from 
{{ ref('firestore_users') }} u 
left join {{ ref('user_map')}} m on u.user_id = m.user_id
left join {{ref('sessions')}} s on m.session_id = s.session_id
QUALIFY (
    ROW_NUMBER() OVER (
        PARTITION BY u.user_id 
        ORDER BY LEAST(
            COALESCE(ABS(UNIX_MICROS(s.start_ts) - UNIX_MICROS(u.created_at)), 1e16),  -- using a large default
            COALESCE(ABS(UNIX_MICROS(s.end_ts) - UNIX_MICROS(u.created_at)), 1e16)
        )
    )
) = 1
