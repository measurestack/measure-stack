select u.* replace (coalesce(u.created_at, e.timestamp) as created_at)
from {{ source('firestore','users') }} u
left join (
    select 
        user_id,
        min(timestamp) timestamp
    from {{ source('tracking','events') }}
    where user_id is not null
    group by user_id
) e using (user_id)