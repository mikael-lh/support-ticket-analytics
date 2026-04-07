select
    rm_id,
    name,
    email
from {{ ref('stg_platform__relationship_managers') }}
