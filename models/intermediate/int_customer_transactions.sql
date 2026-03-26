-- Intermediate model: Customer transactions enriched with account and customer data
-- TODO [Module 3]: Complete this model

{{
    config(
        materialized='ephemeral'
    )
}}

with transactions as (

    select * from {{ ref('stg_transactions') }}

),

accounts as (

    select * from {{ ref('stg_accounts') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

-- Left joins preserve ALL transactions.
-- Orphaned transactions (missing account or customer) surface as nulls
-- rather than being silently dropped. Tests below catch these.
-- TODO [Module 3]: Complete the select list
joined as (

    select
        -- Transaction fields
        t.transaction_id,
        t.transaction_date,
        t.amount,
        t.transaction_type,
        t.status,
        t.category,
        t.merchant_name,
        t.transaction_age_days,

        -- Account fields (null if orphaned transaction)
        a.account_id,
        a.account_type,
        a.account_status,
        a.current_balance,
        a.account_age_days,

        -- TODO [Module 3]: Add account fields (account_type, account_status)

        -- Customer fields (null if orphaned account or transaction)
        c.customer_id,
        c.full_name as customer_name,
        c.email,
        c.customer_type,
        c.risk_category,
        c.credit_score,
        c.city,
        c.state,
        c.age_group,

        current_date - t.transaction_date as days_since_transaction,

        -- TODO [Module 3]: Add customer fields (customer_name, customer_type, risk_category, credit_score)

        -- Data quality flags — surface issues rather than hide them
        coalesce(a.account_id is null, false) as is_orphaned_transaction,
        coalesce(c.customer_id is null, false) as is_missing_customer,

        -- TODO [Module 3]: Add calculated fields:
        -- 1. is_high_value: amount > 1000
        -- 2. risk_flag: customer risk_category = 'high' OR credit_score < 650
        -- 3. transaction_size_band: 'large' >= 1000, 'medium' >= 100, else 'small'
        -- Calculated fields
        coalesce(t.amount > 1000, false) as is_high_value,

        coalesce(c.risk_category = 'high' or c.credit_score < 650, false) as risk_flag,

        case
            when t.amount >= 1000 then 'large'
            when t.amount >= 100 then 'medium'
            else 'small'
        end as transaction_size_band

    from transactions as t
    left join accounts as a on t.account_id = a.account_id
    left join customers as c on a.customer_id = c.customer_id

),

category_totals as (

    select
        customer_id,
        category,
        sum(amount) as category_total,
        count(*) as category_count
    from joined
    where transaction_type = 'debit'
    group by customer_id, category

)

select * from joined
