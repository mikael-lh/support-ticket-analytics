-- For each ticket, find the nearest fund close for the ticket's resolved partner.
-- "Nearest" = smallest absolute distance in days between ticket creation and
-- the close's scheduled date.
--
-- Positive days_to_nearest_close = ticket raised BEFORE the close.
-- Negative = ticket raised AFTER the close.
-- NULL = no resolved partner (unknown requester) or partner has no closes.

with nearest_close as (
    select
        t.ticket_id,
        fc.close_id,
        fc.close_status,
        date_diff(fc.scheduled_close_date, date(t.created_at), day) as days_to_close
    from {{ ref('int_tickets_enriched') }} as t
    inner join {{ ref('stg_platform__fund_closes') }} as fc
        on t.resolved_partner_id = fc.partner_id
    qualify row_number() over (
        partition by t.ticket_id
        order by abs(date_diff(fc.scheduled_close_date, date(t.created_at), day)), fc.close_id
    ) = 1
)

select
    t.*,
    nc.days_to_close as days_to_nearest_close,
    nc.close_id as nearest_close_id,
    nc.close_status as nearest_close_status
from {{ ref('int_tickets_enriched') }} as t
left join nearest_close as nc
    on t.ticket_id = nc.ticket_id
