-- Intermediate model: Account-level transaction summary
-- Aggregates completed transactions per account for use in gold layer marts

{{
    config(
        materialized='ephemeral'
    )
}}

with customer_transactions as (

    select * from {{ ref('int_customer_transactions') }}

),

account_summary as (

    select
        account_id,
        account_type,
        customer_id,
        customer_name,

        -- Transaction counts
        count(*) as transaction_count,
        count(distinct transaction_date) as active_days,
        count(distinct category) as unique_categories,

        -- Amount aggregations
        sum(
            case
                when transaction_type = 'credit'
                    then amount
                else 0
            end
        ) as total_credits,

        sum(
            case
                when transaction_type = 'debit'
                    then amount
                else 0
            end
        ) as total_debits,

        sum(
            case
                when transaction_type = 'transfer'
                    then amount
                else 0
            end
        ) as total_transfers,

        -- Net balance impact from transactions
        sum(
            case
                when transaction_type = 'credit' then amount
                when transaction_type = 'debit' then -amount
                else 0
            end
        ) as net_balance_change,

        -- Date boundaries
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,

        -- Risk counts
        sum(case when risk_flag then 1 else 0 end) as risk_flagged_count,
        sum(case when is_high_value then 1 else 0 end) as high_value_count

    from customer_transactions
    where status = 'completed'
    group by
        account_id,
        account_type,
        customer_id,
        customer_name

)

select * from account_summary
