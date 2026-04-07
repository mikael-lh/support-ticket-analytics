with source as (
    select * from {{ source('platform', 'platform_entities') }}
)

select
    entity_id,
    entity_name,
    partner_id,
    entity_type,
    kyc_status
from source
