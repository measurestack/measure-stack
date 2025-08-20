WITH first_client_id_events AS
  ( -- first occurences of client ids
    SELECT
      `hash`,
      client_id,
      MIN(timestamp) timestamp
    FROM {{ source('mjs','events')}}
    WHERE client_id IS NOT NULL
    GROUP BY 1,2
  ),


event_ids AS
  ( -- assign each event an unique id
    SELECT
      TO_BASE64(SHA256(CONCAT(`hash`, CAST(timestamp AS STRING), CAST(row_number() OVER (PARTITION BY `hash`,timestamp) AS STRING)))) AS event_id, -- create unique event id
      *,
    FROM {{ source('mjs','events')}}
  ),


block_ends AS
  ( -- blocks of events with minimum 30min inactivity in between
    SELECT
      `hash`,
      timestamp,
      TIMESTAMP_DIFF(LEAD(timestamp) OVER (PARTITION BY `hash` ORDER BY timestamp),timestamp, MILLISECOND) AS time_diff_ms, -- time difference to next hit of same hash
    FROM event_ids
    qualify time_diff_ms>1000*60*30 or time_diff_ms IS NULL
  ),


events_block_ends AS
  (
    SELECT
      e.*,
      b.timestamp AS block_end, -- add the blockend timestamp to each event
    FROM event_ids e
    LEFT JOIN block_ends b ON e.`hash`=b.`hash` AND e.timestamp<=b.timestamp
    qualify (row_number() OVER (PARTITION BY e.event_id ORDER BY b.timestamp ASC))=1
  ),


block_client_ids AS
  ( -- determining client id for a block; only do that if the client id is unique for the block
    SELECT
      `hash`,
      block_end,
      count(DISTINCT client_id) cnt,
      any_value(client_id) client_id,
    FROM events_block_ends
    where client_id IS NOT NULL
    GROUP BY 1,2
    HAVING cnt=1
  ),

block_client_ids_fix_cookiebot AS
  ( -- find out whether in a block multiple client ids exist AND these don't overlap, i.e. the first client id is last seen before the next client_id is first seen.
    SELECT
      `hash`,
      block_end,
      client_id,
      max_ts
    FROM (
      SELECT
        *,
        count(client_id) OVER (PARTITION BY `hash`, block_end) AS cnt_client_ids,
        row_number() OVER (PARTITION BY `hash`, block_end ORDER BY max_ts DESC) AS rn
      FROM (
        SELECT
          *,
          CASE WHEN (lag(max_ts) OVER w IS NULL OR lag(max_ts) OVER w < min_ts)
              AND (lead(min_ts) OVER w IS NULL OR lead(min_ts) OVER w > max_ts)
              THEN 1 ELSE 0 END AS non_overlapping
        FROM (
          SELECT
            `hash`,
            block_end,
            client_id,
            min(timestamp) min_ts,
            max(timestamp) max_ts
          FROM events_block_ends
          where client_id IS NOT NULL
          GROUP BY `hash`, block_end, client_id
        )
        window w AS (PARTITION BY `hash`, block_end ORDER BY min_ts)
      )
      where non_overlapping = 1 -- filter out overlapping client_ids, but counting of client_ids per block happens ON all client_ids
    )
    where cnt_client_ids = 2 AND rn = 1 -- keep only entries with exactly 2 client ids per block AND only keep the latest client_id
  ),


backfill_client_id AS
  ( -- assigns client_id to previous events within block; note, will not assign client id to event without client id after the first occurence of client_id, but potentially to a next client id if there is a hash collision in block (multiple client ids per block)
    SELECT
      e.* except(client_id),
      e.client_id tracked_client_id,
      coalesce(e.client_id,c.client_id) AS client_id -- if event has no client_id find next client_id in block or take `hash`
    FROM events_block_ends e
    LEFT JOIN first_client_id_events c ON e.`hash`=c.`hash` AND e.timestamp<=c.timestamp AND e.block_end>=c.timestamp
    qualify (row_number() over (PARTITION BY e.event_id ORDER BY c.timestamp ASC))=1 -- check if that also keeps events where no future client id is present
  ),


backfill_client_id_pass_2 AS
  ( -- fill remaining client ids with any client id FROM block in case there is only one client id for the block; in principle every future event should have a client_id once consent is there (saved in cookie), but AS browsers do not send cookies ON every request with same-site 'Lax' cookies we also have to backfill future events
    SELECT
      e.* except(client_id),
      coalesce(e.client_id,b.client_id,e.`hash`) client_id
    FROM backfill_client_id e
    LEFT JOIN block_client_ids b ON e.`hash`=b.`hash` AND e.block_end=b.block_end
  ),

backfill_client_id_pass_3_fix_cookiebot AS
  ( -- cookiebot deleted cookies when first going to app subdomain so client id will be reset. this was potentially fixed 8.10. by registering the measure cookies in cookiebot AS "statistical"
    SELECT
      e.* except(client_id),
      coalesce(b.client_id,e.client_id) client_id, -- take block client_id if block is suitable ELSE keep previos result
      case when b.client_id IS NOT NULL THEN 1 ELSE 0 END cookiebot_fix
    FROM backfill_client_id_pass_2 e
    LEFT JOIN block_client_ids_fix_cookiebot b ON e.`hash`=b.`hash` AND e.block_end=b.block_end
  )


SELECT * FROM backfill_client_id_pass_3_fix_cookiebot
