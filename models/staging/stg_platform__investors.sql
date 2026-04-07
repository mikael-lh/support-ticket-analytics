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
    cast(created_at as timestamp) as created_at,
    relationship_manager_id
from source
