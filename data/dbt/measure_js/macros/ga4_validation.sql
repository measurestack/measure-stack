{#
  GA4 Event Validation and Enrichment Macros

  These macros provide validation and enrichment functions for GA4 events
  to ensure data quality and consistency across your analytics pipeline.

  Usage:
    {{ ga4_validate_currency(currency) }}
    {{ ga4_enrich_event_category(event_name) }}
    {{ ga4_validate_ecommerce_event(event_name, parameters) }}
#}

{% macro ga4_validate_currency(currency) %}
  CASE
    WHEN {{ currency }} IS NULL THEN 'EUR'
    WHEN {{ currency }} IN ('USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CNY', 'INR', 'BRL', 'MXN') THEN {{ currency }}
    ELSE 'EUR'
  END
{% endmacro %}

{% macro ga4_enrich_event_category(event_name) %}
  CASE
    -- Ecommerce Events
    WHEN {{ event_name }} IN ('purchase', 'view_item', 'add_to_cart', 'begin_checkout', 'view_cart', 'remove_from_cart', 'view_item_list', 'add_to_wishlist', 'view_promotion', 'select_promotion') THEN 'ecommerce'

    -- Engagement Events
    WHEN {{ event_name }} IN ('page_view', 'scroll', 'video_start', 'video_progress', 'video_complete', 'file_download', 'form_start', 'form_submit') THEN 'engagement'

    -- User Lifecycle Events
    WHEN {{ event_name }} IN ('sign_up', 'login', 'logout', 'generate_lead', 'join_group', 'share', 'search') THEN 'user_lifecycle'

    -- Custom Events
    WHEN {{ event_name }} NOT IN ('purchase', 'view_item', 'add_to_cart', 'begin_checkout', 'view_cart', 'remove_from_cart', 'view_item_list', 'add_to_wishlist', 'view_promotion', 'select_promotion', 'page_view', 'scroll', 'video_start', 'video_progress', 'video_complete', 'file_download', 'form_start', 'form_submit', 'sign_up', 'login', 'logout', 'generate_lead', 'join_group', 'share', 'search') THEN 'custom'

    ELSE 'other'
  END
{% endmacro %}

{% macro ga4_validate_ecommerce_event(event_name, parameters) %}
  CASE
    WHEN {{ event_name }} IN ('purchase', 'view_item', 'add_to_cart', 'begin_checkout') THEN
      CASE
        WHEN JSON_VALUE({{ parameters }}, '$.currency') IS NULL THEN FALSE
        WHEN JSON_VALUE({{ parameters }}, '$.value') IS NULL THEN FALSE
        WHEN CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64) <= 0 THEN FALSE
        ELSE TRUE
      END
    WHEN {{ event_name }} = 'view_item' THEN
      CASE
        WHEN JSON_VALUE({{ parameters }}, '$.item_id') IS NULL THEN FALSE
        WHEN JSON_VALUE({{ parameters }}, '$.item_name') IS NULL THEN FALSE
        ELSE TRUE
      END
    ELSE TRUE
  END
{% endmacro %}

{% macro ga4_calculate_session_value(parameters) %}
  CASE
    WHEN JSON_VALUE({{ parameters }}, '$.value') IS NOT NULL
    THEN CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64)
    ELSE 0
  END
{% endmacro %}

{% macro ga4_extract_custom_dimensions(parameters, max_dimensions) %}
  {% set dimensions = [] %}
  {% for i in range(1, max_dimensions + 1) %}
    {% set dimensions = dimensions + ['JSON_VALUE(' + parameters + ', "$.custom_dimension' + i|string + '") AS custom_dimension' + i|string] %}
  {% endfor %}
  {{ dimensions | join(', ') }}
{% endmacro %}

{% macro ga4_extract_custom_metrics(parameters, max_metrics) %}
  {% set metrics = [] %}
  {% for i in range(1, max_metrics + 1) %}
    {% set metrics = metrics + ['CAST(JSON_VALUE(' + parameters + ', "$.custom_metric' + i|string + '") AS FLOAT64) AS custom_metric' + i|string] %}
  {% endfor %}
  {{ metrics | join(', ') }}
{% endmacro %}

{% macro ga4_parse_user_properties(parameters) %}
  STRUCT(
    JSON_VALUE({{ parameters }}, '$.user_properties.user_type') AS user_type,
    JSON_VALUE({{ parameters }}, '$.user_properties.user_tier') AS user_tier,
    JSON_VALUE({{ parameters }}, '$.user_properties.subscription_status') AS subscription_status,
    JSON_VALUE({{ parameters }}, '$.user_properties.account_age_days') AS account_age_days,
    JSON_VALUE({{ parameters }}, '$.user_properties.last_purchase_date') AS last_purchase_date,
    JSON_VALUE({{ parameters }}, '$.user_properties.total_purchases') AS total_purchases,
    JSON_VALUE({{ parameters }}, '$.user_properties.lifetime_value') AS lifetime_value
  )
{% endmacro %}

{% macro ga4_parse_traffic_source(parameters) %}
  STRUCT(
    JSON_VALUE({{ parameters }}, '$.traffic_source.name') AS name,
    JSON_VALUE({{ parameters }}, '$.traffic_source.medium') AS medium,
    JSON_VALUE({{ parameters }}, '$.traffic_source.source') AS source,
    JSON_VALUE({{ parameters }}, '$.traffic_source.campaign') AS campaign,
    JSON_VALUE({{ parameters }}, '$.traffic_source.term') AS term,
    JSON_VALUE({{ parameters }}, '$.traffic_source.content') AS content,
    JSON_VALUE({{ parameters }}, '$.traffic_source.mcc_click_id') AS mcc_click_id,
    JSON_VALUE({{ parameters }}, '$.traffic_source.gclid') AS gclid,
    JSON_VALUE({{ parameters }}, '$.traffic_source.dclid') AS dclid,
    JSON_VALUE({{ parameters }}, '$.traffic_source.srsltid') AS srsltid
  )
{% endmacro %}

{% macro ga4_parse_device_category(device_type, device_brand, device_model) %}
  CASE
    WHEN {{ device_type }} = 'mobile' THEN 'mobile'
    WHEN {{ device_type }} = 'tablet' THEN 'tablet'
    WHEN {{ device_type }} = 'desktop' THEN 'desktop'
    WHEN {{ device_brand }} IN ('iPhone', 'iPad', 'iPod') THEN
      CASE WHEN {{ device_model }} LIKE '%iPad%' THEN 'tablet' ELSE 'mobile' END
    WHEN {{ device_brand }} IN ('Samsung', 'Huawei', 'Xiaomi', 'OnePlus', 'Google') THEN 'mobile'
    WHEN {{ device_brand }} IN ('Apple', 'Dell', 'HP', 'Lenovo', 'ASUS', 'Acer') THEN 'desktop'
    ELSE 'desktop'
  END
{% endmacro %}

{% macro ga4_calculate_engagement_time(parameters) %}
  CASE
    WHEN JSON_VALUE({{ parameters }}, '$.engagement_time_msec') IS NOT NULL
    THEN CAST(JSON_VALUE({{ parameters }}, '$.engagement_time_msec') AS INT64)
    ELSE 0
  END
{% endmacro %}
