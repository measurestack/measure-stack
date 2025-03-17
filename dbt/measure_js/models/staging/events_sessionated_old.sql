with sources as ( -- extract information from referrer and url
SELECT 
  *,
  event_name='pageview' or (event_name='text/html' and REGEXP_CONTAINS(url,r'(?:https?://[^/]+$|/$|\.html$|/[^/\.]+$)')) pageview, -- pageviews are explicit page view events or backend text/html repsonses with .html in filename in case of backend tracking
  referrer is not null 
    and REGEXP_EXTRACT(referrer, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)') != REGEXP_EXTRACT(url, r'^(?:\w+://)?(?:[^:/?]+\.)*([^:/?]+\.[^:/?]+)') 
    and not REGEXP_CONTAINS(referrer, r'({{ var("internal_referrers") }})') AS ext_referrer, -- bool has external referrer, exclude special referrers
  CASE
    WHEN REGEXP_CONTAINS(url, r'({{ var("clid_parameters") }})=([^&]+)') THEN
      STRUCT(
        REGEXP_EXTRACT(url, r'({{ var("clid_parameters") }})=') AS parameter,
        REGEXP_EXTRACT(url, r'(?:{{ var("clid_parameters") }})=([^&]+)') AS value
      )
    ELSE NULL
  END AS clid, -- extract known marketing platform click identifier
  CASE
    WHEN REGEXP_CONTAINS(url, r'(utm_source|utm_medium|utm_campaign|utm_content|utm_term|utm_id)=([^&]+)') THEN
      STRUCT(
        REGEXP_EXTRACT(url, r'utm_source=([^&]+)') AS utm_source,
        REGEXP_EXTRACT(url, r'utm_medium=([^&]+)') AS utm_medium,
        REGEXP_EXTRACT(url, r'utm_campaign=([^&]+)') AS utm_campaign,
        REGEXP_EXTRACT(url, r'utm_content=([^&]+)') AS utm_content,
        REGEXP_EXTRACT(url, r'utm_term=([^&]+)') AS utm_term,
        REGEXP_EXTRACT(url, r'utm_id=([^&]+)') AS utm_id
      )
    ELSE NULL
  END AS utm_parameters, -- extract utm parameters
  REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(url,r'(utm_[a-z]+|{{ var("clid_parameters") }})=[^&#]+&?',''),r'(\?$|\?&)',''),r'\?#','#') page_location, -- remove source params from url, retain other params
  TIMESTAMP_DIFF(timestamp, LAG(timestamp) OVER w, MILLISECOND) AS time_diff_ms, -- time difference to previous hit of same client_id
  LAG(user_id) over w is not null and (user_id is null or user_id != LAG(user_id) over w) as user_id_switch
FROM {{ ref('event_blocks')}}
WINDOW w AS (PARTITION BY client_id ORDER BY timestamp)
),

flagged as ( -- flag potential new session starts
select *,
case 
  when clid is not null then true
  when utm_parameters is not null then true -- has utm parameters
  when ext_referrer then true -- external referrers 
  when time_diff_ms>1000*60*30 then true -- inactivity 30min
  when time_diff_ms is null then true -- first hit of client_id
  when user_id_switch is true then true -- user_id switched; we want user_id to be a session property so we need to start a new session if someone changes user_id; note: 
  else false
end potential_session, -- flag potential new sessions; Note, these may still be duplicated if the utm parameters etc are repeated in following events 
case 
  when clid is not null then true
  when utm_parameters is not null then true
  when ext_referrer then true
  else false 
end ext_session, -- flag only ext session condition
case 
  when time_diff_ms>1000*60*30 then true -- inactivity 30min
  when time_diff_ms is null then true -- first hit of client_id
  else false 
end time_session -- flag only time condition
from sources
), 

dedup as ( -- flagging rows that have the same clid, utm or referrer as previous rows as duplicated; note we are only looking at rows which indicate potential new sessions, so there could be rows in between that do nt have any session relevant data
  select *,
    clid IS NOT NULL AND clid = LAG(clid) OVER w AS same_clid,
    utm_parameters IS NOT NULL AND utm_parameters = LAG(utm_parameters) OVER w AS same_utm,
    ext_referrer IS TRUE AND referrer = LAG(referrer) OVER w AS same_referrer,
    pageview IS TRUE AND LAG(time_session) OVER w_page_time IS TRUE AND LAG(pageview) OVER w_page_time IS NOT TRUE AS first_pageview -- also flag the first pageview event after a time_session event which is not a pageview
  from flagged
  WINDOW 
    w AS (PARTITION BY client_id, potential_session ORDER BY timestamp),
    w_page_time AS (PARTITION BY client_id, pageview OR time_session ORDER BY timestamp)
), 

newsession as ( -- only flag non duplicated as new session rows
  select *,
  (potential_session and same_clid is not true and same_utm is not true  and same_referrer is not true) or first_pageview as new_session -- identify new session events
  from dedup
), 

pre_events as ( -- mark first events in "virtual" session that actually belong to the session right afterward which are started by ext_session conditions
  select * ,
    new_session is true and ext_session is not true and user_id_switch is not true and pageview is not true and (lead(time_session) over w) is not true and (lead(event_id) over w) is not null as pre_event, -- identify events that fire before the pageview that contains the source params; next session must not be a time based session and must exist
    lead(event_id) over w next_session_event_id
  from newsession
  WINDOW w AS (partition by client_id, new_session order by timestamp)
),

sessions_assigned as ( -- assign session id to all events
  select 
    a.*,
    b.event_id new_session_event_id, -- this is actually the "straight-forward" session_id for the event but will assign the id of a pre_session in some cases -> see actual session_id further below
    b.pre_event as session_pre_event,
    case 
      when b.pre_event is true then b.next_session_event_id -- this makes sure that all events from a pre_session are assigned the id from the next real session
      else b.event_id
    end session_id, -- session id is equal to the event_id of the session defining even (see above to find out what that means but it is usually the first pageview of the session)
    row_number() over (partition by a.event_id order by b.timestamp desc) rn
  from pre_events a
  inner join (
    select *
    from pre_events
    where new_session = true
  ) b on a.client_id=b.client_id and a.timestamp>=b.timestamp
  qualify rn=1 -- only latest new_session event before or on current event
)


select *
from sessions_assigned
order by timestamp desc -- remove later for performance