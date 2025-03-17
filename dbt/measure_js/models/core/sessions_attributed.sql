SELECT
    e.* replace(
        case 
            when g.gclid is not null and utm.campaign is null then STRUCT('google' as source,'cpc' as medium, g.campaign_name as campaign, g.keyword as term, g.ad_id as content, g.ad_id as id)
            else utm
        end as utm),
FROM
    {{ ref('sessions') }} e
    LEFT JOIN {{ ref('gclid') }} g on e.clid.value = g.gclid