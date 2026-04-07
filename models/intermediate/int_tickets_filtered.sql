-- Remove internal/test tickets from @titanbay.com and @titanbay.co.uk domains.
-- These are internal QA, ops, or test tickets that should not be included
-- in IS team analysis. Removes ~100 of 2000 tickets.

select *
from {{ ref('stg_freshdesk__tickets') }}
where requester_email not like '%@titanbay.com'
  and requester_email not like '%@titanbay.co.uk'
