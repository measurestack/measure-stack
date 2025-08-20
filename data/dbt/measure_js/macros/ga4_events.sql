{#
  GA4 Style Event Parsing Macros

  This macro file contains reusable functions for parsing GA4 recommended events
  from the parameters JSON field in your events table.

  Usage:
    {{ ga4_parse_purchase(parameters) }}
    {{ ga4_parse_view_item(parameters) }}
    {{ ga4_parse_add_to_cart(parameters) }}
#}

{% macro ga4_parse_purchase(parameters) %}
  CASE WHEN event_name = 'purchase' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.currency')                                AS currency,
      CAST(JSON_VALUE({{ parameters }}, '$.value')                              AS FLOAT64) AS value,
      JSON_VALUE({{ parameters }}, '$.transaction_id')                          AS transaction_id,
      JSON_VALUE({{ parameters }}, '$.coupon')                                  AS coupon,
      CAST(JSON_VALUE({{ parameters }}, '$.shipping')                           AS FLOAT64)  AS shipping,
      CAST(JSON_VALUE({{ parameters }}, '$.tax')                                AS FLOAT64) AS tax,
      JSON_VALUE({{ parameters }}, '$.affiliation')                             AS affiliation,
      CAST(JSON_VALUE({{ parameters }}, '$.shipping_tier')                      AS STRING) AS shipping_tier,
      JSON_VALUE({{ parameters }}, '$.payment_type')                            AS payment_type
    )
  ELSE NULL
  END
{% endmacro %}

{% macro ga4_parse_view_item(parameters) %}
  CASE WHEN event_name = 'view_item' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.currency') AS currency,
      CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64) AS value,
      JSON_VALUE({{ parameters }}, '$.item_id') AS item_id,
      JSON_VALUE({{ parameters }}, '$.item_name') AS item_name,
      JSON_VALUE({{ parameters }}, '$.item_brand') AS item_brand,
      JSON_VALUE({{ parameters }}, '$.item_category') AS item_category,
      JSON_VALUE({{ parameters }}, '$.item_category2') AS item_category2,
      JSON_VALUE({{ parameters }}, '$.item_category3') AS item_category3,
      JSON_VALUE({{ parameters }}, '$.item_category4') AS item_category4,
      JSON_VALUE({{ parameters }}, '$.item_category5') AS item_category5,
      CAST(JSON_VALUE({{ parameters }}, '$.price') AS FLOAT64) AS price,
      CAST(JSON_VALUE({{ parameters }}, '$.quantity') AS INT64) AS quantity,
      JSON_VALUE({{ parameters }}, '$.item_variant') AS item_variant,
      JSON_VALUE({{ parameters }}, '$.item_list_id') AS item_list_id,
      JSON_VALUE({{ parameters }}, '$.item_list_name') AS item_list_name,
      CAST(JSON_VALUE({{ parameters }}, '$.item_list_index') AS INT64) AS item_list_index
    )
  ELSE NULL
  END
{% endmacro %}

{% macro ga4_parse_add_to_cart(parameters) %}
  CASE WHEN event_name = 'add_to_cart' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.currency') AS currency,
      CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64) AS value,
      JSON_VALUE({{ parameters }}, '$.item_id') AS item_id,
      JSON_VALUE({{ parameters }}, '$.item_name') AS item_name,
      JSON_VALUE({{ parameters }}, '$.item_brand') AS item_brand,
      JSON_VALUE({{ parameters }}, '$.item_category') AS item_category,
      JSON_VALUE({{ parameters }}, '$.item_category2') AS item_category2,
      JSON_VALUE({{ parameters }}, '$.item_category3') AS item_category3,
      JSON_VALUE({{ parameters }}, '$.item_category4') AS item_category4,
      JSON_VALUE({{ parameters }}, '$.item_category5') AS item_category5,
      CAST(JSON_VALUE({{ parameters }}, '$.price') AS FLOAT64) AS price,
      CAST(JSON_VALUE({{ parameters }}, '$.quantity') AS INT64) AS quantity,
      JSON_VALUE({{ parameters }}, '$.item_variant') AS item_variant,
      JSON_VALUE({{ parameters }}, '$.item_list_id') AS item_list_id,
      JSON_VALUE({{ parameters }}, '$.item_list_name') AS item_list_name,
      CAST(JSON_VALUE({{ parameters }}, '$.item_list_index') AS INT64) AS item_list_index
    )
  ELSE NULL
  END
{% endmacro %}

{% macro ga4_parse_begin_checkout(parameters) %}
  CASE WHEN event_name = 'begin_checkout' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.currency') AS currency,
      CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64) AS value,
      JSON_VALUE({{ parameters }}, '$.coupon') AS coupon,
      CAST(JSON_VALUE({{ parameters }}, '$.shipping_tier') AS STRING) AS shipping_tier,
      JSON_VALUE({{ parameters }}, '$.payment_type') AS payment_type
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_sign_up(parameters) %}
  CASE WHEN event_name = 'sign_up' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.method') AS method
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_login(parameters) %}
  CASE WHEN event_name = 'login' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.method') AS method
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_generate_lead(parameters) %}
  CASE WHEN event_name = 'generate_lead' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.currency') AS currency,
      CAST(JSON_VALUE({{ parameters }}, '$.value') AS FLOAT64) AS value
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_page_view(parameters) %}
  CASE WHEN event_name = 'page_view' THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.page_title') AS page_title,
      JSON_VALUE({{ parameters }}, '$.page_location') AS page_location,
      JSON_VALUE({{ parameters }}, '$.page_referrer') AS page_referrer
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_scroll(parameters) %}
  CASE WHEN event_name = 'scroll' THEN
    STRUCT(
      CAST(JSON_VALUE({{ parameters }}, '$.percent_scrolled') AS FLOAT64) AS percent_scrolled
    )
  ELSE NULL END
{% endmacro %}

{% macro ga4_parse_video_events(parameters) %}
  CASE WHEN event_name IN ('video_start', 'video_progress', 'video_complete') THEN
    STRUCT(
      JSON_VALUE({{ parameters }}, '$.video_title') AS video_title,
      JSON_VALUE({{ parameters }}, '$.video_duration') AS video_duration,
      JSON_VALUE({{ parameters }}, '$.video_percent') AS video_percent,
      JSON_VALUE({{ parameters }}, '$.video_url') AS video_url,
      JSON_VALUE({{ parameters }}, '$.video_provider') AS video_provider
    )
  ELSE NULL END
{% endmacro %}

{# Macro to parse items array for ecommerce events #}
{% macro ga4_parse_items(parameters, event_name) %}
  CASE WHEN {{ event_name }} IN ('purchase', 'view_item_list', 'view_cart') THEN
    ARRAY(
      SELECT
        STRUCT(
          JSON_VALUE(item, '$.item_id') AS item_id,
          JSON_VALUE(item, '$.item_name') AS item_name,
          JSON_VALUE(item, '$.item_brand') AS item_brand,
          JSON_VALUE(item, '$.item_variant') AS item_variant,
          JSON_VALUE(item, '$.item_category') AS item_category,
          JSON_VALUE(item, '$.item_category2') AS item_category2,
          JSON_VALUE(item, '$.item_category3') AS item_category3,
          JSON_VALUE(item, '$.item_category4') AS item_category4,
          JSON_VALUE(item, '$.item_category5') AS item_category5,
          CAST(JSON_VALUE(item, '$.price') AS FLOAT64) AS price,
          CAST(JSON_VALUE(item, '$.quantity') AS INT64) AS quantity,
          CAST(JSON_VALUE(item, '$.item_revenue') AS FLOAT64) AS item_revenue,
          CAST(JSON_VALUE(item, '$.item_refund') AS FLOAT64) AS item_refund,
          JSON_VALUE(item, '$.coupon') AS coupon,
          JSON_VALUE(item, '$.affiliation') AS affiliation,
          JSON_VALUE(item, '$.location_id') AS location_id,
          JSON_VALUE(item, '$.item_list_id') AS item_list_id,
          JSON_VALUE(item, '$.item_list_name') AS item_list_name,
          CAST(JSON_VALUE(item, '$.item_list_index') AS INT64) AS item_list_index,
          JSON_VALUE(item, '$.promotion_id') AS promotion_id,
          JSON_VALUE(item, '$.promotion_name') AS promotion_name,
          JSON_VALUE(item, '$.creative_name') AS creative_name,
          JSON_VALUE(item, '$.creative_slot') AS creative_slot
        )
      FROM UNNEST(JSON_QUERY_ARRAY({{ parameters }}, '$.items')) AS item
    )
  ELSE [] END
{% endmacro %}
