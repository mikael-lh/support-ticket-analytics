-- One Big Table: every ticket with all dimension attributes pre-joined.
-- Analysts can filter, group, and pivot without writing any joins.

select
    t.ticket_id,
    t.created_at,
    t.resolved_at,
    t.resolution_time_hours,
    t.subject,
    t.status,
    t.priority,
    t.tags_array,
    t.requester_email,
    t.requester_name,
    t.requester_type,

    t.investor_id,
    inv.full_name as investor_name,
    inv.country as investor_country,

    t.rm_id,
    rm.name as rm_name,

    t.partner_id,
    p.partner_name,
    p.partner_type,

    t.entity_id,
    ent.entity_name,
    ent.entity_type,
    ent.kyc_status,

    t.days_to_nearest_close,
    t.nearest_close_id,
    t.nearest_close_status,
    fc.fund_name as nearest_fund_name,
    fc.scheduled_close_date as nearest_close_date
from {{ ref('fct_tickets') }} as t
left join {{ ref('dim_investors') }} as inv
    on t.investor_id = inv.investor_id
left join {{ ref('dim_relationship_managers') }} as rm
    on t.rm_id = rm.rm_id
left join {{ ref('dim_partners') }} as p
    on t.partner_id = p.partner_id
left join {{ ref('dim_entities') }} as ent
    on t.entity_id = ent.entity_id
left join {{ ref('fct_fund_closes') }} as fc
    on t.nearest_close_id = fc.close_id
