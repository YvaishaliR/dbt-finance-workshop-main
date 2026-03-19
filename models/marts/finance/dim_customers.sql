-- Dimension table: Customer dimension
-- TODO [Module 4]: Complete this dimension table

{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with customers as (

    select * from {{ ref('stg_customers') }}

),

-- TODO [Module 4]: Add customer lifetime metrics by joining to int_customer_transactions
customer_metrics as (

    select
        customer_id,
        -- TODO [Module 4]: Calculate from transactions:
        -- count(*) as total_transactions
        -- sum(amount) as total_lifetime_value
        -- min(transaction_date) as first_transaction_date
        -- max(transaction_date) as last_transaction_date
        
    from {{ ref('int_customer_transactions') }}
    where status = 'completed'
    group by customer_id
    
),

final as (

    select
        c.customer_id,
        c.full_name as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        
        -- TODO [Module 4]: Add metrics from customer_metrics CTE
        
    from customers c
    -- TODO [Module 4]: Add left join to customer_metrics
    
)

select * from final
