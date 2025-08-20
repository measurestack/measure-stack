WITH aggregated_sessions AS (
SELECT
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
    SUM(CASE WHEN event_name='pageview' THEN 1 ELSE 0 END) pageviews, -- FIXME: should we use is_pageview instead?
    SUM(CASE WHEN event_type='event' THEN 1 ELSE 0 END) events, -- includes pageviews
    count(*) hits,
    {% for metric in var('session_metrics', []) %}
    {% if metric.count_once %}
    CASE WHEN SUM(CASE WHEN {{ metric.condition }} THEN 1 ELSE 0 END)>0 THEN 1 ELSE 0 END {{ metric.name }},
    {% else %}
    SUM(CASE WHEN {{ metric.condition }} THEN 1 ELSE 0 END) {{ metric.name }},
    {% endif %}
    {% endfor %}
FROM
    {{ ref('events_sessionated') }}
GROUP BY
    session_id,client_id,`hash`
)

SELECT
    s.* REPLACE(COALESCE(s2.utm,s.utm) AS utm, COALESCE(s2.clid, s.clid) AS clid)  -- attribute earlier utm parameters if current session does not have any
FROM aggregated_sessions s
LEFT JOIN aggregated_sessions s2 ON NOT s.is_external AND s.client_id=s2.client_id AND s.start_ts>s2.start_ts AND s2.is_external IS NOT NULL AND s2.is_external AND ((s.`hash`!= s.client_id AND timestamp_diff(s.start_ts,s2.start_ts,day)<30) OR timestamp_diff(s.start_ts,s2.start_ts,hour)<24) -- hash is attributed for 24h max. ; client_id for 30 days
WHERE NOT s.device.is_bot AND NOT s.is_stub
QUALIFY ROW_NUMBER() OVER (PARTITION BY s.session_id ORDER BY s2.start_ts DESC)=1
