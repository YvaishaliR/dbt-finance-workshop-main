-- Create models/marts/finance/dim_accounts.sql following the pattern from dim_customers:

-- Requirements:

-- All columns from stg_accounts
-- Joined metrics from int_account_balances: transaction_count, total_credits, total_debits, net_balance_change, first_transaction_date, last_transaction_date
-- Use left join so accounts with no transactions still appear
-- Add an account_health classification:
-- 'healthy' — net_balance_change >= 0
-- 'declining' — net_balance_change < 0
-- 'inactive' — no transactions (null metrics)

{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with accounts as (

    -- Base account data (all columns from staging)
    select * 
    from {{ ref('stg_accounts') }}

),

account_metrics as (

    -- Pre-aggregated metrics from intermediate layer
    select
        account_id,
        transaction_count,
        total_credits,
        total_debits,
        net_balance_change,
        first_transaction_date,
        last_transaction_date

    from {{ ref('int_account_balances') }}

),

final as (

    select
        a.account_id,
        a.account_type,
        a.customer_id,
        a.open_date,

        -- Metrics (handle accounts with no transactions)
        coalesce(m.transaction_count, 0)        as transaction_count,
        coalesce(m.total_credits, 0)            as total_credits,
        coalesce(m.total_debits, 0)             as total_debits,
        coalesce(m.net_balance_change, 0)       as net_balance_change,
        m.first_transaction_date,
        m.last_transaction_date,

        -- Account health classification
        case 
            when m.account_id is null then 'inactive'
            when m.net_balance_change >= 0 then 'healthy'
            else 'declining'
        end as account_health

    from accounts a
    left join account_metrics m
        on a.account_id = m.account_id

)

select * from final