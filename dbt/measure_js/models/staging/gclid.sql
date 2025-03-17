select 
    click_view_gclid gclid,
    g.campaign_id,
    coalesce(campaign_name,CAST(g.campaign_id as string)) campaign_name,
    g.ad_group_id adset_id,
    coalesce(adset_name,CAST(g.ad_group_id as string)) adset_name,
    g.customer_id account_id,
    coalesce(account_name,CAST(g.customer_id as string)) account_name,
    regexp_extract(click_view_ad_group_ad,r'~(.*)') ad_id,
    coalesce(ad_name,regexp_extract(click_view_ad_group_ad,r'~(.*)')) ad_name,
    click_view_keyword_info_text keyword,
    segments_device device,
from {{ source('adwords','ads_ClickStats_7539300735') }} g
left join {{ ref('google_ads_hierarchy') }} a on regexp_extract(click_view_ad_group_ad,r'~(.*)') = CAST(a.ad_id as string)