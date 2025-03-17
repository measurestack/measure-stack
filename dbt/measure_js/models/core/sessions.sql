with aggregated_sessions as (
select
    MIN(timestamp) start_ts,
    MAX(timestamp) end_ts,
    session_id,
    client_id,
    `hash`,
    any_value(user_agent) user_agent,
    any_value(device) device,
    any_value(location) location,
    any_value(landing_page) landing_page,
    any_value(source_referrer) source_referrer,
    any_value(utm) utm,
    any_value(clid) clid,
    any_value(is_ext_session) is_external,
    any_value(is_stub_session) is_stub,
    any_value(no_client_id) no_client_id,
    sum(case when event_name='pageview' then 1 else 0 end) pageviews, -- FIXME: should we use is_pageview instead?
    sum(case when event_type='event' then 1 else 0 end) events, -- includes pageviews
    count(*) hits,
    {% for metric in var('session_metrics', []) %}
    {% if metric.count_once %}
    case when sum(case when {{ metric.condition }} then 1 else 0 end)>0 then 1 else 0 end {{ metric.name }},
    {% else %}
    sum(case when {{ metric.condition }} then 1 else 0 end) {{ metric.name }},
    {% endif %}
    {% endfor %}
FROM
    {{ ref('events_sessionated') }}
GROUP BY
    session_id,client_id,`hash`
)

SELECT 
    s.* replace(coalesce(s2.utm,s.utm) as utm, coalesce(s2.clid, s.clid) as clid),  -- attribute earlier utm parameters if current session does not have any
from aggregated_sessions s
left join aggregated_sessions s2 on not s.is_external and s.client_id=s2.client_id and s.start_ts>s2.start_ts and s2.is_external is not null and s2.is_external and ((s.`hash`!= s.client_id and timestamp_diff(s.start_ts,s2.start_ts,day)<30)or timestamp_diff(s.start_ts,s2.start_ts,hour)<24) -- hash is attributed for 24h max. ; client_id for 30 days
where not s.device.is_bot and not s.is_stub
qualify row_number() over (partition by s.session_id order by s2.start_ts desc)=1
