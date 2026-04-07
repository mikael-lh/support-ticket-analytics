-- Resolve ticket requesters to platform users via email matching.
--
-- Resolution priority:
--   1. Match to investor email -> requester_type = 'investor'
--   2. Match to RM email -> requester_type = 'relationship_manager'
--   3. No match -> requester_type = 'unknown' (~80 tickets from personal emails)
--
-- Investor and RM email sets are mutually exclusive (verified: 0 overlap),
-- so both LEFT JOINs are safe and at most one will match per ticket.
-- Grain: 1 row per ticket (preserved — both joins are 1:1 on email).

select
    t.ticket_id,
    t.requester_email,
    t.requester_name,
    t.subject,
    t.status,
    t.priority,
    t.created_at,
    t.resolved_at,
    t.tags_array,
    t.partner_label,
    case
        when inv.investor_id is not null then 'investor'
        when rm.rm_id is not null then 'relationship_manager'
        else 'unknown'
    end as requester_type,
    inv.investor_id,
    rm.rm_id,
    coalesce(ent.partner_id, rm.partner_id) as resolved_partner_id,
    inv.entity_id
from {{ ref('int_tickets_filtered') }} as t
left join {{ ref('stg_platform__investors') }} as inv
    on t.requester_email = inv.email
left join {{ ref('stg_platform__relationship_managers') }} as rm
    on t.requester_email = rm.email
left join {{ ref('stg_platform__entities') }} as ent
    on inv.entity_id = ent.entity_id
