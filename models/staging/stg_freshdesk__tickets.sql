with source as (
    select * from {{ source('freshdesk', 'freshdesk_tickets') }}
)

select
    ticket_id,
    lower(requester_email) as requester_email,
    requester_name,
    subject,
    status,
    priority,
    cast(created_at as timestamp) as created_at,
    cast(resolved_at as timestamp) as resolved_at,
    split(tags, ',') as tags_array,
    partner_label
from source
