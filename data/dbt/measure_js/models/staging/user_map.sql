SELECT
    COALESCE(s2.session_id,s.session_id) session_id,
    s.user_id
FROM (
    SELECT
        session_id,
        client_id,
        user_id,
        any_value(no_client_id) no_client_id
    FROM {{ ref('events_sessionated') }}
    GROUP BY 1,2,3
    ) s
LEFT JOIN {{ ref('sessions') }} s2 ON NOT s.no_client_id AND NOT s2.no_client_id and s.client_id=s2.client_id -- get all sessions from current client_id if we have a proper client id
GROUP BY 1,2
