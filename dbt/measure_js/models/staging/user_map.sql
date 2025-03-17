select 
    coalesce(s2.session_id,s.session_id) session_id,
    s.user_id
from (
    select 
        session_id,
        client_id,
        user_id,
        any_value(no_client_id) no_client_id
    from {{ ref('events_sessionated') }} 
    group by 1,2,3
    ) s
left join {{ ref('sessions') }} s2 on not s.no_client_id and not s2.no_client_id and s.client_id=s2.client_id -- get all sessions from current client_id if we have a proper client id 
group by 1,2