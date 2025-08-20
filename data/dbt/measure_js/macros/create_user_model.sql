{% macro create_user_model(source_table) %}

-- IMPORTANT: as multiple users could login into the same session, this may fan-out some metrics, in parrtuclar #sessions
SELECT
    user_id,
    min(start_ts) first_session_ts,
    max(end_ts) last_session_ts,
    ARRAY_AGG(utm ORDER BY start_ts ASC)[OFFSET(0)] as first_utm, 
    ARRAY_AGG(utm ORDER BY start_ts DESC)[OFFSET(0)] as last_utm,
    ARRAY_AGG(case when not is_external or s.utm.source is null then null else s.utm end ignore nulls ORDER BY start_ts ASC) ext_utm_list,
    ARRAY_AGG(case when not is_external or s.utm.source is null then null else start_ts end ignore nulls ORDER BY start_ts ASC) utm_ts_list,
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
FROM {{ source_table }} s
LEFT JOIN {{ ref('user_map') }} u on s.session_id=u.session_id
where user_id is not null
GROUP BY user_id

{% endmacro %}
