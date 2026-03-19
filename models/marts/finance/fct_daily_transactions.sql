-- Fact table: Daily transaction summary
-- TODO [Module 4]: Complete this mart model

{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

),

-- TODO [Module 4]: Create aggregations by date and customer
daily_summary as (

    select
        transaction_date,
        customer_id,
        -- TODO [Module 4]: Add aggregations:
        -- count(*) as transaction_count
        -- sum(amount) as total_amount
        -- avg(amount) as avg_amount
        -- count(distinct account_id) as unique_accounts
        
    from customer_transactions
    where status = 'completed'
    -- TODO [Module 4]: Add group by clause
    
)

select * from daily_summary
