with source as (
    select * from {{ source('platform', 'platform_fund_closes') }}
)

select
    close_id,
    fund_id,
    fund_name,
    partner_id,
    cast(close_number as int64) as close_number,
    cast(scheduled_close_date as date) as scheduled_close_date,
    close_status,
    cast(total_committed_aum as numeric) as total_committed_aum
from source
