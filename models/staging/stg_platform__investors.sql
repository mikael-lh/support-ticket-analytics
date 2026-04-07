with source as (
    select * from {{ source('platform', 'platform_investors') }}
)

select
    investor_id,
    user_id,
    lower(email) as email,
    full_name,
    entity_id,
    country,
    created_at,
    relationship_manager_id
from source
