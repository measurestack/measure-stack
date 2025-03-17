with ads_agg as (
SELECT
  segments_date date,
  account_id,
  account_name,
  stats.campaign_id,
  campaign_name,
  stats.ad_group_id adset_id,
  adset_name, 
  stats.ad_group_ad_ad_id ad_id,
  ad_name,
  SUM(metrics_cost_micros)/1000000 spend, 
  SUM(metrics_impressions) impressions,
  0 reach,
  SUM(metrics_clicks) clicks,
  SUM(metrics_interactions) engagement,
  channel,
  "Google" AS platform,
FROM {{ source('adwords', 'ads_AdBasicStats_7539300735') }} stats 
LEFT JOIN {{ ref('google_ads_hierarchy') }} ads on stats.ad_group_ad_ad_id = ads.ad_id
GROUP BY
  date,
  account_id,
  account_name,
  campaign_id,
  campaign_name,
  adset_id,
  adset_name,
  ad_id,
  ad_name,
  channel,
  platform
)
select 
  *,
  "go_ads" data_source
from ads_agg


