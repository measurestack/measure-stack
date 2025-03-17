with first_client_id_events as ( -- first occurences of client ids
  select
    `hash`,
    client_id,
    min(timestamp) timestamp
  from {{ source('tracking','events')}}
  where client_id is not null
  group by 1,2
),
event_ids as ( -- assign each event an unique id
  select
    TO_BASE64(SHA256(CONCAT(`hash`, CAST(timestamp AS STRING), CAST(row_number() over (partition by `hash`,timestamp) AS STRING)))) AS event_id, -- create unique event id
    *,
  from {{ source('tracking','events')}}
),
block_ends as ( -- blocks of events with minimum 30min inactivity in between
  select
    `hash`,
    timestamp,
    TIMESTAMP_DIFF(LEAD(timestamp) OVER (PARTITION BY `hash` ORDER BY timestamp),timestamp, MILLISECOND) AS time_diff_ms, -- time difference to next hit of same hash
  from event_ids
  qualify time_diff_ms>1000*60*30 or time_diff_ms is null
),
events_block_ends as (
  select
    e.*,
    b.timestamp as block_end, -- add the blockend timestamp to each event
  from event_ids e
  left join block_ends b on e.`hash`=b.`hash` and e.timestamp<=b.timestamp 
  qualify (row_number() over (partition by e.event_id order by b.timestamp asc))=1
),
block_client_ids as ( -- determining client id for a block; only do that if the client id is unique for the block
  select 
    `hash`,
    block_end,
    count(distinct client_id) cnt,
    any_value(client_id) client_id,
  from events_block_ends
  where client_id is not null
  group by 1,2
  having cnt=1
),
block_client_ids_fix_cookiebot as ( -- find out whether in a block multiple client ids exist and these don't overlap, i.e. the first client id is last seen before the next client_id is first seen.
  select 
    `hash`,
    block_end,
    client_id,
    max_ts
  from (
    select 
      *,
      count(client_id) over (partition by `hash`, block_end) as cnt_client_ids, 
      row_number() over (partition by `hash`, block_end order by max_ts desc) as rn
    from (
      select 
        *,
        case when (lag(max_ts) over w is null or lag(max_ts) over w < min_ts) 
            and (lead(min_ts) over w is null or lead(min_ts) over w > max_ts) 
            then 1 else 0 end as non_overlapping    
      from (
        select 
          `hash`,
          block_end,
          client_id,
          min(timestamp) min_ts,
          max(timestamp) max_ts
        from events_block_ends
        where client_id is not null
        group by `hash`, block_end, client_id
      )
      window w as (partition by `hash`, block_end order by min_ts)
    ) 
    where non_overlapping = 1 -- filter out overlapping client_ids, but counting of client_ids per block happens on all client_ids
  ) 
  where cnt_client_ids = 2 and rn = 1 -- keep only entries with exactly 2 client ids per block and only keep the latest client_id
),
backfill_client_id as ( -- assigns client_id to previous events within block; note, will not assign client id to event without client id after the first occurence of client_id, but potentially to a next client id if there is a hash collision in block (multiple client ids per block)
  select
    e.* except(client_id),
    e.client_id tracked_client_id,
    coalesce(e.client_id,c.client_id) as client_id -- if event has no client_id find next client_id in block or take `hash`
  from events_block_ends e
  left join first_client_id_events c on e.`hash`=c.`hash` and e.timestamp<=c.timestamp and e.block_end>=c.timestamp
  qualify (row_number() over (partition by e.event_id order by c.timestamp asc))=1 -- check if that also keeps events where no future client id is present
),
backfill_client_id_pass_2 as ( -- fill remaining client ids with any client id from block in case there is only one client id for the block; in principle every future event should have a client_id once consent is there (saved in cookie), but as browsers do not send cookies on every request with same-site 'Lax' cookies we also have to backfill future events
  select 
    e.* except(client_id),
    coalesce(e.client_id,b.client_id,e.`hash`) client_id
  from backfill_client_id e
  left join block_client_ids b on e.`hash`=b.`hash` and e.block_end=b.block_end
),
backfill_client_id_pass_3_fix_cookiebot as( -- cookiebot deleted cookies when first going to app subdomain so client id will be reset. this was potentially fixed 8.10. by registering the measure cookies in cookiebot as "statistical"
  select 
    e.* except(client_id),
    coalesce(b.client_id,e.client_id) client_id, -- take block client_id if block is suitable else keep previos result
    case when b.client_id is not null then 1 else 0 end cookiebot_fix
  from backfill_client_id_pass_2 e 
  left join block_client_ids_fix_cookiebot b on e.`hash`=b.`hash` and e.block_end=b.block_end
)
select * from backfill_client_id_pass_3_fix_cookiebot    