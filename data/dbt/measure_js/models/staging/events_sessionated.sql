{% set utm_rules = var('utm_rules', []) %}

/* -----------------------------------------------------------------------------
This staging model transforms raw event data, sent by the Measure-JS SDK into
'sessions'. Herein, several key steps are performed to:
  1. Pre-processes raw tracking data by generating unique IDs, cleaning URL data,
    and extracting device and marketing parameters
  2. Identify blocks of user activity based on inactivity gaps.
  3. Harmonize client IDs across events within the same activity block
  4. Determine external source of traffic (using UTM, referrer, and click identifiers)
    with customizable rules.
  5. Sessionize events by grouping them based on activity blocks and external source signals,
    thereby providing a robust dataset for downstream analysis of user sessions and behavior.
  */ -----------------------------------------------------------------------------

WITH event_ids AS
  ( -- assign each event an unique id; extract external source data from url and referrer
    SELECT
      TO_BASE64
        (
          SHA256(CONCAT(`hash`, CAST(timestamp AS STRING), CAST(ROW_NUMBER() OVER (PARTITION BY `hash`,timestamp) AS STRING)))
        ) AS event_id, -- create unique event id

      * REPLACE(
                STRUCT( -- flatten the nested device information
                    device.type AS type,
                    device.brand AS brand,
                    device.model AS model,
                    device.browser AS browser,
                    device.browser_version AS browser_version,
                    device.os AS os,
                    device.os_version AS os_version,
                    ifnull(device.is_bot,FALSE) OR REGEXP_CONTAINS(user_agent,"{{ var('bot_regex') }}") as is_bot,
                    device.is_bot AS is_bot_old
      ) AS device
                ),
      event_name='pageview' OR ({{ var("request_pageviews") }} AND event_name='text/html' AND REGEXP_CONTAINS(url,r'{{ var("request_pageviews_regex") }}')
      ) AS is_pageview, -- pageviews are explicit page view events or backend text/html repsonses with .html in filename in case of backend tracking

      COALESCE(referrer IS NOT NULL
                    AND REGEXP_EXTRACT(referrer, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)') != REGEXP_EXTRACT(url, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)')
                    AND NOT REGEXP_CONTAINS(referrer, r'({{ var("internal_referrers") }})'),FALSE)
      AS is_ext_referrer, -- bool has external referrer, exclude special referrers

      REGEXP_EXTRACT(referrer, r'https?://([^/?#]+)'
      ) AS referring_domain,

      CASE
        WHEN REGEXP_CONTAINS(url, r'({{ var("clid_parameters") }})=([^&#]+)') THEN
          STRUCT(
            REGEXP_EXTRACT(url, r'({{ var("clid_parameters") }})=') AS parameter,
            REGEXP_EXTRACT(url, r'(?:{{ var("clid_parameters") }})=([^&#]+)') AS value
                )
        ELSE NULL
      END AS clid, -- extract known marketing platform click identifier; note: will only get first of these parameters

      CASE
        WHEN REGEXP_CONTAINS(url, r'(utm_source|utm_medium|utm_campaign|utm_content|utm_term|utm_id)=([^&#]+)')
        THEN
          STRUCT(
            REGEXP_EXTRACT(url, r'utm_source=([^&#]+)') AS source,
            REGEXP_EXTRACT(url, r'utm_medium=([^&#]+)') AS medium,
            REGEXP_EXTRACT(url, r'utm_campaign=([^&#]+)') AS campaign,
            REGEXP_EXTRACT(url, r'utm_content=([^&#]+)') AS content,
            REGEXP_EXTRACT(url, r'utm_term=([^&#]+)') AS term,
            REGEXP_EXTRACT(url, r'utm_id=([^&#]+)') AS id
          )
        ELSE NULL
      END AS utm, -- extract utm parameters

      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(url,r'{{ var("page_location_cleanup") }}',''
            ),r'(utm_[a-z]+|{{ var("clid_parameters") }})=[^&#]*&?',''
            ),r'(\?$|\?&)',''),r'\?#','#'
      ) AS page_location, -- remove source params from url, retain other params

      REGEXP_EXTRACT(url, r'https?://([^/?#]+)') AS hostname,


      {{ ga4_parse_purchase('parameters') }} AS ecommerce,
      {{ ga4_parse_view_item('parameters') }} AS view_item_data,
      {{ ga4_parse_add_to_cart('parameters') }} AS add_to_cart_data,
      {{ ga4_parse_begin_checkout('parameters') }} AS begin_checkout_data,
      {{ ga4_parse_sign_up('parameters') }} AS sign_up_data,
      {{ ga4_parse_login('parameters') }} AS login_data,
      {{ ga4_parse_generate_lead('parameters') }} AS generate_lead_data,
      {{ ga4_parse_page_view('parameters') }} AS page_view_data,
      {{ ga4_parse_scroll('parameters') }} AS scroll_data,
      {{ ga4_parse_video_events('parameters') }} AS video_data,
      {{ ga4_parse_items('parameters', 'event_name') }} AS item

    FROM {{ source('mjs','events')}}
  ),

-- Identify blocks of activity; == events of same hash with less then 30 min pause
block_starts AS
  ( -- blocks of events with minimum 30min inactivity in between
    SELECT
      `hash`,
      timestamp,
      TIMESTAMP_DIFF
        (
        timestamp,LAG(timestamp) OVER (PARTITION BY `hash` ORDER BY timestamp), MILLISECOND
        )
      AS time_diff_ms, -- time difference to next hit of same hash
    FROM {{ source('mjs','events')}}

    QUALIFY time_diff_ms>1000*60*30 OR time_diff_ms IS NULL
  ),

-- Identify, when certain event blocks start
events_block_starts AS
  (
    SELECT
      e.*,
      b.timestamp AS block_start, -- add the blockend timestamp to each event
    FROM event_ids e
    LEFT JOIN block_starts b ON e.`hash`=b.`hash` AND e.timestamp>=b.timestamp
    QUALIFY (ROW_NUMBER() OVER (PARTITION BY e.event_id ORDER BY b.timestamp DESC))=1
  ),

-- identify event where a client_id was first set
first_client_id_events AS
  ( -- first occurences of client ids
    SELECT
      `hash`,
      block_start,
      client_id,
      min(timestamp) timestamp
    FROM events_block_starts
    WHERE client_id IS NOT NULL
    GROUP BY 1,2,3
  ),

-- now make sure all events in a block get a client_id in case there is a client id set later in a block or some events in between have a client_id (the latter should be unlikely though)
merged_client_ids AS
  (
    SELECT
      e.* replace(
          CASE
            WHEN e.client_id IS NOT NULL
            AND e.timestamp >= '2023-10-08'
            THEN e.client_id
            WHEN c.client_id IS NOT NULL
            THEN c.client_id ELSE e.`hash`
          END
      AS client_id
      ), --assign first client id in that block to all events in that block (if exists, else null); before 10-08 replace existing clients ids in the block to fix cookiebot error; if no client_ids are in block use hash

      c.client_id IS NULL AND e.client_id IS NULL
      AS no_client_id -- the client id is a hash, no consent to store cookies

    FROM events_block_starts e
    LEFT JOIN first_client_id_events c ON e.`hash`=c.`hash` AND e.block_start=c.block_start
    QUALIFY CASE
      WHEN e.timestamp < '2023-10-08' AND COUNT(*) OVER(PARTITION BY e.event_id) = 2 -- specical CASE for cookiebot error where we assigned a new client id WHEN entering app subdomain. cookiebot deleted cookie in this CASE
        then (ROW_NUMBER() OVER (PARTITION BY e.event_id ORDER BY c.timestamp ASC)) = 2
      else (ROW_NUMBER() OVER (PARTITION BY e.event_id ORDER BY c.timestamp ASC)) = 1 -- this will SELECT the row with the first client id per block
    end

  ),

-- identify all events that indicate an external source (e.g. utm params, refferrer, etc.)
-- if the same parameters repeat within a block only consider the first as external source event
ext_sources AS
  (
    SELECT
      * REPLACE(
        CASE
        {% for rule in utm_rules %}
          WHEN {{ rule.condition }} THEN STRUCT(
            COALESCE(utm.source, {{ rule.source | default("'(not set)'") }}) AS source,
            COALESCE(utm.medium, {{ rule.medium | default("'(not set)'") }}) AS medium,
            utm.campaign, utm.content, utm.term, utm.id
          )
        {% endfor %}
        ELSE STRUCT(
            COALESCE(utm.source, 'direct') AS source,
            COALESCE(utm.medium, 'none') AS medium,
            utm.campaign, utm.content, utm.term, utm.id
          )
        END AS utm -- apply utm rules
      ),
      ROW_NUMBER() OVER (PARTITION BY client_id,block_start ORDER BY timestamp ASC) = 1 as first_source -- first source entry in a block
    FROM (
      SELECT
        event_id,
        timestamp,
        client_id,
        block_start,
        is_pageview AND ROW_NUMBER() OVER (PARTITION BY client_id,block_start,is_pageview ORDER BY timestamp) = 1 AS is_first_pageview,
        is_ext_referrer,
        page_location landing_page,
        referrer,
        referring_domain,
        clid,
        utm,
        NOT is_ext_referrer AND clid IS NULL AND utm IS NULL AS is_direct, -- first page view without any external traffic signals is direct session
        CONCAT(
          ifnull(referrer,""),
          TO_JSON_STRING(clid), -- Note: TO_JSON_STRING(NULL) is "null"
          TO_JSON_STRING(utm)
        ) AS combined_source
      FROM merged_client_ids
      QUALIFY is_pageview AND (is_first_pageview OR is_ext_referrer OR clid IS NOT NULL or utm IS NOT NULL) -- external sources can only be identified on pageviews
    )
    QUALIFY ROW_NUMBER() OVER (PARTITION BY client_id, block_start, combined_source ORDER BY timestamp ASC) = 1 -- only keep the first occurence of a ext source in a block
  ),

-- sessionate the events by assuming external sources start a new session
-- take source params from source events
sessionated AS
  (
    SELECT
      e.* EXCEPT (utm, clid, block_start),
      TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start))) AS block_id,
      CASE
        WHEN s.event_id IS NOT NULL THEN TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start,s.event_id)))
        ELSE TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start))) -- if no external sources were found, block is already session
      END AS session_id,
      s.referrer source_referrer,
      s.landing_page, --FIXME if no ext source session is available then this should still have a landing page
      COALESCE(s.utm, STRUCT(
            'direct' AS source,
            'none' AS medium,
            NULL AS campaign,
            NULL AS content,
            NULL AS term,
            NULL AS id
          )) utm,
      s.clid,
      s.event_id IS NULL AS is_stub_session, -- session has no pageviews (received some disconnected evens/requests)
      s.event_id IS NOT NULL AND NOT s.is_direct AS is_ext_session, -- indicates sessions that are external traffic (so not direct traffic)
      e.event_id=s.event_id AS is_source_event -- marks the event that holds the relevant traffic source information
    FROM merged_client_ids e
    LEFT JOIN ext_sources s ON e.client_id=s.client_id AND e.block_start=s.block_start AND (e.timestamp>=s.timestamp OR s.first_source) -- join all sources before and at current event; always join first source to cOVER "pre" events
    QUALIFY ROW_NUMBER() OVER (PARTITION BY e.event_id ORDER BY s.timestamp DESC) = 1
  )

SELECT * from sessionated
