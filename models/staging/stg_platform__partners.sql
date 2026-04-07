with source as (
    select * from {{ source('platform', 'platform_partners') }}
)

select
    partner_id,
    partner_name,
    partner_type
from source
