select
    entity_id,
    entity_name,
    entity_type,
    kyc_status
from {{ ref('stg_platform__entities') }}
