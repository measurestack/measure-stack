SELECT
    client_id,
    min(start_ts) first_session_ts,
    max(end_ts) last_session_ts,
    ARRAY_AGG(utm ORDER BY start_ts ASC)[OFFSET(0)] as first_utm, 
    ARRAY_AGG(utm ORDER BY start_ts DESC)[OFFSET(0)] as last_utm,
    STRING_AGG(
        CASE 
            WHEN is_external THEN CONCAT(ifnull(utm.source,''), '/', ifnull(utm.medium,''), ':', ifnull(utm.campaign,''))
            ELSE NULL 
        END, 
        " > " ORDER BY start_ts ASC
    ) as touchpoints, 
    count(*) sessions,
    {% for metric in var('session_metrics', []) %}
    {% if metric.count_once %}
    case when sum({{ metric.name }})>0 then 1 else 0 end {{ metric.name }},
    {% else %}
    sum({{ metric.name }}) {{ metric.name }},
    {% endif %}
    {% endfor %} 
    any_value(no_client_id) no_client_id,
FROM {{ ref('sessions') }}
GROUP BY client_id

