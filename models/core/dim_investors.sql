select
    investor_id,
    user_id,
    full_name,
    email,
    country,
    created_at
from {{ ref('stg_platform__investors') }}
