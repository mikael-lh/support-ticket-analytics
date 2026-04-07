-- Monitor that the proportion of 'unknown' requester tickets stays below 10%.
-- If this test fails, it signals a data linkage regression (e.g. new email
-- domains appearing that need investigation).

with stats as (
    select
        countif(requester_type = 'unknown') as unknown_count,
        count(*) as total_count
    from {{ ref('fct_tickets') }}
)

select *
from stats
where safe_divide(unknown_count, total_count) > 0.10
