with source as (
    select * from {{ source('platform', 'platform_fund_closes') }}
)

select
    close_id,
    fund_id,
    fund_name,
    partner_id,
    close_number,
    scheduled_close_date,
    close_status,
    total_committed_aum
from source
