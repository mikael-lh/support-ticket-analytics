with source as (
    select * from {{ source('platform', 'platform_relationship_managers') }}
)

select
    rm_id,
    partner_id,
    name,
    lower(email) as email
from source
