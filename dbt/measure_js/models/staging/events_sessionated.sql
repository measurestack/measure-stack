{% set utm_rules = var('utm_rules', []) %}


with event_ids as ( -- assign each event an unique id; extract external source data from url and referrer
  select
    TO_BASE64(SHA256(CONCAT(`hash`, CAST(timestamp AS STRING), CAST(row_number() over (partition by `hash`,timestamp) AS STRING)))) AS event_id, -- create unique event id
    * replace (STRUCT(
      device.type as type,
      device.family as family,
      device.brand as brand,
      device.model as model,
      device.browser as browser,
      device.browser_version as browser_version,
      device.os as os,
      device.os_version as os_version,
      ifnull(device.is_bot,FALSE) or REGEXP_CONTAINS(user_agent,"{{ var('bot_regex') }}") as is_bot,
      device.is_bot as is_bot_old
    ) AS device),
    event_name='pageview' or ({{ var("request_pageviews") }} and event_name='text/html' and REGEXP_CONTAINS(url,r'{{ var("request_pageviews_regex") }}')) is_pageview, -- pageviews are explicit page view events or backend text/html repsonses with .html in filename in case of backend tracking
    COALESCE(referrer is not null 
      and REGEXP_EXTRACT(referrer, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)') != REGEXP_EXTRACT(url, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)') 
      and not REGEXP_CONTAINS(referrer, r'({{ var("internal_referrers") }})'),FALSE) AS is_ext_referrer, -- bool has external referrer, exclude special referrers
    REGEXP_EXTRACT(referrer, r'https?://([^/?#]+)') AS referring_domain,
    CASE
      WHEN REGEXP_CONTAINS(url, r'({{ var("clid_parameters") }})=([^&#]+)') THEN
        STRUCT(
          REGEXP_EXTRACT(url, r'({{ var("clid_parameters") }})=') AS parameter,
          REGEXP_EXTRACT(url, r'(?:{{ var("clid_parameters") }})=([^&#]+)') AS value
        )
      ELSE NULL
    END AS clid, -- extract known marketing platform click identifier; note: will only get first of these parameters
    CASE
      WHEN REGEXP_CONTAINS(url, r'(utm_source|utm_medium|utm_campaign|utm_content|utm_term|utm_id)=([^&#]+)') THEN
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
    REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(url,r'{{ var("page_location_cleanup") }}',''),r'(utm_[a-z]+|{{ var("clid_parameters") }})=[^&#]*&?',''),r'(\?$|\?&)',''),r'\?#','#') page_location, -- remove source params from url, retain other params
    REGEXP_EXTRACT(url, r'https?://([^/?#]+)') AS hostname
  from {{ source('tracking','events')}}
),
-- identify blocks of activity; == events of same hash with less then 30 min pause
block_starts as ( -- blocks of events with minimum 30min inactivity in between
  select
    `hash`,
    timestamp,
    TIMESTAMP_DIFF(timestamp,LAG(timestamp) OVER (PARTITION BY `hash` ORDER BY timestamp), MILLISECOND) AS time_diff_ms, -- time difference to next hit of same hash
  from {{ source('tracking','events')}}
  qualify time_diff_ms>1000*60*30 or time_diff_ms is null
),
events_block_starts as (
  select
    e.*,
    b.timestamp as block_start, -- add the blockend timestamp to each event

  from event_ids e
  left join block_starts b on e.`hash`=b.`hash` and e.timestamp>=b.timestamp 
  qualify (row_number() over (partition by e.event_id order by b.timestamp desc))=1
),
-- identify event where a client_id was first set
first_client_id_events as ( -- first occurences of client ids
  select
    `hash`,
    block_start,
    client_id,
    min(timestamp) timestamp
  from events_block_starts
  where client_id is not null
  group by 1,2,3
),
-- now make sure all events in a block get a client_id in case there is a client id set later in a block or some events in between have and client_id (the latter should be unlikely though)
merged_client_ids as (
  select
    e.* replace(case when e.client_id is not null and e.timestamp >= '2023-10-08' then e.client_id 
                     when c.client_id is not null then c.client_id else e.`hash` end as client_id), --assign first client id in that block to all events in that block (if exists, else null); before 10-08 replace existing clients ids in the block to fix cookiebot error; if no client_ids are in block use hash
    c.client_id is null and e.client_id is null AS no_client_id -- the client id is a hash, no consent to store cookies
  from events_block_starts e
  left join first_client_id_events c on e.`hash`=c.`hash` and e.block_start=c.block_start
  qualify case
    when e.timestamp < '2023-10-08' and count(*) over(partition by e.event_id) = 2 -- specical case for cookiebot error where we assigned a new client id when entering app subdomain. cookiebot deleted cookie in this case
      then (row_number() over (partition by e.event_id order by c.timestamp asc)) = 2
    else (row_number() over (partition by e.event_id order by c.timestamp asc)) = 1 -- this will select the row with the first client id per block
  end

),
-- identify all events that indicate an external source (e.g. utm params, refferrer, etc.)
-- if the same parameters repeat within a block only consider the first as external source event
ext_sources as (
  select 
    * replace(
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
    row_number() over (partition by client_id,block_start order by timestamp asc) = 1 as first_source -- first source entry in a block
  from (
    select 
      event_id,
      timestamp,
      client_id,
      block_start,
      is_pageview and row_number() over (partition by client_id,block_start,is_pageview order by timestamp) = 1 AS is_first_pageview,
      is_ext_referrer,
      page_location landing_page,
      referrer,
      referring_domain,
      clid,
      utm,
      not is_ext_referrer and clid is null and utm is null AS is_direct, -- first page view without any external traffic signals is direct session
      CONCAT(
        ifnull(referrer,""), 
        TO_JSON_STRING(clid), -- Note: TO_JSON_STRING(NULL) is "null"
        TO_JSON_STRING(utm)
      ) AS combined_source
    from merged_client_ids
    qualify is_pageview and (is_first_pageview or is_ext_referrer or clid is not null or utm is not null) -- external sources can only be identified on pageviews
  )
  qualify row_number() over (partition by client_id, block_start, combined_source order by timestamp asc) = 1 -- only keep the first occurence of a ext source in a block
),
-- sessionate the events by assuming external sources start a new session
-- take source params from source events
sessionated as (
  select 
    e.* except (utm, clid, block_start),
    TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start))) as block_id, 
    CASE 
      WHEN s.event_id is not null THEN TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start,s.event_id)))
      ELSE TO_BASE64(SHA256(CONCAT(e.client_id, e.block_start))) -- if no external sources were found, block is already session
    END as session_id, 
    s.referrer source_referrer,
    s.landing_page, --FIXME if no ext source session is available then this should still have a landing page
    COALESCE(s.utm, STRUCT(
          'direct' AS source, 
          'none' AS medium, 
          NULL as campaign, 
          NULL as content, 
          NULL as term, 
          NULL as id
        )) utm,
    s.clid,
    s.event_id is null AS is_stub_session, -- session has no pageviews (received some disconnected evens/requests)
    s.event_id is not null and not s.is_direct AS is_ext_session, -- indicates sessions that are external traffic (so not direct traffic)
    e.event_id=s.event_id AS is_source_event -- marks the event that holds the relevant traffic source information
  from merged_client_ids e
  left join ext_sources s on e.client_id=s.client_id and e.block_start=s.block_start and (e.timestamp>=s.timestamp or s.first_source) -- join all sources before and at current event; always join first source to cover "pre" events
  qualify row_number() over (partition by e.event_id order by s.timestamp desc) = 1
)


select * from sessionated