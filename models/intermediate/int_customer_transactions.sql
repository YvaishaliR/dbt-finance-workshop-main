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
        -- TODO [Module 3]: Add account fields (account_type, account_status)

        -- Customer fields (null if orphaned account or transaction)
        c.customer_id,
        -- TODO [Module 3]: Add customer fields (customer_name, customer_type, risk_category, credit_score)

        -- Data quality flags — surface issues rather than hide them
        case when a.account_id  is null then true else false end as is_orphaned_transaction,
        case when c.customer_id is null then true else false end as is_missing_customer,

        -- TODO [Module 3]: Add calculated fields:
        -- 1. is_high_value: amount > 1000
        -- 2. risk_flag: customer risk_category = 'high' OR credit_score < 650
        -- 3. transaction_size_band: 'large' >= 1000, 'medium' >= 100, else 'small'

    from transactions t
    left join accounts  a on t.account_id  = a.account_id
    left join customers c on a.customer_id = c.customer_id

)

select * from joined
