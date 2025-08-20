{% macro daily_performance(table_name, date_column, utm, metrics) %}
SELECT
    date,
    account_name,
    campaign_name,
    adset_name,
    ad_name,
    ad_id,
    channel,
    platform,
    data_source,
    0 spend,
    0 impressions,
    0 reach,
    0 clicks,
    0 engagement,
    {% for metric in metrics %}
        {{ metric }},
    {% endfor %}
FROM (
    SELECT
        DATE({{ date_column }}) AS date,
        {{ utm }}.source,
        {{ utm }}.medium,
        {{ utm }}.campaign,
        {{ utm }}.term,
        {{ utm }}.content,
        {{ utm }}.id,
        account_name,
        coalesce(campaign_name, {{ utm }}.campaign) campaign_name,
        coalesce(adset_name,{{ utm }}.term) adset_name,
        coalesce(ad_name,{{ utm }}.content) ad_name,
        coalesce(cast(ad_id as string),{{ utm }}.id) ad_id,
        coalesce(channel,{{ utm }}.medium) channel,
        coalesce(platform,{{ utm }}.source) platform,
        'tracking' as data_source,
        {% for metric in metrics %}
            sum({{ metric }}) as {{ metric }},
        {% endfor %}
    FROM {{ table_name }} u

    LEFT JOIN {{ ref('google_ads_hierarchy') }} go ON u.{{ utm }}.id = CAST(go.ad_id AS string)
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
)
{% endmacro %}
