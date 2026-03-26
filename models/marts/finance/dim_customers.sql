{{
    config(
        materialized='table',
        schema='marts'
    )
}}

with customers as (

    select * from {{ ref('stg_customers') }}

),

customer_metrics as (

    select
        customer_id,
        count(*) as total_transactions,
        sum(amount) as total_lifetime_value,
        avg(amount) as avg_transaction_amount,
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,
        count(distinct account_id) as account_count,
        count(distinct category) as category_count,

        -- Days since last transaction
        current_date - max(transaction_date) as days_since_last_transaction

    from {{ ref('int_customer_transactions') }}
    where status = 'completed'
    group by customer_id

),

final as (

    select
        -- Customer attributes
        c.customer_id,
        c.full_name as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        c.age_group,
        c.created_at as customer_since,
        --c.customer_age_days,

        -- Transaction metrics (coalesce handles customers with no transactions)
        m.first_transaction_date,
        m.last_transaction_date,
        m.days_since_last_transaction,
        coalesce(m.total_transactions, 0) as total_transactions,
        coalesce(m.total_lifetime_value, 0) as total_lifetime_value,
        coalesce(m.avg_transaction_amount, 0) as avg_transaction_amount,
        coalesce(m.account_count, 0) as account_count,
        coalesce(m.category_count, 0) as category_count,

        -- Customer segment derived from lifetime value
        case
            when coalesce(m.total_lifetime_value, 0) >= 10000 then 'platinum'
            when coalesce(m.total_lifetime_value, 0) >= 5000 then 'gold'
            when coalesce(m.total_lifetime_value, 0) >= 1000 then 'silver'
            else 'bronze'
        end as customer_segment

    from customers as c
    left join customer_metrics as m on c.customer_id = m.customer_id

)

select * from final
