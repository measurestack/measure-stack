with customer as (
  select * except(rn) from (
  select *,row_number() over (partition by customer_id order by _DATA_DATE desc) rn from {{ source('adwords', 'ads_Customer_7539300735') }}
  ) 
  where rn=1
),
campaigns as (
  select * except(rn) from (
  select *,row_number() over (partition by campaign_id order by _DATA_DATE desc) rn from {{ source('adwords', 'ads_Campaign_7539300735') }}
  ) 
  where rn=1
),
adgroups as (
  select * except(rn) from (
  select *,row_number() over (partition by ad_group_id order by _DATA_DATE desc) rn from {{ source('adwords', 'ads_AdGroup_7539300735') }}
  ) 
  where rn=1
),
ads as (
  select * except(rn) from (
  select *,
    COALESCE (ad_group_ad_ad_name, ad_group_ad_ad_image_ad_name, ad_group_ad_ad_text_ad_headline, ad_group_ad_ad_legacy_responsive_display_ad_short_headline ,ad_group_ad_ad_responsive_display_ad_headlines, CAST(ad_group_ad_ad_id as STRING)) ad_name,
    row_number() over (partition by ad_group_ad_ad_id order by _DATA_DATE desc) rn 
    from {{ source('adwords', 'ads_Ad_7539300735') }}
  ) 
  where rn=1
)

select 
  customer_descriptive_name account_name,
  ads.customer_id account_id,
  ads.campaign_id campaign_id,
  campaign_name campaign_name,
  ads.ad_group_id adset_id,
  ad_group_name adset_name,
  ad_group_ad_ad_id ad_id,
  ad_name,
  CASE
    -- WHEN AdNetworkType2 like '%YOUTUBE%' then 'Google YOUTUBE'  -- AdNetworkType2 seem to be only in the stats tables
    WHEN campaign_advertising_channel_type like '%SEARCH%' then "Google SEARCH"
    WHEN campaign_advertising_channel_type like '%DISCOVERY%' then "Google DISCOVERY"
    WHEN campaign_advertising_channel_type like '%DISPLAY%' then "Google DISPLAY"
    WHEN campaign_advertising_channel_type like '%SHOPPING%' then "Google SHOPPING"
    WHEN campaign_advertising_channel_type like '%VIDEO%' then "Google VIDEO"
    else "GOOGLE_UNKNOWN"
  END AS channel,
  "Google" as platform
from ads
LEFT JOIN  campaigns c on ads.campaign_id = c.campaign_id
LEFT JOIN  adgroups adset ON ads.ad_group_id = adset.ad_group_id
LEFT JOIN  customer cust ON ads.customer_id = cust.customer_id