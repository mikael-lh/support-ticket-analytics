-- One row per investor with ticket behaviour summary.
-- Directly answers: "Which investors raise the most tickets and what patterns exist?"

with ticket_tags as (
    select
        investor_id,
        tag
    from {{ ref('fct_tickets') }},
    unnest(tags_array) as tag
    where requester_type = 'investor'
),

top_tag_per_investor as (
    select
        investor_id,
        tag,
        row_number() over (
            partition by investor_id
            order by count(*) desc, tag
        ) as rn
    from ticket_tags
    group by investor_id, tag
)

select
    inv.investor_id,
    inv.full_name,
    inv.email,
    inv.country,
    p.partner_name,
    ent.entity_type,
    ent.kyc_status,
    count(t.ticket_id) as total_tickets,
    countif(t.status in ('open', 'pending')) as open_tickets,
    countif(t.status in ('resolved', 'closed')) as resolved_tickets,
    round(avg(t.resolution_time_hours), 1) as avg_resolution_hours,
    min(t.created_at) as first_ticket_date,
    max(t.created_at) as most_recent_ticket_date,
    tt.tag as most_common_tag
from {{ ref('fct_tickets') }} as t
inner join {{ ref('dim_investors') }} as inv
    on t.investor_id = inv.investor_id
left join {{ ref('dim_entities') }} as ent
    on t.entity_id = ent.entity_id
left join {{ ref('dim_partners') }} as p
    on t.partner_id = p.partner_id
left join top_tag_per_investor as tt
    on t.investor_id = tt.investor_id
    and tt.rn = 1
where t.requester_type = 'investor'
group by
    inv.investor_id,
    inv.full_name,
    inv.email,
    inv.country,
    p.partner_name,
    ent.entity_type,
    ent.kyc_status,
    tt.tag
