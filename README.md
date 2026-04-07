# Support Ticket Analytics

A dbt + BigQuery analytics engineering project that models support ticket data alongside platform data, enabling the Investor Services (IS) team to understand ticket patterns and anticipate resourcing needs.

## Business Problem

The IS team handles support tickets reactively — when a ticket comes in, they resolve it and move on. There is no structured view of:
- Which investors raise the most tickets
- What patterns exist in ticket behaviour
- How ticket volume relates to platform activity (e.g. fund closes)

This project models the available data so analysts can answer these questions directly.

## What an Analyst Can Now Do

The mart layer provides two analyst-facing tables that require no joins or SQL knowledge beyond basic filtering:

**1. `mart.mart_investor_ticket_summary`** — One row per investor, pre-aggregated. Directly answers "which investors raise the most tickets?":
```sql
select * from mart.mart_investor_ticket_summary
order by total_tickets desc
```

**2. `mart.mart_ticket_overview`** — Every ticket with all context pre-joined (investor name, partner, entity, nearest fund close). Filter and group however you need:
```sql
-- Tickets by partner and priority
select partner_name, priority, count(*) as ticket_count
from mart.mart_ticket_overview
group by 1, 2

-- Ticket pressure around fund closes
select
    case
        when days_to_nearest_close between -7 and 7 then 'within_1_week'
        when days_to_nearest_close between -14 and 14 then 'within_2_weeks'
        else 'outside_2_weeks'
    end as close_proximity,
    count(*) as ticket_count
from mart.mart_ticket_overview
where days_to_nearest_close is not null
group by 1
```

For more granular analysis, the normalized core layer (`fct_tickets` + dimension tables) is also available.

## Architecture

**Stack:** dbt + BigQuery + GitHub Actions

**Medallion architecture** with four layers:

```
Raw (BQ)          Staging              Intermediate              Core                Mart
─────────    ──────────────────    ─────────────────────    ──────────────    ──────────────
CSV uploads  1:1 with source,     Entity resolution,       Dimensional       Analyst-facing
in BQ raw    rename + clean       filtering, enrichment    model: dims       denormalized
dataset      (views)              (views)                  + facts (tables)  tables
```

### Layer Details

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| Raw | `raw` | BQ tables (CSV upload) | Source data as-is |
| Staging | `staging` | Views | 1:1 with source. Lowercase emails, split tags. No joins. |
| Intermediate | `intermediate` | Views | Filter internal tickets, resolve requesters to platform users, compute fund close proximity |
| Core | `core` | Tables | Star schema: `fct_tickets`, `fct_fund_closes`, `dim_investors`, `dim_relationship_managers`, `dim_partners`, `dim_entities` |
| Mart | `mart` | Tables | Analyst-facing: `mart_ticket_overview` (OBT), `mart_investor_ticket_summary` (per-investor aggregation) |

### Data Model

**Core layer** — star schema with all FKs on the fact table:

```
 dim_investors       dim_relationship_managers       dim_entities       dim_partners    dim_partners
 ─────────────       ─────────────────────────       ────────────       ────────────    ────────────
 investor_id (PK)    rm_id (PK)                      entity_id (PK)     partner_id (PK)  partner_id (PK)
 full_name           name                            entity_name        partner_name     partner_name
 email               email                           entity_type        partner_type     partner_type
 country                                             kyc_status                                 
 created_at                                                                                     │
       │                    │                                                 │                 │
       └────────────────────┼─────────────────────────────────────────────────┘                 │
                            │                                                                   │
                   ┌────────┴──────────┐          ┌───────────────────┐                         │
                   │   fct_tickets     │          │  fct_fund_closes  │                         │
                   │──────────────────-│          │───────────────────│                         │
                   │ ticket_id (PK)    │          │ close_id (PK)     │                         │
                   │ investor_id (FK)  │          │ fund_id           │                         │
                   │ rm_id (FK)        │          │ fund_name         │                         │
                   │ entity_id (FK)    │          │ partner_id (FK)   │─────────────────────────┘
                   │ partner_id (FK)   │          │ scheduled_close   │
                   │ nearest_close     │          | close_status      │
                   │ requester_type    │          │ committed_aum     │
                   │ resolution_hours  │          └───────────────────┘
                   │ days_to_close     │
                   └───────────────────┘
```

**Mart layer** — analyst-facing denormalized tables built on top of core:

- `mart_ticket_overview` — OBT: every ticket with all dim attributes pre-joined
- `mart_investor_ticket_summary` — one row per investor with aggregated ticket metrics

## Key Decisions

1. **Entity resolution via email matching.** Ticket `requester_email` is joined to investor and RM emails. Investor/RM email sets are mutually exclusive (0 overlap verified), so at most one join matches per ticket. This is the primary linkage — the `partner_label` field is too unreliable to use.

2. **Internal tickets filtered out.** 100 tickets from `@titanbay.com` (47) and `@titanbay.co.uk` (53) are removed in the intermediate layer. Many have mismatched names or test subjects.

3. **Unknown requesters kept as-is.** ~80 tickets from personal emails (gmail, icloud, outlook, yahoo) can't be linked to platform users. 81 match an investor by name, but name matching is too risky (names aren't unique). Kept as `requester_type = 'unknown'`.

4. **Normalized star schema.** Dimension tables contain only their own attributes — no denormalized cross-dim fields. All FKs (`investor_id`, `rm_id`, `entity_id`, `partner_id`) live on `fct_tickets`.

5. **Fund close proximity pre-computed.** `days_to_nearest_close` is computed per ticket as the distance to the nearest fund close for the ticket's partner. This avoids row multiplication (one partner has many closes) while enabling close-proximity analysis.

6. **Mart layer for analyst usability.** Two pre-built tables: `mart_ticket_overview` (OBT with all dimensions pre-joined) and `mart_investor_ticket_summary` (per-investor aggregation). These let analysts explore data without writing joins.

## Assumptions

- **Email is the reliable identifier.** We trust platform emails as the primary join key. Tickets from non-platform emails are flagged as unknown rather than force-matched.
- **"Nearest close" uses absolute distance.** A close 5 days before ticket creation and 5 days after are equally "near." Positive values = ticket before close; negative = ticket after close.
- **All source PKs are trusted.** `ticket_id`, `investor_id`, etc. are assumed unique and non-null in source data (validated via staging tests).
- **Synthetic data quirks are acceptable.** Future dates in `created_at` and some implausible country values are noted but not filtered — they don't affect the modelling logic.

## Data Quality Issues Found

| Issue | Severity | Handling |
|-------|----------|----------|
| `partner_label` is ~44% null, with mixed case, abbreviations, and inconsistent variants | High | Not used for joining. Email-based resolution is the primary method. Documented as a DQ finding. |
| ~100 internal/test tickets from `@titanbay.com` and `@titanbay.co.uk` | Medium | Filtered out in intermediate layer |
| ~80 tickets from personal emails unlinked to platform users | Medium | Kept as `requester_type = 'unknown'`. Resolution coverage monitored via test (must stay below 10%) |
| `requester_name` sometimes mismatches the email-implied name | Low | Email trusted for matching; name discrepancy noted |
| Some investor `created_at` dates are in 2026 | Low | Synthetic data artifact; noted, not filtered |

## Testing Strategy

Tests run at all four layers:

- **Staging:** PK uniqueness, not_null, accepted_values on enums — validates source data expectations
- **Intermediate:** Grain preservation (1 row per ticket after joins), requester_type values
- **Core:** Referential integrity (all FKs reference valid dim rows), business logic (resolution time >= 0, committed AUM > 0 for non-cancelled closes), resolution coverage threshold
- **Mart:** Grain preservation (unique investor_id in summary table, unique ticket_id in overview table), not_null on primary keys

## AI Tool Usage

AI tools (Claude / Cursor) were used throughout this project as a force multiplier:

- **Data exploration:** Automated analysis of CSV files to identify data quality issues, email domain patterns, and requester type distribution
- **Planning:** Collaborative design of the data model, with the AI proposing approaches and the engineer challenging and refining them
- **Code generation:** SQL models, YAML configs, and tests generated with AI assistance, then reviewed and adjusted
- **Documentation:** README structure and content drafted with AI, reviewed for accuracy

All architectural decisions, modelling choices, and trade-offs were made by the engineer. The AI accelerated execution but did not replace judgement.

## Reflection Question

> *"Based on what you have seen in the data, what would the ideal long-term fix(es) be for the core data linkage problem(s) you encountered?"*

The core problem is that Freshdesk tickets have no structured foreign key to the platform's user tables. The linkage relies on email matching, which breaks for personal emails, shared inboxes, or address changes. The `partner_label` field is manually entered free-text with no referential integrity.

**Ideal long-term fixes:**

1. **Add a `platform_user_id` to Freshdesk tickets** — via SSO integration or API enrichment at ticket creation time. This eliminates email matching entirely and handles the personal-email problem.
2. **Replace free-text `partner_label` with a structured dropdown** — linked to the canonical partner list from the platform. This provides reliable partner attribution even when user identity can't be resolved.
3. **Add a `requester_type` field to Freshdesk** — (investor / RM / internal) set at ticket creation. This removes the ambiguity of inferring type from email domain patterns.

**Additional data to enable further analysis:**

The current data only has `total_committed_aum` at the fund close level, with no breakdown by individual investor. Adding an investor-level commitment table would enable analysis of whether higher-capital investors generate more support tickets, and allow the IS team to prioritise accordingly.
