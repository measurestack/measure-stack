select * 
FROM (
    select *,
        final_price=0 is_free,
        paddle_data.session_completed_object.p_price > 0 or stripe_data.session_completed_object.status = 'complete' is_paid,
        (case when paddle_data.session_completed_object.p_price > 0 or stripe_data.session_completed_object.status = 'complete' then final_price else 0 end)/100 revenue,

    FROM {{ source('firestore','bookings') }}
)
where is_free or is_paid